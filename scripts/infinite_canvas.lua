-- ============================================================================
-- HySett Infinite Canvas (Бесконечный холст для Hyprland Lua)
-- ============================================================================

local PANLOCK_FILE = "/tmp/hysett_canvas_panlock"
local ACTIVE_FILE  = "/tmp/hysett_canvas_active"
local STATE_FILE   = "/tmp/hysett_canvas_state.lua"

_G.Canvas = _G.Canvas or {
    enabled = false,
    panning = false,
    inverted = false,
    speed = 3.2,
    accel = 1.6,
    min_gap = 12,
    key_step = 110,
    init_scale = 0.78,
    all_workspaces = true,
    edge_push_enabled = true,
    active_ws_id = 1,
    next_order_seq = 1,
    saved_state = {},
    virtual_pos = {},
    win_order = {},
}

-- Восстанавливаем состояние холста после hyprctl reload (при переключении комментариев биндов в hyprland.lua)
local function load_persisted_state()
    local f = io.open(STATE_FILE, "r")
    if not f then return end
    f:close()
    local ok, data = pcall(dofile, STATE_FILE)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            _G.Canvas[k] = v
        end
    end
end

local function save_persisted_state()
    if not _G.Canvas.enabled then
        os.remove(STATE_FILE)
        return
    end
    local f = io.open(STATE_FILE, "w")
    if not f then return end
    f:write("return {\n")
    f:write(string.format("  enabled = %s,\n", tostring(_G.Canvas.enabled)))
    f:write(string.format("  inverted = %s,\n", tostring(_G.Canvas.inverted)))
    f:write(string.format("  speed = %s,\n", tostring(_G.Canvas.speed or 3.2)))
    f:write(string.format("  accel = %s,\n", tostring(_G.Canvas.accel or 1.6)))
    f:write(string.format("  min_gap = %d,\n", math.floor(_G.Canvas.min_gap or 12)))
    f:write(string.format("  key_step = %d,\n", math.floor(_G.Canvas.key_step or 110)))
    f:write(string.format("  init_scale = %s,\n", tostring(_G.Canvas.init_scale or 0.78)))
    f:write(string.format("  active_ws_id = %d,\n", math.floor(_G.Canvas.active_ws_id or 1)))
    f:write(string.format("  next_order_seq = %d,\n", math.floor(_G.Canvas.next_order_seq or 1)))

    f:write("  win_order = {\n")
    for k, v in pairs(_G.Canvas.win_order or {}) do
        f:write(string.format("    [%q] = %d,\n", tostring(k), math.floor(v)))
    end
    f:write("  },\n")

    f:write("  saved_state = {\n")
    for k, st in pairs(_G.Canvas.saved_state or {}) do
        f:write(string.format(
            "    [%q] = { order = %d, workspace_id = %d, was_float = %s, x = %d, y = %d, w = %d, h = %d },\n",
            tostring(k),
            math.floor(st.order or 1),
            math.floor(st.workspace_id or 1),
            tostring(st.was_float and true or false),
            math.floor(st.x or 0),
            math.floor(st.y or 0),
            math.floor(st.w or 600),
            math.floor(st.h or 400)
        ))
    end
    f:write("  },\n")

    f:write("  virtual_pos = {\n")
    for k, vp in pairs(_G.Canvas.virtual_pos or {}) do
        f:write(string.format(
            "    [%q] = { x = %d, y = %d, w = %d, h = %d },\n",
            tostring(k),
            math.floor(vp.x or 0),
            math.floor(vp.y or 0),
            math.floor(vp.w or 600),
            math.floor(vp.h or 400)
        ))
    end
    f:write("  },\n")
    f:write("}\n")
    f:close()
end

load_persisted_state()

local IGNORED_CLASSES = {
    ["hypratmooverlay"] = true,
    ["hysett"] = true,
    ["waybar"] = true,
    ["mako"] = true,
}

local function set_active_indicator(state)
    if state then
        local f = io.open(ACTIVE_FILE, "w")
        if f then f:write("1"); f:close() end
    else
        os.remove(ACTIVE_FILE)
    end
end

local function norm_addr(a)
    local s = string.lower(tostring(a or ""))
    if s ~= "" and not string.find(s, "^0x") then
        s = "0x" .. s
    end
    return s
end

local function is_valid_win(w)
    if not w then return false end
    if not w.workspace then return false end
    local wid = w.workspace.id or 0
    if wid < 1 or wid >= 10 then return false end
    if w.pinned then return false end
    local cls = string.lower(w.class or "")
    if IGNORED_CLASSES[cls] then return false end
    if w.title == "HySettAtmosphereOverlay" then return false end
    return true
end

local function is_canvas_win(w, ws_id)
    if not is_valid_win(w) then return false end
    if ws_id and w.workspace.id ~= ws_id then return false end
    return true
end

local function sort_windows_deterministic(list)
    table.sort(list, function(a, b)
        local ka = norm_addr(a.address)
        local kb = norm_addr(b.address)
        local oa = _G.Canvas.win_order[ka]
        local ob = _G.Canvas.win_order[kb]
        if oa and ob and oa ~= ob then
            return oa < ob
        end
        local wa = (a.workspace and a.workspace.id) or 0
        local wb = (b.workspace and b.workspace.id) or 0
        if wa ~= wb then return wa < wb end
        local row_a = math.floor((a.at.y or 0) / 80)
        local row_b = math.floor((b.at.y or 0) / 80)
        if row_a ~= row_b then return row_a < row_b end
        local col_a = math.floor((a.at.x or 0) / 80)
        local col_b = math.floor((b.at.x or 0) / 80)
        if col_a ~= col_b then return col_a < col_b end
        return ka < kb
    end)
end

local function get_ws_windows(ws_id)
    local list = {}
    for _, w in pairs(hl.get_windows()) do
        if is_canvas_win(w, ws_id) then
            table.insert(list, w)
        end
    end
    sort_windows_deterministic(list)
    return list
end

local function get_monitor_box()
    local m = hl.get_active_monitor()
    if m then
        local mx = (m.position and m.position.x) or m.x or 0
        local my = (m.position and m.position.y) or m.y or 0
        local mw = (m.size and m.size.x) or m.width or 1920
        local mh = (m.size and m.size.y) or m.height or 1080
        return mx, my, mw, mh
    end
    return 0, 0, 1920, 1080
end

local function ensure_vp(w)
    local key = norm_addr(w.address)
    local vp = _G.Canvas.virtual_pos[key]
    if not vp then
        vp = {
            x = w.at.x,
            y = w.at.y,
            w = w.size.x,
            h = w.size.y,
        }
        _G.Canvas.virtual_pos[key] = vp
    end
    return vp
end

local function apply_win_geom(w, x, y, width, height)
    if not w then return end
    local vp = ensure_vp(w)
    hl.dispatch(hl.dsp.focus({ window = w }))

    if width and height then
        local iw = math.max(260, math.floor(width + 0.5))
        local ih = math.max(180, math.floor(height + 0.5))
        vp.w = iw
        vp.h = ih
        if w.size.x ~= iw or w.size.y ~= ih then
            hl.dispatch(hl.dsp.window.resize({
                x = iw,
                y = ih,
                relative = false,
            }))
        end
    end
    if x and y then
        local ix = math.floor(x + 0.5)
        local iy = math.floor(y + 0.5)
        vp.x = ix
        vp.y = iy
        hl.dispatch(hl.dsp.window.move({
            x = ix,
            y = iy,
            relative = false,
        }))
    end
end

local function focus_and_raise(w)
    if not w then return end
    hl.dispatch(hl.dsp.focus({ window = w }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

local function rect_overlaps_any(x, y, w, h, ignore_addr, placed_list)
    local gap = _G.Canvas.min_gap or 12
    local pad = gap - 1
    local l1 = x - pad
    local r1 = x + w + pad
    local t1 = y - pad
    local b1 = y + h + pad

    for _, item in ipairs(placed_list) do
        if item.addr ~= ignore_addr then
            local l2 = item.x
            local r2 = item.x + item.w
            local t2 = item.y
            local b2 = item.y + item.h
            if not (r1 <= l2 or l1 >= r2 or b1 <= t2 or t1 >= b2) then
                return true
            end
        end
    end
    return false
end

local function find_free_spot(win_w, win_h, origin_cx, origin_cy, ignore_addr, placed_list)
    local gap = _G.Canvas.min_gap or 12
    local center_x = origin_cx - win_w * 0.5
    local center_y = origin_cy - win_h * 0.5
    if #placed_list == 0 or not rect_overlaps_any(center_x, center_y, win_w, win_h, ignore_addr, placed_list) then
        return center_x, center_y
    end

    local candidates = {}
    for _, p in ipairs(placed_list) do
        local px, py, pw, ph = p.x, p.y, p.w, p.h
        local mid_y = py + (ph - win_h) * 0.5
        local mid_x = px + (pw - win_w) * 0.5

        table.insert(candidates, { x = px + pw + gap, y = mid_y })
        table.insert(candidates, { x = px - win_w - gap, y = mid_y })
        table.insert(candidates, { x = mid_x, y = py + ph + gap })
        table.insert(candidates, { x = mid_x, y = py - win_h - gap })

        table.insert(candidates, { x = px + pw + gap, y = py })
        table.insert(candidates, { x = px + pw + gap, y = py + ph - win_h })
        table.insert(candidates, { x = px - win_w - gap, y = py })
        table.insert(candidates, { x = px - win_w - gap, y = py + ph - win_h })
        table.insert(candidates, { x = px, y = py + ph + gap })
        table.insert(candidates, { x = px + pw - win_w, y = py + ph + gap })
        table.insert(candidates, { x = px, y = py - win_h - gap })
        table.insert(candidates, { x = px + pw - win_w, y = py - win_h - gap })
    end

    local best_x, best_y = nil, nil
    local best_dist = 1e18

    for _, c in ipairs(candidates) do
        if not rect_overlaps_any(c.x, c.y, win_w, win_h, ignore_addr, placed_list) then
            local ccx = c.x + win_w * 0.5
            local ccy = c.y + win_h * 0.5
            local dx = ccx - origin_cx
            local dy = (ccy - origin_cy) * 1.15
            local dist = dx * dx + dy * dy
            if dist < best_dist then
                best_dist = dist
                best_x = c.x
                best_y = c.y
            end
        end
    end

    if best_x and best_y then
        return best_x, best_y
    end

    local step_x = win_w + gap
    return origin_cx + (#placed_list) * step_x - win_w * 0.5, center_y
end

local function calc_initial_canvas_size(orig_w, orig_h)
    local sc = _G.Canvas.init_scale or 0.78
    local tw = math.max(340, math.floor(orig_w * sc + 0.5))
    local th = math.max(230, math.floor(orig_h * sc + 0.5))
    return tw, th
end

function _G.Canvas.set_option(key, val)
    _G.Canvas[key] = val
    save_persisted_state()
    if key == "min_gap" and _G.Canvas.enabled then
        _G.Canvas.gather_home()
    end
end

function _G.Canvas.pan_delta(raw_dx, raw_dy)
    if not _G.Canvas.enabled then return end
    local sgn = _G.Canvas.inverted and -1.0 or 1.0
    local mag = math.sqrt(raw_dx * raw_dx + raw_dy * raw_dy)
    local max_acc = _G.Canvas.accel or 1.6
    local accel = 1.0 + math.min(max_acc, mag * 0.025)
    local spd = _G.Canvas.speed or 3.2
    local dx = raw_dx * spd * accel * sgn
    local dy = raw_dy * spd * accel * sgn
    if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end

    local ws = hl.get_active_workspace()
    if not ws then return end
    local active = hl.get_active_window()
    for _, w in pairs(hl.get_windows()) do
        if is_canvas_win(w, ws.id) and w.floating then
            local vp = ensure_vp(w)
            apply_win_geom(w, vp.x + dx, vp.y + dy, nil, nil)
        end
    end
    if active then
        hl.dispatch(hl.dsp.focus({ window = active }))
    end
    save_persisted_state()
end

function _G.Canvas.set_panning(active)
    if not _G.Canvas.enabled then
        _G.Canvas.panning = false
        os.remove(PANLOCK_FILE)
        return
    end
    _G.Canvas.panning = active and true or false
    if _G.Canvas.panning then
        local f = io.open(PANLOCK_FILE, "w")
        if f then f:write("1"); f:close() end
    else
        os.remove(PANLOCK_FILE)
    end
end

function _G.Canvas.toggle_pan_lock()
    if not _G.Canvas.enabled then return end
    _G.Canvas.set_panning(not _G.Canvas.panning)
end

-- Когда открывается новое окно: ставим на свободное место, двигаем камеру к нему и передаём фокус
function _G.Canvas.on_window_open(addr_str)
    if not _G.Canvas.enabled then return end
    local target_key = norm_addr(addr_str)
    if _G.Canvas.saved_state[target_key] then return end

    local ws = hl.get_active_workspace()
    if not ws then return end

    local new_win = nil
    for _, w in pairs(hl.get_windows()) do
        if norm_addr(w.address) == target_key then
            new_win = w
            break
        end
    end
    if not is_valid_win(new_win) then return end

    _G.Canvas.next_order_seq = (_G.Canvas.next_order_seq or 100) + 1
    _G.Canvas.win_order[target_key] = _G.Canvas.next_order_seq

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    local orig_w = math.max(520, new_win.size.x)
    local orig_h = math.max(360, new_win.size.y)
    if new_win.workspace.id ~= ws.id then
        hl.dispatch(hl.dsp.window.move({
            workspace = ws.id,
            window = new_win,
            follow = false,
        }))
    end

    hl.dispatch(hl.dsp.focus({ window = new_win }))
    if not new_win.floating then
        hl.dispatch(hl.dsp.window.float({ action = "on", window = new_win }))
    end

    local nw, nh = calc_initial_canvas_size(orig_w, orig_h)
    local placed = {}
    local other_wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        local k = norm_addr(w.address)
        if k ~= target_key and w.floating then
            local vp = ensure_vp(w)
            table.insert(placed, { addr = k, x = vp.x, y = vp.y, w = vp.w, h = vp.h })
            table.insert(other_wins, w)
        end
    end

    local free_x, free_y = find_free_spot(nw, nh, cx, cy, target_key, placed)
    local free_cx = free_x + nw * 0.5
    local free_cy = free_y + nh * 0.5

    local dx = cx - free_cx
    local dy = cy - free_cy

    for _, w in ipairs(other_wins) do
        local vp = ensure_vp(w)
        apply_win_geom(w, vp.x + dx, vp.y + dy, nil, nil)
    end

    local center_x = cx - nw * 0.5
    local center_y = cy - nh * 0.5
    apply_win_geom(new_win, center_x, center_y, nw, nh)
    focus_and_raise(new_win)
    save_persisted_state()
end

function _G.Canvas.toggle()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    if not _G.Canvas.enabled then
        _G.Canvas.enabled = true
        _G.Canvas.active_ws_id = ws.id
        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        _G.Canvas.win_order = {}
        os.remove(PANLOCK_FILE)
        set_active_indicator(true)

        local active = hl.get_active_window()
        local raw_wins = {}
        for _, w in pairs(hl.get_windows()) do
            if is_valid_win(w) then
                if _G.Canvas.all_workspaces ~= false or w.workspace.id == ws.id then
                    table.insert(raw_wins, w)
                end
            end
        end

        table.sort(raw_wins, function(a, b)
            local wa = (a.workspace and a.workspace.id) or 0
            local wb = (b.workspace and b.workspace.id) or 0
            if wa ~= wb then return wa < wb end
            if math.abs(a.at.y - b.at.y) > 30 then return a.at.y < b.at.y end
            if math.abs(a.at.x - b.at.x) > 30 then return a.at.x < b.at.x end
            return tostring(a.address) < tostring(b.address)
        end)

        for i, w in ipairs(raw_wins) do
            local key = norm_addr(w.address)
            _G.Canvas.win_order[key] = i
            _G.Canvas.saved_state[key] = {
                order = i,
                workspace_id = w.workspace.id,
                was_float = w.floating,
                x = w.at.x,
                y = w.at.y,
                w = w.size.x,
                h = w.size.y,
            }
        end
        _G.Canvas.next_order_seq = #raw_wins + 1

        local active_key = (active and norm_addr(active.address)) or (raw_wins[1] and norm_addr(raw_wins[1].address)) or ""
        local ordered = {}
        for _, w in ipairs(raw_wins) do
            if norm_addr(w.address) == active_key then
                table.insert(ordered, 1, w)
            elseif w.workspace.id == ws.id then
                table.insert(ordered, w)
            end
        end
        for _, w in ipairs(raw_wins) do
            if norm_addr(w.address) ~= active_key and w.workspace.id ~= ws.id then
                table.insert(ordered, w)
            end
        end

        local placed = {}
        for _, w in ipairs(ordered) do
            local key = norm_addr(w.address)
            local st = _G.Canvas.saved_state[key]

            if st.workspace_id ~= ws.id then
                hl.dispatch(hl.dsp.window.move({
                    workspace = ws.id,
                    window = w,
                    follow = false,
                }))
            end

            hl.dispatch(hl.dsp.focus({ window = w }))
            if not st.was_float then
                hl.dispatch(hl.dsp.window.float({ action = "on", window = w }))
            end

            local tw, th = calc_initial_canvas_size(st.w, st.h)
            local tx, ty = find_free_spot(tw, th, cx, cy, key, placed)

            apply_win_geom(w, tx, ty, tw, th)
            table.insert(placed, { addr = key, x = tx, y = ty, w = tw, h = th })
        end

        if ordered[1] then
            focus_and_raise(ordered[1])
        end

        save_persisted_state()
        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py enable_binds_and_daemon &")
    else
        _G.Canvas.enabled = false
        _G.Canvas.panning = false
        os.remove(PANLOCK_FILE)
        os.remove(STATE_FILE)
        set_active_indicator(false)

        local all_wins = {}
        for _, w in pairs(hl.get_windows()) do
            if is_valid_win(w) then
                table.insert(all_wins, w)
            end
        end

        table.sort(all_wins, function(a, b)
            local sa = _G.Canvas.saved_state[norm_addr(a.address)]
            local sb = _G.Canvas.saved_state[norm_addr(b.address)]
            local oa = (sa and sa.order) or 9999
            local ob = (sb and sb.order) or 9999
            if oa ~= ob then return oa < ob end
            return tostring(a.address) < tostring(b.address)
        end)

        for _, w in ipairs(all_wins) do
            local key = norm_addr(w.address)
            local st = _G.Canvas.saved_state[key]
            if st then
                if st.workspace_id and w.workspace.id ~= st.workspace_id then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = st.workspace_id,
                        window = w,
                        follow = false,
                    }))
                end
                apply_win_geom(w, st.x, st.y, st.w, st.h)
            end
        end

        for _, w in ipairs(all_wins) do
            local key = norm_addr(w.address)
            local st = _G.Canvas.saved_state[key]
            if st then
                if not st.was_float then
                    hl.dispatch(hl.dsp.focus({ window = w }))
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                end
            else
                if w.floating then
                    hl.dispatch(hl.dsp.focus({ window = w }))
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                end
            end
        end

        if _G.Canvas.active_ws_id then
            hl.dispatch(hl.dsp.focus({ workspace = _G.Canvas.active_ws_id }))
        end

        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        _G.Canvas.win_order = {}
        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py disable_binds_and_stop &")
    end
end

local function pan_canvas_to_window(wins, target)
    if not target then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    local tvp = ensure_vp(target)
    local tcx = tvp.x + tvp.w * 0.5
    local tcy = tvp.y + tvp.h * 0.5
    local dx = cx - tcx
    local dy = cy - tcy

    for _, w in ipairs(wins) do
        local vp = ensure_vp(w)
        apply_win_geom(w, vp.x + dx, vp.y + dy, nil, nil)
    end
    focus_and_raise(target)
    save_persisted_state()
end

function _G.Canvas.navigate(dir)
    if not _G.Canvas.enabled then
        hl.dispatch(hl.dsp.focus({ direction = dir }))
        return
    end

    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    if #wins == 0 then
        hl.dispatch(hl.dsp.focus({ direction = dir }))
        return
    end
    if #wins == 1 then
        pan_canvas_to_window(wins, wins[1])
        return
    end

    local active = hl.get_active_window()
    local ref = active or wins[1]
    local rvp = ensure_vp(ref)
    local rx = rvp.x + rvp.w * 0.5
    local ry = rvp.y + rvp.h * 0.5
    local rl, rr = rvp.x, rvp.x + rvp.w
    local rt, rb = rvp.y, rvp.y + rvp.h

    local best_aligned, best_aligned_dist = nil, 1e18
    local best_dir, best_dir_dist = nil, 1e18
    local best_wrap, best_wrap_dist = nil, -1

    for _, w in ipairs(wins) do
        if w.address ~= ref.address then
            local vp = ensure_vp(w)
            local wx = vp.x + vp.w * 0.5
            local wy = vp.y + vp.h * 0.5
            local wl, wr = vp.x, vp.x + vp.w
            local wt, wb = vp.y, vp.y + vp.h
            local overlap_v = not (wb <= rt or wt >= rb)
            local overlap_h = not (wr <= rl or wl >= rr)

            local in_dir = false
            local dist = 0
            local aligned = false

            if dir == "left" and wx < rx - 10 then
                in_dir = true
                dist = (rx - wx) + math.abs(ry - wy) * 0.4
                aligned = overlap_v
            elseif dir == "right" and wx > rx + 10 then
                in_dir = true
                dist = (wx - rx) + math.abs(ry - wy) * 0.4
                aligned = overlap_v
            elseif dir == "up" and wy < ry - 10 then
                in_dir = true
                dist = (ry - wy) + math.abs(rx - wx) * 0.4
                aligned = overlap_h
            elseif dir == "down" and wy > ry + 10 then
                in_dir = true
                dist = (wy - ry) + math.abs(rx - wx) * 0.4
                aligned = overlap_h
            end

            if in_dir then
                if aligned and dist < best_aligned_dist then
                    best_aligned_dist = dist
                    best_aligned = w
                end
                if dist < best_dir_dist then
                    best_dir_dist = dist
                    best_dir = w
                end
            else
                local wdist = math.abs(wx - rx) + math.abs(wy - ry)
                if wdist > best_wrap_dist then
                    best_wrap_dist = wdist
                    best_wrap = w
                end
            end
        end
    end

    local target = best_aligned or best_dir or best_wrap
    if target then
        pan_canvas_to_window(wins, target)
    end
end

function _G.Canvas.move_or_swap(dir)
    local active = hl.get_active_window()
    if not _G.Canvas.enabled and (not active or not active.floating) then
        local map = { left = "l", right = "r", up = "u", down = "d", l = "l", r = "r", u = "u", d = "d" }
        hl.dispatch(hl.dsp.window.swap({ direction = map[dir] or dir }))
        return
    end
    if not active or not active.floating then return end

    local step = _G.Canvas.key_step or 110
    local dx, dy = 0, 0
    if dir == "left" or dir == "l" then dx = -step
    elseif dir == "right" or dir == "r" then dx = step
    elseif dir == "up" or dir == "u" then dy = -step
    elseif dir == "down" or dir == "d" then dy = step end

    local mx, my, mw, mh = get_monitor_box()
    local avp = ensure_vp(active)
    local nx = avp.x + dx
    local ny = avp.y + dy

    local hit_edge = (dx < 0 and nx <= mx + 12)
                  or (dx > 0 and (nx + avp.w) >= (mx + mw - 12))
                  or (dy < 0 and ny <= my + 12)
                  or (dy > 0 and (ny + avp.h) >= (my + mh - 12))

    if hit_edge and _G.Canvas.enabled then
        local ws = hl.get_active_workspace()
        if ws then
            for _, w in ipairs(get_ws_windows(ws.id)) do
                if w.floating and w.address ~= active.address then
                    local vp = ensure_vp(w)
                    apply_win_geom(w, vp.x - dx, vp.y - dy, nil, nil)
                end
            end
        end
        hl.dispatch(hl.dsp.focus({ window = active }))
    else
        apply_win_geom(active, nx, ny, nil, nil)
    end
    save_persisted_state()
end

function _G.Canvas.focus_cycle(dir)
    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    if #wins == 0 then return end

    local active = hl.get_active_window()
    local cur_addr = active and active.address or ""
    local cur_idx = 1
    for i, w in ipairs(wins) do
        if w.address == cur_addr then
            cur_idx = i
            break
        end
    end

    local step = (dir == "next") and 1 or -1
    local next_idx = ((cur_idx - 1 + step) % #wins) + 1
    local target = wins[next_idx]
    pan_canvas_to_window(wins, target)
end

function _G.Canvas.gather_home()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    if #wins == 0 then return end

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    local placed = {}
    for _, w in ipairs(wins) do
        local key = norm_addr(w.address)
        local vp = ensure_vp(w)
        local tx, ty = find_free_spot(vp.w, vp.h, cx, cy, key, placed)
        apply_win_geom(w, tx, ty, nil, nil)
        table.insert(placed, { addr = key, x = tx, y = ty, w = vp.w, h = vp.h })
    end
    if wins[1] then
        pan_canvas_to_window(wins, wins[1])
    end
    save_persisted_state()
end

function _G.Canvas.toggle_invert()
    _G.Canvas.inverted = not _G.Canvas.inverted
    save_persisted_state()
end

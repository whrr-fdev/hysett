-- ============================================================================
-- HySett Infinite Canvas (Бесконечный холст для Hyprland Lua)
-- ============================================================================

_G.Canvas = _G.Canvas or {
    enabled = false,
    panning = false,
    inverted = false,
    speed = 1.35,
    saved_state = {},
    virtual_pos = {},
}

local PANLOCK_FILE = "/tmp/hysett_canvas_panlock"

local IGNORED_CLASSES = {
    ["hypratmooverlay"] = true,
    ["hysett"] = true,
    ["waybar"] = true,
    ["mako"] = true,
}

local function notify(title, body)
    hl.exec_cmd("notify-send -a 'HySett Canvas' '" .. title .. "' '" .. body .. "'")
end

local function is_canvas_win(w, ws_id)
    if not w then return false end
    if not w.workspace or w.workspace.id ~= ws_id then return false end
    if w.pinned then return false end
    local cls = string.lower(w.class or "")
    if IGNORED_CLASSES[cls] then return false end
    if w.title == "HySettAtmosphereOverlay" then return false end
    return true
end

local function get_ws_windows(ws_id)
    local list = {}
    for _, w in pairs(hl.get_windows()) do
        if is_canvas_win(w, ws_id) then
            table.insert(list, w)
        end
    end
    table.sort(list, function(a, b) return tostring(a.address) < tostring(b.address) end)
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

local function move_win_exact(w, x, y)
    local ix = math.floor(x + 0.5)
    local iy = math.floor(y + 0.5)
    _G.Canvas.virtual_pos[w.address] = { x = ix, y = iy }
    hl.dispatch(hl.dsp.window.move({
        x = ix,
        y = iy,
        relative = false,
        window = w,
    }))
end

local function resize_win_exact(w, width, height)
    local iw = math.max(220, math.floor(width + 0.5))
    local ih = math.max(160, math.floor(height + 0.5))
    hl.dispatch(hl.dsp.window.resize({
        x = iw,
        y = ih,
        relative = false,
        window = w,
    }))
end

local function focus_and_raise(w)
    if not w then return end
    hl.dispatch(hl.dsp.focus({ window = w }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

function _G.Canvas.pan_delta(raw_dx, raw_dy)
    if not _G.Canvas.enabled then return end
    local sgn = _G.Canvas.inverted and -1.0 or 1.0
    local dx = raw_dx * _G.Canvas.speed * sgn
    local dy = raw_dy * _G.Canvas.speed * sgn
    if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end

    local ws = hl.get_active_workspace()
    if not ws then return end
    for _, w in pairs(hl.get_windows()) do
        if is_canvas_win(w, ws.id) and w.floating then
            local vp = _G.Canvas.virtual_pos[w.address]
            local cur_x = vp and vp.x or w.at.x
            local cur_y = vp and vp.y or w.at.y
            move_win_exact(w, cur_x + dx, cur_y + dy)
        end
    end
end

-- Сдвиг остальных окон при перетаскивании активного окна (Super+ЛКМ) к краю экрана
function _G.Canvas.edge_push(raw_dx, raw_dy)
    if not _G.Canvas.enabled then return end
    local active = hl.get_active_window()
    if not active or not active.floating then return end

    local mx, my, mw, mh = get_monitor_box()
    local margin = 16
    local ax, ay = active.at.x, active.at.y
    local aw, ah = active.size.x, active.size.y

    local push_x, push_y = 0, 0
    if ax <= mx + margin and raw_dx < 0 then
        push_x = -raw_dx
    elseif (ax + aw) >= (mx + mw - margin) and raw_dx > 0 then
        push_x = -raw_dx
    end

    if ay <= my + margin and raw_dy < 0 then
        push_y = -raw_dy
    elseif (ay + ah) >= (my + mh - margin) and raw_dy > 0 then
        push_y = -raw_dy
    end

    if push_x == 0 and push_y == 0 then return end

    local ws = hl.get_active_workspace()
    if not ws then return end
    for _, w in pairs(hl.get_windows()) do
        if is_canvas_win(w, ws.id) and w.floating and w.address ~= active.address then
            local vp = _G.Canvas.virtual_pos[w.address]
            local cur_x = vp and vp.x or w.at.x
            local cur_y = vp and vp.y or w.at.y
            move_win_exact(w, cur_x + push_x, cur_y + push_y)
        end
    end
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
    notify("Бесконечный холст", _G.Canvas.panning and "Фиксация перемещения мыши ВКЛЮЧЕНА" or "Фиксация перемещения мыши ВЫКЛЮЧЕНА")
end

-- Включение / выключение режима Бесконечного Холста
function _G.Canvas.toggle()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    if not _G.Canvas.enabled then
        _G.Canvas.enabled = true
        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        os.remove(PANLOCK_FILE)

        local active = hl.get_active_window()
        local active_addr = active and active.address or ""
        local wins = get_ws_windows(ws.id)
        local count = #wins

        local tw_base = math.floor(mw * 0.62 + 0.5)
        local th_base = math.floor(mh * 0.62 + 0.5)
        local ring_idx = 0
        local others = math.max(1, count - 1)

        for _, w in ipairs(wins) do
            local ox, oy = w.at.x, w.at.y
            local ow, oh = w.size.x, w.size.y
            local was_float = w.floating

            _G.Canvas.saved_state[w.address] = {
                was_float = was_float,
                x = ox,
                y = oy,
                w = ow,
                h = oh,
            }

            if not was_float then
                hl.dispatch(hl.dsp.window.float({ action = "on", window = w }))
            end

            local tw = was_float and math.min(ow, math.floor(mw * 0.78)) or tw_base
            local th = was_float and math.min(oh, math.floor(mh * 0.78)) or th_base
            local tx, ty

            if w.address == active_addr or count == 1 then
                tx = cx - tw * 0.5
                ty = cy - th * 0.5
            else
                ring_idx = ring_idx + 1
                local angle = (ring_idx - 1) * (2.0 * math.pi / others)
                local rad_x = math.floor(mw * 0.58)
                local rad_y = math.floor(mh * 0.52)
                tx = cx + math.cos(angle) * rad_x - tw * 0.5
                ty = cy + math.sin(angle) * rad_y - th * 0.5
            end

            resize_win_exact(w, tw, th)
            move_win_exact(w, tx, ty)
        end

        if active then
            focus_and_raise(active)
        end

        hl.exec_cmd("pkill -f 'hysett_infinite_canvas.py start_evdev'; python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py start_evdev &")
        notify("Бесконечный холст ВКЛЮЧЕН", "Super+Alt+Мышь — двигать холст | Super+←/→/↑/↓ — к окну | Super+Shift+←/→/↑/↓ — двигать окно | Super+I — выход")
    else
        _G.Canvas.enabled = false
        _G.Canvas.panning = false
        os.remove(PANLOCK_FILE)
        hl.exec_cmd("pkill -f 'hysett_infinite_canvas.py start_evdev'")

        local wins = get_ws_windows(ws.id)
        for _, w in ipairs(wins) do
            local st = _G.Canvas.saved_state[w.address]
            if st then
                if not st.was_float then
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                else
                    resize_win_exact(w, st.w, st.h)
                    move_win_exact(w, st.x, st.y)
                end
            elseif w.floating then
                hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
            end
        end

        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        notify("Бесконечный холст ВЫКЛЮЧЕН", "Возврат к обычному рабочему столу")
    end
end

local function pan_canvas_to_window(wins, target)
    if not target then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    local tcx = target.at.x + target.size.x * 0.5
    local tcy = target.at.y + target.size.y * 0.5
    local dx = cx - tcx
    local dy = cy - tcy

    for _, w in ipairs(wins) do
        move_win_exact(w, w.at.x + dx, w.at.y + dy)
    end
    focus_and_raise(target)
end

-- Навигация по направлениям (left / right / up / down) как в sarodscommits/hyprland-infinitie-desktop-v2
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

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5
    local active = hl.get_active_window()
    local ref = active or wins[1]
    local rx = ref.at.x + ref.size.x * 0.5
    local ry = ref.at.y + ref.size.y * 0.5
    local rl, rr = ref.at.x, ref.at.x + ref.size.x
    local rt, rb = ref.at.y, ref.at.y + ref.size.y

    local best_aligned, best_aligned_dist = nil, 1e18
    local best_dir, best_dir_dist = nil, 1e18
    local best_wrap, best_wrap_dist = nil, -1

    for _, w in ipairs(wins) do
        if w.address ~= ref.address then
            local wx = w.at.x + w.size.x * 0.5
            local wy = w.at.y + w.size.y * 0.5
            local wl, wr = w.at.x, w.at.x + w.size.x
            local wt, wb = w.at.y, w.at.y + w.size.y
            local overlap_v = not (wb <= rt or wt >= rb)
            local overlap_h = not (wr <= rl or wl >= rr)

            local in_dir = false
            local dist = 0
            local aligned = false

            if dir == "left" and wx < rx - 5 then
                in_dir = true
                dist = (rx - wx) + math.abs(ry - wy) * 0.35
                aligned = overlap_v
            elseif dir == "right" and wx > rx + 5 then
                in_dir = true
                dist = (wx - rx) + math.abs(ry - wy) * 0.35
                aligned = overlap_v
            elseif dir == "up" and wy < ry - 5 then
                in_dir = true
                dist = (ry - wy) + math.abs(rx - wx) * 0.35
                aligned = overlap_h
            elseif dir == "down" and wy > ry + 5 then
                in_dir = true
                dist = (wy - ry) + math.abs(rx - wx) * 0.35
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

-- Сдвиг активного плавающего окна стрелками Super+Shift+Arrows с толканием холста у границ экрана
function _G.Canvas.move_or_swap(dir)
    local active = hl.get_active_window()
    if not _G.Canvas.enabled and (not active or not active.floating) then
        local map = { left = "l", right = "r", up = "u", down = "d", l = "l", r = "r", u = "u", d = "d" }
        hl.dispatch(hl.dsp.window.swap({ direction = map[dir] or dir }))
        return
    end
    if not active or not active.floating then return end

    local step = 48
    local dx, dy = 0, 0
    if dir == "left" or dir == "l" then dx = -step
    elseif dir == "right" or dir == "r" then dx = step
    elseif dir == "up" or dir == "u" then dy = -step
    elseif dir == "down" or dir == "d" then dy = step end

    local mx, my, mw, mh = get_monitor_box()
    local nx = active.at.x + dx
    local ny = active.at.y + dy
    local aw, ah = active.size.x, active.size.y

    local hit_edge = (dx < 0 and nx <= mx + 12)
                  or (dx > 0 and (nx + aw) >= (mx + mw - 12))
                  or (dy < 0 and ny <= my + 12)
                  or (dy > 0 and (ny + ah) >= (my + mh - 12))

    if hit_edge and _G.Canvas.enabled then
        local ws = hl.get_active_workspace()
        if ws then
            for _, w in ipairs(get_ws_windows(ws.id)) do
                if w.floating and w.address ~= active.address then
                    move_win_exact(w, w.at.x - dx, w.at.y - dy)
                end
            end
        end
    else
        move_win_exact(active, nx, ny)
    end
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

function _G.Canvas.zoom(factor)
    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    if #wins == 0 then return end

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    for _, w in ipairs(wins) do
        local wx, wy = w.at.x, w.at.y
        local ww, wh = w.size.x, w.size.y
        local wcx = wx + ww * 0.5
        local wcy = wy + wh * 0.5

        local nw = math.max(260, math.min(math.floor(mw * 0.94), math.floor(ww * factor + 0.5)))
        local nh = math.max(180, math.min(math.floor(mh * 0.92), math.floor(wh * factor + 0.5)))
        local ncx = cx + (wcx - cx) * factor
        local ncy = cy + (wcy - cy) * factor
        local nx = ncx - nw * 0.5
        local ny = ncy - nh * 0.5

        resize_win_exact(w, nw, nh)
        move_win_exact(w, nx, ny)
    end
end

function _G.Canvas.gather_home()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    local n = #wins
    if n == 0 then return end

    local mx, my, mw, mh = get_monitor_box()
    local cols = math.ceil(math.sqrt(n))
    local rows = math.ceil(n / cols)
    local pad_x, pad_y = 32, 48
    local cell_w = math.floor((mw - pad_x * 2) / cols)
    local cell_h = math.floor((mh - pad_y - 32) / rows)

    for i, w in ipairs(wins) do
        local r = math.floor((i - 1) / cols)
        local c = (i - 1) % cols
        local tw = math.min(cell_w - 20, w.size.x)
        local th = math.min(cell_h - 20, w.size.y)
        local tx = mx + pad_x + c * cell_w + math.floor((cell_w - tw) * 0.5)
        local ty = my + pad_y + r * cell_h + math.floor((cell_h - th) * 0.5)

        resize_win_exact(w, tw, th)
        move_win_exact(w, tx, ty)
    end
    notify("Бесконечный холст", "Все окна собраны в центр экрана")
end

function _G.Canvas.toggle_invert()
    _G.Canvas.inverted = not _G.Canvas.inverted
    notify("Бесконечный холст", "Направление перетаскивания: " .. (_G.Canvas.inverted and "Инвертированное" or "Обычное"))
end

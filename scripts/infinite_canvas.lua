-- ============================================================================
-- HySett Infinite Canvas (Бесконечный холст для Hyprland Lua)
-- ============================================================================

_G.Canvas = _G.Canvas or {
    enabled = false,
    panning = false,
    inverted = false,
    speed = 1.45,
    zoom_scale = 1.0,
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

-- Спиральный порядок ячеек вокруг центра (0, 0), чтобы окна никогда не перекрывались
local SPIRAL_CELLS = {
    { 0,  0},
    { 1,  0}, {-1,  0}, { 0,  1}, { 0, -1},
    { 1,  1}, {-1,  1}, {-1, -1}, { 1, -1},
    { 2,  0}, {-2,  0}, { 0,  2}, { 0, -2},
    { 2,  1}, { 2, -1}, {-2,  1}, {-2, -1},
    { 1,  2}, {-1,  2}, { 1, -2}, {-1, -2},
    { 2,  2}, {-2,  2}, {-2, -2}, { 2, -2},
    { 3,  0}, {-3,  0}, { 0,  3}, { 0, -3},
}

local function get_spiral_cell(idx)
    if idx <= #SPIRAL_CELLS then
        return SPIRAL_CELLS[idx][1], SPIRAL_CELLS[idx][2]
    end
    local cols = math.ceil(math.sqrt(idx))
    local r = math.floor((idx - 1) / cols)
    local c = ((idx - 1) % cols) - math.floor(cols / 2)
    return c, r
end

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

local function ensure_vp(w)
    local vp = _G.Canvas.virtual_pos[w.address]
    if not vp then
        vp = {
            x = w.at.x,
            y = w.at.y,
            w = w.size.x,
            h = w.size.y,
        }
        _G.Canvas.virtual_pos[w.address] = vp
    end
    return vp
end

local function apply_win_geom(w, x, y, width, height)
    local vp = ensure_vp(w)
    if width and height then
        local iw = math.max(240, math.floor(width + 0.5))
        local ih = math.max(160, math.floor(height + 0.5))
        vp.w = iw
        vp.h = ih
        hl.dispatch(hl.dsp.window.resize({
            x = iw,
            y = ih,
            relative = false,
            window = w,
        }))
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
            window = w,
        }))
    end
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
            local vp = ensure_vp(w)
            apply_win_geom(w, vp.x + dx, vp.y + dy, nil, nil)
        end
    end
end

function _G.Canvas.edge_push(raw_dx, raw_dy)
    if not _G.Canvas.enabled then return end
    local active = hl.get_active_window()
    if not active or not active.floating then return end

    local mx, my, mw, mh = get_monitor_box()
    local margin = 18
    local ax, ay = active.at.x, active.at.y
    local aw, ah = active.size.x, active.size.y
    _G.Canvas.virtual_pos[active.address] = { x = ax, y = ay, w = aw, h = ah }

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
            local vp = ensure_vp(w)
            apply_win_geom(w, vp.x + push_x, vp.y + push_y, nil, nil)
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
    notify("Бесконечный холст", _G.Canvas.panning and "Режим панорамирования мыши ВКЛЮЧЕН" or "Режим панорамирования мыши ВЫКЛЮЧЕН")
end

-- Включение / выключение режима Бесконечного Холста (окна раскладываются раздельно по сетке без наложений)
function _G.Canvas.toggle()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    if not _G.Canvas.enabled then
        _G.Canvas.enabled = true
        _G.Canvas.zoom_scale = 1.0
        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        os.remove(PANLOCK_FILE)

        local active = hl.get_active_window()
        local wins = get_ws_windows(ws.id)
        local active_addr = (active and active.address) or (wins[1] and wins[1].address) or ""

        -- Базовый размер карточки окна на холсте и гарантированный зазор между ними
        local card_w = math.floor(mw * 0.46 + 0.5)
        local card_h = math.floor(mh * 0.46 + 0.5)
        local gap_x  = 96
        local gap_y  = 84
        local step_x = card_w + gap_x
        local step_y = card_h + gap_y

        -- Упорядочиваем так, чтобы активное окно получило центральную ячейку (0, 0)
        local ordered = {}
        for _, w in ipairs(wins) do
            if w.address == active_addr then
                table.insert(ordered, 1, w)
            else
                table.insert(ordered, w)
            end
        end

        for idx, w in ipairs(ordered) do
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

            local gx, gy = get_spiral_cell(idx)
            local tx = cx + gx * step_x - card_w * 0.5
            local ty = cy + gy * step_y - card_h * 0.5

            apply_win_geom(w, tx, ty, card_w, card_h)
        end

        if ordered[1] then
            focus_and_raise(ordered[1])
        end

        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py start_evdev &")
        notify("Бесконечный холст ВКЛЮЧЕН", "Super+Alt+Мышь — двигать холст | Super+Стрелки — к окну | Ctrl+Super+←/→ — цикл | Super+I — выход")
    else
        _G.Canvas.enabled = false
        _G.Canvas.panning = false
        os.remove(PANLOCK_FILE)
        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py stop_evdev &")

        local wins = get_ws_windows(ws.id)
        for _, w in ipairs(wins) do
            local st = _G.Canvas.saved_state[w.address]
            if st then
                if not st.was_float then
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                else
                    apply_win_geom(w, st.x, st.y, st.w, st.h)
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

    local step = 52
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
    else
        apply_win_geom(active, nx, ny, nil, nil)
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

-- Масштабирование с сохранением пропорций сетки, чтобы окна никогда не налезали друг на друга
function _G.Canvas.zoom(factor)
    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    if #wins == 0 then return end

    local cur_scale = _G.Canvas.zoom_scale or 1.0
    local new_scale = math.max(0.42, math.min(1.65, cur_scale * factor))
    local eff = new_scale / cur_scale
    if math.abs(eff - 1.0) < 0.005 then return end
    _G.Canvas.zoom_scale = new_scale

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    for _, w in ipairs(wins) do
        local vp = ensure_vp(w)
        local wcx = vp.x + vp.w * 0.5
        local wcy = vp.y + vp.h * 0.5

        local nw = vp.w * eff
        local nh = vp.h * eff
        local ncx = cx + (wcx - cx) * eff
        local ncy = cy + (wcy - cy) * eff
        local nx = ncx - nw * 0.5
        local ny = ncy - nh * 0.5

        apply_win_geom(w, nx, ny, nw, nh)
    end
end

-- Собрать все окна на экране раздельной таблицей без перекрытий
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
    local pad_x, pad_y = 28, 44
    local gap = 22
    local cell_w = math.floor((mw - pad_x * 2) / cols)
    local cell_h = math.floor((mh - pad_y - 28) / rows)
    local tw = math.max(240, cell_w - gap)
    local th = math.max(160, cell_h - gap)

    for i, w in ipairs(wins) do
        local r = math.floor((i - 1) / cols)
        local c = (i - 1) % cols
        local tx = mx + pad_x + c * cell_w + math.floor((cell_w - tw) * 0.5)
        local ty = my + pad_y + r * cell_h + math.floor((cell_h - th) * 0.5)

        apply_win_geom(w, tx, ty, tw, th)
    end
    notify("Бесконечный холст", "Все окна разложены без перекрытий")
end

function _G.Canvas.toggle_invert()
    _G.Canvas.inverted = not _G.Canvas.inverted
    notify("Бесконечный холст", "Направление перетаскивания: " .. (_G.Canvas.inverted and "Инвертированное" or "Обычное"))
end

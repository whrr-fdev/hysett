-- ============================================================================
-- HySett Infinite Canvas (Бесконечный холст для Hyprland Lua)
-- ============================================================================

_G.Canvas = _G.Canvas or {
    enabled = false,
    panning = false,
    inverted = false,
    speed = 1.45,
    zoom_factor = 1.0,
    active_ws_id = 1,
    saved_state = {},
    virtual_pos = {},
}

local PANLOCK_FILE = "/tmp/hysett_canvas_panlock"
local GAP_X = 96
local GAP_Y = 84

local IGNORED_CLASSES = {
    ["hypratmooverlay"] = true,
    ["hysett"] = true,
    ["waybar"] = true,
    ["mako"] = true,
}

local SPIRAL_CELLS = {}
for ring = 0, 8 do
    if ring == 0 then
        table.insert(SPIRAL_CELLS, { 0, 0 })
    else
        table.insert(SPIRAL_CELLS, {  ring,  0 })
        table.insert(SPIRAL_CELLS, { -ring,  0 })
        table.insert(SPIRAL_CELLS, {  0,  ring })
        table.insert(SPIRAL_CELLS, {  0, -ring })
        for d = 1, ring - 1 do
            table.insert(SPIRAL_CELLS, {  ring,  d })
            table.insert(SPIRAL_CELLS, {  ring, -d })
            table.insert(SPIRAL_CELLS, { -ring,  d })
            table.insert(SPIRAL_CELLS, { -ring, -d })
            table.insert(SPIRAL_CELLS, {  d,  ring })
            table.insert(SPIRAL_CELLS, { -d,  ring })
            table.insert(SPIRAL_CELLS, {  d, -ring })
            table.insert(SPIRAL_CELLS, { -d, -ring })
        end
        table.insert(SPIRAL_CELLS, {  ring,  ring })
        table.insert(SPIRAL_CELLS, { -ring,  ring })
        table.insert(SPIRAL_CELLS, { -ring, -ring })
        table.insert(SPIRAL_CELLS, {  ring, -ring })
    end
end

local function notify(title, body)
    hl.exec_cmd("notify-send -a 'HySett Canvas' '" .. title .. "' '" .. body .. "'")
end

local function norm_addr(a)
    local s = string.lower(tostring(a or ""))
    if s ~= "" and not string.find(s, "^0x") then
        s = "0x" .. s
    end
    return s
end

-- Окно подходит для холста, если оно на рабочих столах 1..9 (10-й стол — скрытый трей)
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

local function get_all_user_windows()
    local list = {}
    for _, w in pairs(hl.get_windows()) do
        if is_valid_win(w) then
            table.insert(list, w)
        end
    end
    table.sort(list, function(a, b)
        local wa = (a.workspace and a.workspace.id) or 0
        local wb = (b.workspace and b.workspace.id) or 0
        if wa ~= wb then return wa < wb end
        return tostring(a.address) < tostring(b.address)
    end)
    return list
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

-- Проверка пересечения прямоугольника (x, y, w, h) с уже размещёнными окнами на холсте
local function rect_overlaps_any(x, y, w, h, ignore_addr, placed_list)
    local l1 = x - GAP_X * 0.85
    local r1 = x + w + GAP_X * 0.85
    local t1 = y - GAP_Y * 0.85
    local b1 = y + h + GAP_Y * 0.85

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

-- Поиск ближайшего свободного места на холсте вокруг точки (origin_cx, origin_cy) без перекрытий
local function find_free_spot(win_w, win_h, origin_cx, origin_cy, ignore_addr, placed_list)
    local step_x = math.max(win_w, 860) + GAP_X
    local step_y = math.max(win_h, 540) + GAP_Y

    for _, cell in ipairs(SPIRAL_CELLS) do
        local tx = origin_cx + cell[1] * step_x - win_w * 0.5
        local ty = origin_cy + cell[2] * step_y - win_h * 0.5
        if not rect_overlaps_any(tx, ty, win_w, win_h, ignore_addr, placed_list) then
            return tx, ty
        end
    end

    local fallback_x = origin_cx + (#placed_list + 1) * step_x - win_w * 0.5
    local fallback_y = origin_cy - win_h * 0.5
    return fallback_x, fallback_y
end

-- Выбор размера окна на холсте без сжатия его содержимого
local function pick_canvas_size(w, mw, mh)
    local ow, oh = w.size.x, w.size.y
    -- Если окно уже было меньше полного экрана (в сплите или плавающим) — сохраняем его точный размер!
    if ow <= math.floor(mw * 0.82) and oh <= math.floor(mh * 0.85) then
        return ow, oh
    end
    -- Если окно было развёрнуто во весь тайловый экран (1900x1028), даём полноценный крупный размер без поломки вёрстки
    return math.min(ow, math.floor(mw * 0.68)), math.min(oh, math.floor(mh * 0.72))
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
    _G.Canvas.virtual_pos[norm_addr(active.address)] = { x = ax, y = ay, w = aw, h = ah }

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

-- Обработка открытия НОВОГО окна: ставим на свободное место и двигаем камеру, чтобы оно стало посередине экрана
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

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    if new_win.workspace.id ~= ws.id then
        hl.dispatch(hl.dsp.window.move({
            workspace = ws.id,
            window = new_win,
            follow = false,
        }))
    end

    if not new_win.floating then
        hl.dispatch(hl.dsp.window.float({ action = "on", window = new_win }))
    end

    local nw, nh = pick_canvas_size(new_win, mw, mh)

    -- Собираем список уже стоящих на холсте окон
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

    -- Находим ближайшее свободное место на холсте
    local free_x, free_y = find_free_spot(nw, nh, cx, cy, target_key, placed)
    local free_cx = free_x + nw * 0.5
    local free_cy = free_y + nh * 0.5

    -- Сдвигаем камеру (все остальные окна на вектор dx, dy), чтобы новое окно встало ровно в центр экрана (cx, cy)
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
end

-- Включение / выключение режима Бесконечного Холста (собирает окна со ВСЕХ рабочих столов 1..9 и возвращает обратно)
function _G.Canvas.toggle()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    if not _G.Canvas.enabled then
        _G.Canvas.enabled = true
        _G.Canvas.zoom_factor = 1.0
        _G.Canvas.active_ws_id = ws.id
        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        os.remove(PANLOCK_FILE)

        local active = hl.get_active_window()
        local all_wins = get_all_user_windows()
        local active_key = (active and norm_addr(active.address)) or (all_wins[1] and norm_addr(all_wins[1].address)) or ""

        -- Активное окно ставим первым (в центр 0,0), затем окна текущего стола, затем окна остальных столов
        local ordered = {}
        for _, w in ipairs(all_wins) do
            if norm_addr(w.address) == active_key then
                table.insert(ordered, 1, w)
            elseif w.workspace.id == ws.id then
                table.insert(ordered, w)
            end
        end
        for _, w in ipairs(all_wins) do
            if norm_addr(w.address) ~= active_key and w.workspace.id ~= ws.id then
                table.insert(ordered, w)
            end
        end

        local placed = {}
        for _, w in ipairs(ordered) do
            local key = norm_addr(w.address)
            local ox, oy = w.at.x, w.at.y
            local ow, oh = w.size.x, w.size.y
            local was_float = w.floating
            local orig_ws = w.workspace.id

            _G.Canvas.saved_state[key] = {
                workspace_id = orig_ws,
                was_float = was_float,
                x = ox,
                y = oy,
                w = ow,
                h = oh,
            }

            if orig_ws ~= ws.id then
                hl.dispatch(hl.dsp.window.move({
                    workspace = ws.id,
                    window = w,
                    follow = false,
                }))
            end

            if not was_float then
                hl.dispatch(hl.dsp.window.float({ action = "on", window = w }))
            end

            local tw, th = pick_canvas_size(w, mw, mh)
            local tx, ty = find_free_spot(tw, th, cx, cy, key, placed)

            apply_win_geom(w, tx, ty, tw, th)
            table.insert(placed, { addr = key, x = tx, y = ty, w = tw, h = th })
        end

        if ordered[1] then
            focus_and_raise(ordered[1])
        end

        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py start_evdev &")
        notify("Бесконечный холст ВКЛЮЧЕН", "Окна со всех столов собраны на холсте | Super+Alt+Мышь — двигать | Super+Стрелки — к окну | Super+I — выход")
    else
        _G.Canvas.enabled = false
        _G.Canvas.panning = false
        _G.Canvas.zoom_factor = 1.0
        os.remove(PANLOCK_FILE)
        hl.exec_cmd("hyprctl keyword cursor:zoom_factor 1.0 >/dev/null 2>&1 &")
        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py stop_evdev &")

        local all_wins = get_all_user_windows()
        -- Сортируем по исходным координатам (x, y), чтобы тайловые окна возвращались в свои сплиты в том же порядке
        table.sort(all_wins, function(a, b)
            local sa = _G.Canvas.saved_state[norm_addr(a.address)]
            local sb = _G.Canvas.saved_state[norm_addr(b.address)]
            if sa and sb then
                if sa.workspace_id ~= sb.workspace_id then
                    return sa.workspace_id < sb.workspace_id
                end
                if math.abs(sa.x - sb.x) > 20 then
                    return sa.x < sb.x
                end
                return sa.y < sb.y
            end
            return tostring(a.address) < tostring(b.address)
        end)

        for _, w in ipairs(all_wins) do
            local key = norm_addr(w.address)
            local st = _G.Canvas.saved_state[key]
            if st then
                -- Сначала ставим окно в его исходные координаты и размер
                apply_win_geom(w, st.x, st.y, st.w, st.h)

                if not st.was_float then
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                end

                if st.workspace_id and w.workspace.id ~= st.workspace_id then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = st.workspace_id,
                        window = w,
                        follow = false,
                    }))
                end
            else
                -- Окна, открытые уже во время работы холста, возвращаем в обычный тайлинг
                if w.floating then
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                end
            end
        end

        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}
        notify("Бесконечный холст ВЫКЛЮЧЕН", "Все окна возвращены на свои рабочие столы и позиции")
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

-- Масштабирование через GPU cursor:zoom_factor (без уменьшения физического размера окон и их содержимого)
function _G.Canvas.zoom(factor)
    if not _G.Canvas.enabled then return end
    local zf = (_G.Canvas.zoom_factor or 1.0) * factor
    zf = math.max(1.0, math.min(3.0, zf))
    _G.Canvas.zoom_factor = zf
    hl.exec_cmd(string.format("hyprctl keyword cursor:zoom_factor %.2f >/dev/null 2>&1 &", zf))
end

-- Упорядочить все окна по сетке без уменьшения их размера и без перекрытий
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
        focus_and_raise(wins[1])
    end
    notify("Бесконечный холст", "Все окна аккуратно разложены вокруг центра")
end

function _G.Canvas.toggle_invert()
    _G.Canvas.inverted = not _G.Canvas.inverted
    notify("Бесконечный холст", "Направление перетаскивания: " .. (_G.Canvas.inverted and "Инвертированное" or "Обычное"))
end

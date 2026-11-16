-- ============================================================================
-- HySett Infinite Canvas (Бесконечный холст для Hyprland Lua)
-- ============================================================================

_G.Canvas = _G.Canvas or {
    enabled = false,
    panning = false,
    inverted = false,
    speed = 1.35,
    last_cursor = nil,
    saved_state = {},
    virtual_pos = {},
}

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
        return m.x or 0, m.y or 0, m.width or 1920, m.height or 1080
    end
    return 0, 0, 1920, 1080
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
            local addr = w.address
            local vp = _G.Canvas.virtual_pos[addr]
            if not vp then
                vp = { x = w.at.x, y = w.at.y }
            end
            vp.x = vp.x + dx
            vp.y = vp.y + dy
            _G.Canvas.virtual_pos[addr] = vp
            hl.dispatch(hl.dsp.window.move({
                x = math.floor(vp.x + 0.5),
                y = math.floor(vp.y + 0.5),
                window = w,
            }))
        end
    end
end

local function pan_loop()
    if not _G.Canvas.enabled or not _G.Canvas.panning then
        _G.Canvas.last_cursor = nil
        return
    end

    local cp = hl.get_cursor_pos()
    if cp and _G.Canvas.last_cursor then
        local raw_dx = cp.x - _G.Canvas.last_cursor.x
        local raw_dy = cp.y - _G.Canvas.last_cursor.y
        _G.Canvas.last_cursor = { x = cp.x, y = cp.y }
        _G.Canvas.pan_delta(raw_dx, raw_dy)
    elseif cp then
        _G.Canvas.last_cursor = { x = cp.x, y = cp.y }
    end

    pcall(hl.timer, pan_loop, { type = "oneshot", timeout = 8 })
end

function _G.Canvas.set_panning(active)
    if not _G.Canvas.enabled then
        _G.Canvas.panning = false
        return
    end
    if active and not _G.Canvas.panning then
        _G.Canvas.panning = true
        local cp = hl.get_cursor_pos()
        _G.Canvas.last_cursor = cp and { x = cp.x, y = cp.y } or nil
        local ws = hl.get_active_workspace()
        if ws then
            for _, w in pairs(hl.get_windows()) do
                if is_canvas_win(w, ws.id) and w.floating then
                    _G.Canvas.virtual_pos[w.address] = { x = w.at.x, y = w.at.y }
                end
            end
        end
        pcall(hl.timer, pan_loop, { type = "oneshot", timeout = 8 })
    elseif not active then
        _G.Canvas.panning = false
        _G.Canvas.last_cursor = nil
    end
end

function _G.Canvas.toggle_pan_lock()
    if not _G.Canvas.enabled then return end
    _G.Canvas.set_panning(not _G.Canvas.panning)
end

-- Включение / выключение режима Бесконечного Холста с пружинной анимацией отдаления (Zoom-Out)
function _G.Canvas.toggle()
    local ws = hl.get_active_workspace()
    if not ws then return end
    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

    if not _G.Canvas.enabled then
        _G.Canvas.enabled = true
        _G.Canvas.saved_state = {}
        _G.Canvas.virtual_pos = {}

        local wins = get_ws_windows(ws.id)
        local count = #wins
        local zoom_scale = (count <= 1) and 0.72 or 0.65
        local spread = (count <= 1) and 1.0 or 1.25

        for i, w in ipairs(wins) do
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

            local wcx = ox + ow * 0.5
            local wcy = oy + oh * 0.5
            local tw = math.max(380, math.floor(ow * zoom_scale + 0.5))
            local th = math.max(260, math.floor(oh * zoom_scale + 0.5))

            local dx_from_center = (wcx - cx) * spread
            local dy_from_center = (wcy - cy) * spread
            if count > 1 and math.abs(dx_from_center) < 40 and math.abs(dy_from_center) < 40 then
                local angle = (i - 1) * (2.0 * math.pi / count)
                dx_from_center = math.cos(angle) * 280
                dy_from_center = math.sin(angle) * 170
            end

            local tx = math.floor(cx + dx_from_center - tw * 0.5 + 0.5)
            local ty = math.floor(cy + dy_from_center - th * 0.5 + 0.5)

            hl.dispatch(hl.dsp.window.resize({ x = tw, y = th, window = w }))
            hl.dispatch(hl.dsp.window.move({ x = tx, y = ty, window = w }))
            _G.Canvas.virtual_pos[w.address] = { x = tx, y = ty }
        end

        hl.exec_cmd("pkill -f 'hysett_infinite_canvas.py start_evdev'; python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py start_evdev &")
        notify("Бесконечный холст ВКЛЮЧЕН", "Super+Alt+ЛКМ — двигать холст | Ctrl+Super+←/→ — перелёт к окну | Super+Alt+Колесо — зум | Super+I — выход")
    else
        _G.Canvas.enabled = false
        _G.Canvas.panning = false
        hl.exec_cmd("pkill -f 'hysett_infinite_canvas.py start_evdev'")

        local wins = get_ws_windows(ws.id)
        for _, w in ipairs(wins) do
            local st = _G.Canvas.saved_state[w.address]
            if st then
                if not st.was_float then
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                else
                    hl.dispatch(hl.dsp.window.resize({ x = st.w, y = st.h, window = w }))
                    hl.dispatch(hl.dsp.window.move({ x = st.x, y = st.y, window = w }))
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

function _G.Canvas.focus_cycle(dir)
    local ws = hl.get_active_workspace()
    if not ws then return end
    local wins = {}
    for _, w in ipairs(get_ws_windows(ws.id)) do
        if w.floating then table.insert(wins, w) end
    end
    if #wins == 0 then return end

    local mx, my, mw, mh = get_monitor_box()
    local cx, cy = mx + mw * 0.5, my + mh * 0.5

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
    if not target then return end

    local tcx = target.at.x + target.size.x * 0.5
    local tcy = target.at.y + target.size.y * 0.5
    local dx = math.floor(cx - tcx + 0.5)
    local dy = math.floor(cy - tcy + 0.5)

    for _, w in ipairs(wins) do
        local nx = w.at.x + dx
        local ny = w.at.y + dy
        _G.Canvas.virtual_pos[w.address] = { x = nx, y = ny }
        hl.dispatch(hl.dsp.window.move({ x = nx, y = ny, window = w }))
    end

    hl.dispatch(hl.dsp.focus({ window = target }))
    hl.dispatch(hl.dsp.window.bring_to_top({ window = target }))
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
        local nx = math.floor(ncx - nw * 0.5 + 0.5)
        local ny = math.floor(ncy - nh * 0.5 + 0.5)

        _G.Canvas.virtual_pos[w.address] = { x = nx, y = ny }
        hl.dispatch(hl.dsp.window.resize({ x = nw, y = nh, window = w }))
        hl.dispatch(hl.dsp.window.move({ x = nx, y = ny, window = w }))
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

        _G.Canvas.virtual_pos[w.address] = { x = tx, y = ty }
        hl.dispatch(hl.dsp.window.resize({ x = tw, y = th, window = w }))
        hl.dispatch(hl.dsp.window.move({ x = tx, y = ty, window = w }))
    end
    notify("Бесконечный холст", "Все окна собраны в центр экрана")
end

function _G.Canvas.toggle_invert()
    _G.Canvas.inverted = not _G.Canvas.inverted
    notify("Бесконечный холст", "Направление перетаскивания: " .. (_G.Canvas.inverted and "Инвертированное" or "Обычное"))
end

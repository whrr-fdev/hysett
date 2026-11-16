-- ============================================================================
-- HySett Infinite Canvas (Бесконечный холст для Hyprland Lua)
-- Управление:
--   SUPER + I                  : Включить / выключить режим Бесконечного холста (с анимацией отдаления/приближения)
--   SUPER + ALT + ЛКМ (зажать) : Свободное перемещение (панорамирование) всего холста
--   SUPER + ALT + SPACE        : Включить/выключить ведение холста за курсором без зажатия ЛКМ
--   CTRL + SUPER + Left/Right  : Плавный перелёт камеры к предыдущему / следующему окну на холсте
--   SUPER + ALT + Колесико     : Плавное приближение / отдаление (Zoom) всего холста
--   SUPER + ALT + C            : Собрать все окна холста обратно в обзор по центру экрана
--   SUPER + ALT + I            : Инвертировать направление перетаскивания холста
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

-- Высокочастотный цикл панорамирования внутри композитора (125 FPS)
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

        local sgn = _G.Canvas.inverted and -1.0 or 1.0
        local dx = raw_dx * _G.Canvas.speed * sgn
        local dy = raw_dy * _G.Canvas.speed * sgn

        if math.abs(dx) >= 0.5 or math.abs(dy) >= 0.5 then
            local ws = hl.get_active_workspace()
            if ws then
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
        end
    elseif cp then
        _G.Canvas.last_cursor = { x = cp.x, y = cp.y }
    end

    hl.timer(pan_loop, { timeout = 8 })
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
        -- Синхронизируем стартовые координаты окон
        local ws = hl.get_active_workspace()
        if ws then
            for _, w in pairs(hl.get_windows()) do
                if is_canvas_win(w, ws.id) and w.floating then
                    _G.Canvas.virtual_pos[w.address] = { x = w.at.x, y = w.at.y }
                end
            end
        end
        hl.timer(pan_loop, { timeout = 8 })
    elseif not active then
        _G.Canvas.panning = false
        _G.Canvas.last_cursor = nil
    end
end

function _G.Canvas.toggle_pan_lock()
    if not _G.Canvas.enabled then return end
    _G.Canvas.set_panning(not _G.Canvas.panning)
end

-- Включение / выключение режима Бесконечного Холста с анимацией отдаления (Zoom-Out) и приближения (Zoom-In)
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
        local n = #wins

        -- Шаг 1: фиксируем текущие координаты/размеры каждого окна и переводим в плавающий режим на тех же местах
        for idx, w in ipairs(wins) do
            local ox, oy = w.at.x, w.at.y
            local ow, oh = w.size.x, w.size.y
            local was_float = w.floating

            _G.Canvas.saved_state[w.address] = {
                was_float = was_float,
                x = ox,
                y = oy,
                w = ow,
                h = oh,
                idx = idx,
            }

            if not was_float then
                hl.dispatch(hl.dsp.window.float({ action = "on", window = w }))
                hl.dispatch(hl.dsp.window.resize({ x = ow, y = oh, window = w }))
                hl.dispatch(hl.dsp.window.move({ x = ox, y = oy, window = w }))
            end
        end

        -- Шаг 2: через 25 мс запускаем пружинную анимацию отдаления (Zoom-Out) и разлёта окон по холсту
        hl.timer(function()
            local cur_wins = get_ws_windows(ws.id)
            local count = #cur_wins
            local zoom_scale = (count == 1) and 0.72 or 0.66
            local spread = (count == 1) and 1.0 or 1.28

            for i, w in ipairs(cur_wins) do
                local st = _G.Canvas.saved_state[w.address]
                local ox = st and st.x or w.at.x
                local oy = st and st.y or w.at.y
                local ow = st and st.w or w.size.x
                local oh = st and st.h or w.size.y

                local wcx = ox + ow * 0.5
                local wcy = oy + oh * 0.5

                local tw = math.max(380, math.floor(ow * zoom_scale))
                local th = math.max(260, math.floor(oh * zoom_scale))

                -- Отдаляем центры окон от центра монитора (эффект подъёма камеры над бесконечным холстом)
                local dx_from_center = (wcx - cx) * spread
                local dy_from_center = (wcy - cy) * spread
                if count > 1 and math.abs(dx_from_center) < 40 and math.abs(dy_from_center) < 40 then
                    local angle = (i - 1) * (2.0 * math.pi / count)
                    dx_from_center = math.cos(angle) * 260
                    dy_from_center = math.sin(angle) * 160
                end

                local tx = math.floor(cx + dx_from_center - tw * 0.5)
                local ty = math.floor(cy + dy_from_center - th * 0.5)

                hl.dispatch(hl.dsp.window.resize({ x = tw, y = th, window = w }))
                hl.dispatch(hl.dsp.window.move({ x = tx, y = ty, window = w }))
                _G.Canvas.virtual_pos[w.address] = { x = tx, y = ty }
            end
        end, { timeout = 25 })

        hl.exec_cmd("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py start_evdev &")
        notify("Бесконечный холст ВКЛЮЧЕН", "Super+Alt+ЛКМ — двигать холст | Ctrl+Super+←/→ — перелёт к окну | Super+Alt+Колесо — зум | Super+I — выход")
    else
        _G.Canvas.enabled = false
        _G.Canvas.panning = false
        hl.exec_cmd("pkill -f 'hysett_infinite_canvas.py start_evdev'")

        local wins = get_ws_windows(ws.id)
        -- Шаг 1: Плавная анимация приближения (Zoom-In) обратно на исходные позиции
        for _, w in ipairs(wins) do
            local st = _G.Canvas.saved_state[w.address]
            if st then
                hl.dispatch(hl.dsp.window.resize({ x = st.w, y = st.h, window = w }))
                hl.dispatch(hl.dsp.window.move({ x = st.x, y = st.y, window = w }))
            else
                local nw = math.min(mw - 40, math.max(500, w.size.x))
                local nh = math.min(mh - 60, math.max(360, w.size.y))
                local nx = math.max(mx + 20, math.min(mx + mw - nw - 20, w.at.x))
                local ny = math.max(my + 42, math.min(my + mh - nh - 20, w.at.y))
                hl.dispatch(hl.dsp.window.move({ x = nx, y = ny, window = w }))
            end
        end

        -- Шаг 2: После завершения анимации приближения возвращаем тайловые окна обратно в тайлинг
        hl.timer(function()
            for _, w in pairs(hl.get_windows()) do
                local st = _G.Canvas.saved_state[w.address]
                if st and not st.was_float and w.floating then
                    hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
                end
            end
            _G.Canvas.saved_state = {}
            _G.Canvas.virtual_pos = {}
        end, { timeout = 230 })

        notify("Бесконечный холст ВЫКЛЮЧЕН", "Возврат к обычному рабочему столу")
    end
end

-- Плавный перелёт камеры от окна к окну на бесконечном холсте (CTRL + SUPER + Left / Right)
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

-- Плавное приближение / отдаление (Zoom) всего бесконечного холста (SUPER + ALT + Колесико)
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

-- Собрать все разбросанные окна холста обратно перед глазами (SUPER + ALT + C)
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

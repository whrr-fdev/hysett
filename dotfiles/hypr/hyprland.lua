-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "1920x1080@160",
    position = "auto",
    scale    = "1",
})


---------------------
---- MY LOCALS ------
---------------------

-- Set programs that you use
local terminal    = "kitty"
--local terminal    = "foot"
local fileManager = "nautilus"
local menu        = "hyprlauncher"
local browser     = "firefox"
local VPN         = "throne"

-- Абсолютные пути для сохранения скриншотов и видео
local home = os.getenv("HOME")
local scrPath = home .. "/Pictures/Screens"
local videoPath = home .. "/Videos/Records"

-- Скрипты скриншотов (одновременно сохраняют файл и копируют в буфер)
local screenshot_cmd = "filename=" .. scrPath .. "/screen_$(date +%Y-%m-%d_%H-%M-%S).png && " ..
                       "grim \"$filename\" && wl-copy < \"$filename\" && " ..
                       "notify-send 'Скриншот' 'Сохранено и скопировано в буфер!'"

--local region_cmd     = "filename=" .. scrPath .. "/screen_$(date +%Y-%m-%d_%H-%M-%S).png && " ..
--                       "grim -g \"$(slurp)\" \"$filename\" && wl-copy < \"$filename\" && " ..
--                       "notify-send 'Скриншот области' 'Сохранено и скопировано в буфер!'"
local region_cmd     = "filename=" .. scrPath .. "/screen_$(date +%Y-%m-%d_%H-%M-%S).png; " ..
                       "hyprpicker -r -z & PICKER_PID=$!; " ..
                       "sleep 0.2; " ..
                       "AREA=$(slurp); " ..
                       "kill $PICKER_PID; " ..
                       "if [ -n \"$AREA\" ]; then grim -g \"$AREA\" \"$filename\" && wl-copy < \"$filename\" && notify-send 'Скриншот области' 'Сохранено и скопировано в буфер!'; fi"

-- Команда для записи экрана (при остановке копирует видеофайл в буфер обмена как ссылку на файл)
local record_cmd = "if pgrep -f gpu-screen-recorder > /dev/null; then " ..
                   "killall -SIGINT gpu-screen-recorder && " ..
                   "sleep 0.5 && " ..
                   "latest_video=$(ls -t " .. videoPath .. "/video_*.mp4 | head -n 1) && " ..
                   "wl-copy -t text/uri-list \"file://$latest_video\" && " ..
                   "notify-send 'Запись экрана' 'Запись сохранена и скопирована в буфер обмена!'; " ..
                   "else " ..
                   "gpu-screen-recorder -w screen -f 60 -a default_output -fallback-cpu-encoding yes -o " .. videoPath .. "/video_$(date +'%Y-%m-%d_%H-%M-%S').mp4 & " ..
                   "notify-send 'Запись экрана' 'Запись началась (CPU encoding, 60 FPS)'; fi"
-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
     --hl.exec_cmd("anyrun daemon &")
     hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
     hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=KDE")
     hl.exec_cmd("/usr/lib/pam_kwallet_init &")
     --hl.exec_cmd("waybar & mako &")
     --hl.exec_cmd("throne")
     --hl.exec_cmd("sh -c 'sleep 2 && hyprctl eval \"for _,w in pairs(hl.get_windows()) do if w.class == \\\"Throne\\\" then hl.dispatch(hl.dsp.window.close({ window = w })) end end\"'")

     hl.exec_cmd("firefox", { workspace = "10 silent" })
     hl.exec_cmd("awww-daemon &")
     --hl.exec_cmd("sh -c 'sleep 1 && wallpaperd > /tmp/wallpaper_daemon.log 2>&1 &'")
     --hl.exec_cmd("hyprctl keyword windowrulev2 'dimaround, class:(?i)rofi'")
     hl.exec_cmd("sh -c 'sleep 2 && qs -c overview'")
     hl.exec_cmd("sh -c 'sleep 3 && waycorner'")
     
     --hl.exec_cmd("foot -a peaclok-clock -e peaclock &")
     --hl.exec_cmd("foot -a fastfetch-widget -W 50x8 -e sh -c 'fastfetch; sleep infinity' &")
     
     hl.exec_cmd("wl-paste --type text --watch cliphist store &")
     hl.exec_cmd("wl-paste --type image --watch cliphist store &")

     --hl.exec_cmd("control-center --daemon &")
     hl.exec_cmd("/home/whrr/hysett/build/hysett --daemon &")
     hl.exec_cmd("sh -c 'sleep 2 && /usr/bin/python3 /home/whrr/.config/hypr/scripts/hysett_vpn.py start' &")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_SCALE_FACTOR_ROUNDING_POLICY", "RoundPreferFloor")
hl.env("QS_ICON_THEME", "Papirus")
hl.env("SAL_USE_VCLPLUGIN", "wayland")



hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_FONT_DPI", "96")


-----------------------
----- PERMISSIONS -----
-----------------------
-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 10,

        border_size = 1,

        col = {
            --active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            --inactive_border = "rgba(595959aa)",
	active_border = "rgba(ccccccff)",
	inactive_border = "rgba(333333ff)",        
	},

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,
	extend_border_grab_area = 15,
        hover_icon_on_border = true,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        --rounding       = 10,
        --rounding_power = 2,

        dim_strength = 0.75, --было 0.75
	--dim_inactive = true, 
	-- Change transparency of focused and unfocused windows
        active_opacity   = 0.75, --0.8
        inactive_opacity = 0.7, --0.75

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 8,
            passes    = 3, --было 3
            --vibrancy  = 0.1696,
	    vibrancy  = 0.5,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 7.0, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 7.0, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 7.0, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        background_color = 0x1a1a1a,
        disable_splash_rendering = true, -- добавьте эту строку
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ru",
	kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        numlock_by_default = true,
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------





local mainMod = "SUPER" -- Sets "Windows" key as main modifier
-- Создаем папки для скриншотов и видео при старте, если их нет
os.execute("mkdir -p " .. scrPath .. " && mkdir -p " .. videoPath)
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))
-- ============================================================
--  СКРИНШОТЫ И ЗАПИСЬ ЭКРАНА
-- ============================================================
hl.bind("Print",                    hl.dsp.exec_cmd(screenshot_cmd))
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.exec_cmd(region_cmd))
hl.bind("mouse:274",                hl.dsp.exec_cmd(region_cmd), { mouse = true })
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd("~/.config/hypr/scripts/record.sh"))
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd("pkill -SIGUSR1 -f kb_overlay.py"))
hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/kb_toggle.sh"))
hl.bind(mainMod .. " + SHIFT + F10", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/kb_overlay --settings"))
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd("pkill -SIGUSR1 -fx /home/whrr/.config/hypr/scripts/kb_overlay"))
-- ============================================================
--  ЗАПУСК ПРИЛОЖЕНИЙ
-- ============================================================
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
--hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(VPN))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("env -u QT_SCALE_FACTOR TDESKTOP_USE_PORTAL=1 DESKTOP_APP_I_KNOW_ABOUT_GTK_INCOMPATIBILITY=1 DESKTOP_APP_DISABLE_GTK_INTEGRATION=1 QT_QPA_PLATFORMTHEME=kde AyuGram"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("kcalc"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("pineconemc"))
--hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/wallpaper-gui"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("/home/whrr/hysett/build/hysett --wallpaper"))
--hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("Telegram"))
--hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/theme_toggle.sh toggle"))
-- Запуск Ollama внутри эмулятора терминала Kitty
--hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(terminal .. " ollama run qwen2.5-coder:7b"))
-- Запуск Open Interpreter в терминале
--hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(terminal .. " -e sh -c 'interpreter --model ollama/qwen2.5-coder:7b'"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class waybar-btop -e btop"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("neovide"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipmenu.sh"))
--hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(browser))

hl.bind(mainMod .. " + Z", function()
    local ws = hl.get_active_workspace()
    if not ws then return end

    for _, w in pairs(hl.get_windows()) do
        if w.class == "firefox" then
            -- Перемещаем окно на текущий рабочий стол БЕЗ переключения (аналог silent)
            hl.dispatch(hl.dsp.window.move({
                workspace = ws.id,
                window = w,
                follow = false,   -- false = не переключаться на целевой стол
            }))
            -- Фокусируем перемещённое окно
            hl.dispatch(hl.dsp.focus({ window = w }))
            return
        end
    end

    -- Если окна нет — запускаем (появится на текущем столе)
    hl.exec_cmd(browser)
end)

hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("deckcraft"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("google-chrome-stable"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("pinta"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("wordcraft"))
-- ============================================================
--  МЕНЮ И ЛАУНЧЕРЫ
-- ============================================================
--hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("control-center"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("/home/whrr/hysett/build/hysett"))

--hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("anyrun"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("/home/whrr/hysett/build/hysett --apps"))
-- ============================================================
--  УПРАВЛЕНИЕ ОКНАМИ
-- ============================================================
-- переключение плавающего режима окон
hl.bind(mainMod .. " + SPACE", function()
    local w = hl.get_active_window()
    if not w then return end

    if not w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "on" }))
        local custom_sizes = {
            ["com.ayugram.desktop"]       = { x = 500,  y = 700 },
            ["org.telegram.desktop"]      = { x = 1000, y = 700 },
            ["app.hiddify.com"]           = { x = 450,  y = 650 },
            ["Throne"]                    = { x = 500,  y = 600 },
            ["org.kde.kcalc"]             = { x = 100,  y = 320 },
            ["com.whrr.WallpaperManager"] = { x = 1100, y = 190 },
	    ["com.whrr.HyprSettings"]     = { x = 1040, y = 700 },
	    ["waybar-btop"]               = { x = 1000, y = 650 }
        }
        
        local target_size = custom_sizes[w.class]
        
        if target_size then
            hl.dispatch(hl.dsp.window.resize({ x = target_size.x, y = target_size.y }))
        else
            hl.dispatch(hl.dsp.window.resize({ x = 640, y = 640 }))
        end
    else
        hl.dispatch(hl.dsp.window.float({ action = "off" }))
    end
end)




hl.bind(mainMod .. " + C",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.kill())
--hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + Y", hl.dsp.window.pin())
hl.bind(mainMod .. " + X",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ state = 0 }))
-- Перемещение окон стрелками
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "d" }))
-- Управление фокусом (стрелки)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + Z", function()
    local w = hl.get_active_window()
    if w == nil then return end
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    if w.floating then
        local m = hl.get_active_monitor()
        if m then
            local target_x = math.floor(m.width * 0.6)
            local target_y = math.floor(m.height * 0.6)
            hl.dispatch(hl.dsp.window.center())
            hl.dispatch(hl.dsp.window.resize({ x = target_x, y = target_y }))
        end
    end
end)
-- Закрытие некоторых окон по Escape
hl.bind("Escape", function()
    local w = hl.get_active_window()
    if not w then return end
    local close_on_esc = {
        ["org.kde.kcalc"]       = true,
        ["Throne"]              = true,
        ["com.ayugram.desktop"] = true,
        ["waybar-btop"]                = true,
        ["org.pulseaudio.pavucontrol"] = true,
	["blueman-manager"] = true,
	["peaclok-clock"]       = true,
	["fastfetch-widget"]    = true,
	["com.whrr.WallpaperManager"] = true,
	-- ["com.whrr.HyprSettings"] = true,
    }

    if close_on_esc[w.class] then
        hl.dispatch(hl.dsp.window.close())
    end
end, { non_consuming = true })
-- ============================================================
--  РАБОЧИЕ СТОЛЫ (1–5)
-- ============================================================
for i = 1, 5 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
-- ============================================================
--  МЫШЬ
-- ============================================================
-- Прокрутка рабочих столов
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
-- Перетаскивание и ресайз окон
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- Боковые кнопки мыши: рабочие столы
hl.bind(mainMod .. " + mouse:276", hl.dsp.focus({ workspace = "r-1" }), { mouse = true })
hl.bind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = "r+1" }), { mouse = true })
--hl.bind("mouse:275", hl.dsp.focus({ workspace = "e-1" }), { mouse = true })
--hl.bind("mouse:276", hl.dsp.focus({ workspace = "e+1" }), { mouse = true })
-- ============================================================
--  МУЛЬТИМЕДИА И ЯРКОСТЬ
-- ============================================================
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
-- Управление плеером
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
-- ============================================================
--  СИСТЕМА
-- ============================================================
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("/home/whrr/logout_menu.sh"))
hl.bind(mainMod .. " + Escape + P", hl.dsp.exec_cmd("systemctl poweroff"))




-- ============================================================
--  МЕНЮ ШЕЙДЕРОВ
-- ============================================================
hl.bind(mainMod .. " + F11", hl.dsp.exec_cmd("~/.config/hypr/scripts/shader_menu.sh"))









--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)
hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
    hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    
    move  = "20 monitor_h-120",
    float = true,
    })


--


-- Правило для Блютуза
hl.window_rule({
    name  = "blueman-center",
    match = { class = "blueman-manager" },
    float = true,
    center = true,
})

-- Правило для Wi-Fi (iwgtk)
    hl.window_rule({
    name  = "wifi-center",
    match = { class = "nm-connection-editor" },
    float = true,
    center = true,
    })

-- Правило для Диспетчера задач (htop в kitty)
hl.window_rule({
    name  = "htop-center",
    match = { class = "waybar-htop" },
    float = true,
    center = true,
})
-- Правило для системного монитора (btop в kitty)
hl.window_rule({
    name  = "btop-center",
    match = { class = "waybar-btop" },
    float = true,
    center = true,
    size  = { 1000, 650 }
})
-- Правило для Звука (pavucontrol)
hl.window_rule({
    name  = "volume-center",
    match = { class = "org.pulseaudio.pavucontrol" }, -- Или просто class = "pavucontrol"
    float = true,
    center = true,
})


-- Правило для Hiddify с правильным классом
hl.window_rule({
    name  = "hiddify-center",
    match = { class = "app.hiddify.com" },
    float = true,
    center = true,
    size  = { 450, 650 }
})
-- Правило для Telegram
hl.window_rule({
    name  = "telegram-floating",
    match = { class = "org.telegram.desktop" },
    float = true,
    center = true,
    size  = { 1000, 700 } -- Настрой ширину и высоту под себя
})

-- Правило для AyuGram — плавающее окно по центру
hl.window_rule({
    name  = "ayugram-floating",
    match = { class = "com.ayugram.desktop" },
    float = true,
    center = true,
    size  = { 500, 700 },  -- ширина x высота, подгони под себя
})

-- Блюр для уведомлений Mako
hl.layer_rule({
    name  = "mako-blur",
    match = "mako", -- передаем просто имя слоя строкой
    blur  = true,
})
hl.layer_rule({
    name  = "wlogout-blur",
    match = "wlogout",
    blur  = true,
})
hl.window_rule({
    name  = "minecraft-floating",
    match = { class = "^Minecraft%*.*" }, 
    float = true,
    center = true,
    -- override гарантирует, что прозрачность всегда будет 1.0, 
    -- игнорируя настройки для неактивных окон
    opacity = "1.0 override 1.0", 
})
-- Правила для Менеджера обоев
hl.window_rule({
    name  = "wallpaper-manager-float",
    match = { class = "com.whrr.WallpaperManager" },
    float = true,
    move  = "410 850", 
    size  = { 1100, 190 } -- Изменили 260 на 190
})
hl.layer_rule({
    name = "anyrun-animation",
    match = { namespace = "anyrun" },
    animation = "popin 90%",
    dim_around = true,
})
-- Правило для Throne: плавающее окно по центру, минимальный размер
hl.window_rule({
    name  = "throne-float-center",
    match = { class = "Throne" },
    float = true,
    center = true,
    size  = { 500, 600 }, -- ширина x высота. Подгони под себя
})
hl.layer_rule({
    name = "quickshell-overview-blur",
    match = { namespace = "quickshell:overview-blur" },
    blur = true,
    ignore_alpha = 0,
})


hl.layer_rule({
    name = "waybar-blur",
    match = { namespace = "waybar" },
    blur = true,
    ignore_alpha = 0.5,
})
-- Затемнение вокруг Rofi (если он работает как слой)
hl.layer_rule({
    name = "rofi-dim",
    match = { namespace = "rofi" },
    dim_around = true,
})

-- Затемнение вокруг Quickshell Overview
--hl.layer_rule({
  --  name = "quickshell-overview-dim",
    --match = { namespace = "quickshell:overview" },
    --dim_around = true,
--})
hl.layer_rule({
    name = "quickshell-overview-dim",
    match = { namespace = ".*quickshell.*" },
    dim_around = true,
})
-- Понижаем порядок Waybar, чтобы dim_around от Rofi/Quickshell его затрагивал
hl.layer_rule({
    name = "waybar-order",
    match = { namespace = "waybar" },
    order = -1,
})

hl.layer_rule({
    name = "waybar-blur",
    match = { namespace = "waybar" },
    blur = true,
    ignore_alpha = 0,
    xray = false,
})


-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name  = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    --rounding    = 0,
})
hl.window_rule({
    name  = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    --rounding    = 0,
})

hl.window_rule({
    name  = "peaclok-center",
    match = { class = "peaclok-clock" },
    float = true,
    center = true,
    size  = { 800, 380 } -- Настройте ширину и высоту окна под себя
})


blueman_gui = os.getenv("HOME") .. "/.config/hypr/hyprland-gui.conf"
if io.open(blueman_gui, "r") ~= nil then
    dofile(blueman_gui)
end

-- HyprMod managed settings
require("hyprland-gui")

-- Правило для KCalc: плавающее окно по центру, минимальный размер
hl.window_rule({
    name  = "kcalc-float-center",
    match = { class = "org.kde.kcalc" },
    float = true,
    center = true,
    size  = { 100, 320 }, -- ширина x высота. Подгони под себя (например, 200, 280)
    -- persistent_size = true, -- раскомментируй, если хочешь, чтобы KCalc запоминал размер, который ты задал вручную
})


-- Правило для графического портала (окно выбора файлов)
hl.window_rule({
    name  = "file-chooser-portal",
    match = { class = "xdg-desktop-portal-gtk" },
    float = true,
    center = true,
    size  = { 1152, 648 }
})

-- Резервное правило по названию окна (для Firefox)
hl.window_rule({
    name  = "file-chooser-title",
    match = { title = ".*файл.*" },
    float = true,
    center = true,
    size  = { 1152, 648 }
})

-- Часы (peaclock) в нижней правой четверти
hl.window_rule({
    name  = "peaclock-widget",
    match = { class = "peaclok-clock" },
    float = true,
    move = "900 500",   -- координаты на экране (X Y)
    size = { 850, 400 }, -- уменьшенный размер
    pin = false,          -- закрепляет окно на всех рабочих столах
})

-- Системная инфа (fastfetch) в верхней левой четверти
hl.window_rule({
    name  = "fastfetch-widget",
    match = { class = "fastfetch-widget" },
    float = true,
    move = "300 200",    -- координаты на экране (X Y)
    pin = false,
})
hl.window_rule({
    name   = "kb-overlay-settings-float",
    match  = { class = "com.whrr.KeyboardOverlaySettings" },
    float  = true,
    center = true,
    size   = { 860, 720 },
})

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/theme.lua")

pcall(dofile, os.getenv("HOME") .. "/.config/hypr/look.lua")

pcall(require, "cursor")
pcall(require, "monitors")

-- Центр управления Hyprland
hl.window_rule({
    name      = "control-center-floating",
    match     = { class = "com.whrr.HyprSettings" },
    float     = true,
    center    = true,
    size      = { 1040, 700 },
    opacity   = "1.0 override 1.0 override",
    animation = "popin 5%",
})


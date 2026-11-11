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

local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "hyprlauncher"
local browser     = "firefox"
local VPN         = "throne"

local home      = os.getenv("HOME")
local scrPath   = home .. "/Pictures/Screens"
local videoPath = home .. "/Videos/Records"

local screenshot_cmd = "filename=" .. scrPath .. "/screen_$(date +%Y-%m-%d_%H-%M-%S).png && " ..
                       "grim \"$filename\" && wl-copy < \"$filename\" && " ..
                       "notify-send 'Скриншот' 'Сохранено и скопировано в буфер!'"

local region_cmd     = "filename=" .. scrPath .. "/screen_$(date +%Y-%m-%d_%H-%M-%S).png; " ..
                       "hyprpicker -r -z & PICKER_PID=$!; " ..
                       "sleep 0.2; " ..
                       "AREA=$(slurp); " ..
                       "kill $PICKER_PID; " ..
                       "if [ -n \"$AREA\" ]; then grim -g \"$AREA\" \"$filename\" && wl-copy < \"$filename\" && notify-send 'Скриншот области' 'Сохранено и скопировано в буфер!'; fi"

local record_cmd     = "if pgrep -f gpu-screen-recorder > /dev/null; then " ..
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
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=KDE")
    hl.exec_cmd("/usr/lib/pam_kwallet_init &")

    hl.exec_cmd("firefox", { workspace = "10 silent" })
    hl.exec_cmd("awww-daemon &")

    hl.exec_cmd("wl-paste --type text --watch cliphist store &")
    hl.exec_cmd("wl-paste --type image --watch cliphist store &")

    hl.exec_cmd("/home/whrr/hysett/build/hysett --daemon &")

    hl.exec_cmd("nautilus --gapplication-service &")

    hl.exec_cmd("env -u QT_SCALE_FACTOR TDESKTOP_USE_PORTAL=1 DESKTOP_APP_I_KNOW_ABOUT_GTK_INCOMPATIBILITY=1 DESKTOP_APP_DISABLE_GTK_INTEGRATION=1 MALLOC_ARENA_MAX=2 MALLOC_MMAP_THRESHOLD_=65536 MALLOC_TRIM_THRESHOLD_=65536 QT_QPA_PLATFORMTHEME=kde AyuGram -startintray")
    hl.exec_cmd("sh -c 'if [ \"$(cat ~/.config/hypr/scripts/clock.conf 2>/dev/null)\" = \"1\" ]; then ~/clock_overlay/target/release/clock_overlay & fi'")
    hl.exec_cmd("sh -c 'sleep 1 && FILE=$(readlink -f ~/.cache/wallpaper-current); if [[ $FILE == *.mp4 || $FILE == *.webm || $FILE == *.mkv ]]; then mpvpaper -p -o \"no-audio --loop-file=inf --hwdec=auto --panscan=1.0\" \"*\" \"$FILE\" & else awww img \"$FILE\" --transition-type grow || swww img \"$FILE\" & fi'")
    hl.exec_cmd("~/.config/hypr/scripts/mpvpaper_autopause.py &")
    
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
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 10,
        border_size = 1,

        col = {
            active_border   = "rgba(ccccccff)",
            inactive_border = "rgba(333333ff)",
        },

        resize_on_border        = true,
        extend_border_grab_area = 15,
        hover_icon_on_border    = true,
        allow_tearing           = false,
        layout                  = "dwindle",
    },

    decoration = {
        dim_strength     = 0.75,
        active_opacity   = 0.75,
        inactive_opacity = 0.7,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 8,
            passes   = 3,
            vibrancy = 0.5,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 7.0,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 7.0,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 7.0,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

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
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        background_color         = 0x1a1a1a,
        disable_splash_rendering = true,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout          = "us,ru",
        kb_variant         = "",
        kb_model           = "",
        kb_options         = "grp:alt_shift_toggle",
        numlock_by_default = true,
        kb_rules           = "",
        follow_mouse       = 1,
        sensitivity        = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"
os.execute("mkdir -p " .. scrPath .. " && mkdir -p " .. videoPath)

hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))

-- Скриншоты и запись экрана
hl.bind("Print",                   hl.dsp.exec_cmd(screenshot_cmd))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(region_cmd))
hl.bind("mouse:274",               hl.dsp.exec_cmd(region_cmd), { mouse = true })
hl.bind(mainMod .. " + F10",       hl.dsp.exec_cmd("~/.config/hypr/scripts/record.sh"))
hl.bind(mainMod .. " + F9",        hl.dsp.exec_cmd("pkill -SIGUSR1 -f kb_overlay.py"))
hl.bind(mainMod .. " + SHIFT + F9",  hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/kb_toggle.sh"))
hl.bind(mainMod .. " + SHIFT + F11", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/sysinfo_toggle.sh"))
hl.bind(mainMod .. " + SHIFT + F10", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/kb_overlay --settings"))
hl.bind(mainMod .. " + F9",        hl.dsp.exec_cmd("pkill -SIGUSR1 -fx /home/whrr/.config/hypr/scripts/kb_overlay"))

-- Запуск приложений
hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + H",         hl.dsp.exec_cmd(VPN))

-- SUPER + A: Мгновенное открытие/фокус AyuGram (из фонового стола 10 или запуск)
hl.bind(mainMod .. " + A", function()
    local ws = hl.get_active_workspace()
    if ws then
        for _, w in pairs(hl.get_windows()) do
            if w.class == "com.ayugram.desktop" then
                if w.workspace.id ~= ws.id then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = ws.id,
                        window    = w,
                        follow    = false,
                    }))
                end
                hl.dispatch(hl.dsp.focus({ window = w }))
                hl.dispatch(hl.dsp.window.center())
                return
            end
        end
    end
    hl.exec_cmd("env -u QT_SCALE_FACTOR TDESKTOP_USE_PORTAL=1 DESKTOP_APP_I_KNOW_ABOUT_GTK_INCOMPATIBILITY=1 DESKTOP_APP_DISABLE_GTK_INTEGRATION=1 MALLOC_ARENA_MAX=2 MALLOC_MMAP_THRESHOLD_=65536 MALLOC_TRIM_THRESHOLD_=65536 QT_QPA_PLATFORMTHEME=kde AyuGram")
end)

hl.bind(mainMod .. " + K",         hl.dsp.exec_cmd("kcalc"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("pineconemc"))
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("/home/whrr/hysett/build/hysett --wallpaper"))
hl.bind("CTRL + SHIFT + Escape",   hl.dsp.exec_cmd("kitty --class waybar-btop -e btop"))
hl.bind(mainMod .. " + F1",        hl.dsp.exec_cmd("foot --class waybar-btop -e btop"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("neovide"))
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("~/.config/hypr/scripts/clipmenu.sh"))
hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("deckcraft"))
hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd("google-chrome-stable"))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd("pinta"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd("wordcraft"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("env WINIT_UNIX_BACKEND=wayland /home/whrr/horizon/target/release/horizon-client --resources /home/whrr/horizon/.local/horizon-client/26.3"))

-- Меню и лаунчеры
hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("/home/whrr/hysett/build/hysett"))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("/home/whrr/hysett/build/hysett --apps"))

-- Управление окнами
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
            ["waybar-btop"]               = { x = 1000, y = 650 },
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

-- SUPER + Z: Мгновенный вызов предзагруженного Firefox на текущий стол (0 мс)
local function is_firefox_win(w)
    if not w or not w.class then return false end
    local c = string.lower(w.class)
    return c == "firefox" or c == "org.mozilla.firefox" or string.find(c, "firefox") ~= nil
end

hl.bind(mainMod .. " + Z", function()
    local ws = hl.get_active_workspace()
    if not ws then return end

    local current_ws_win = nil
    local hidden_ws_win  = nil

    for _, w in pairs(hl.get_windows()) do
        if is_firefox_win(w) then
            if w.workspace.id == 10 then
                hidden_ws_win = w
            elseif w.workspace.id == ws.id then
                current_ws_win = w
            elseif not hidden_ws_win then
                hidden_ws_win = w
            end
        end
    end

    local target = hidden_ws_win or current_ws_win
    if target then
        if target.workspace.id ~= ws.id then
            hl.dispatch(hl.dsp.window.move({
                workspace = ws.id,
                window    = target,
                follow    = false,
            }))
        end
        hl.dispatch(hl.dsp.focus({ window = target }))
        return
    end

    hl.exec_cmd(browser)
end)

-- SUPER + C: Умное закрытие (Firefox мгновенно скрывается и пересоздает прогретое окно на 10-м столе, AyuGram/Throne прячутся в трей)
hl.bind(mainMod .. " + C", function()
    local w = hl.get_active_window()
    if not w then return end

    if is_firefox_win(w) then
        local old_addr = w.address
        local other_ff = false
        for _, ow in pairs(hl.get_windows()) do
            if is_firefox_win(ow) and ow.address ~= old_addr then
                other_ff = true
                break
            end
        end

        if other_ff then
            hl.dispatch(hl.dsp.window.close({ window = w }))
            return
        end

        hl.window_rule({
            name      = "ff-prewarm-trap",
            match     = { class = ".*firefox.*" },
            workspace = "10 silent",
        })

        hl.dispatch(hl.dsp.window.move({
            workspace = 10,
            window    = w,
            follow    = false,
        }))

        hl.exec_cmd("/home/whrr/.config/hypr/scripts/ff_recycle.sh " .. old_addr .. " &")
    elseif w.class == "com.ayugram.desktop" or w.class == "Throne" then
        hl.dispatch(hl.dsp.window.move({
            workspace = 10,
            window    = w,
            follow    = false,
        }))
        hl.exec_cmd("/home/whrr/.config/hypr/scripts/reclaim_bg.sh &")
    elseif string.find(string.lower(w.class or ""), "nautilus") then
        hl.dispatch(hl.dsp.window.close({ window = w }))
        hl.exec_cmd("sh -c 'sleep 0.15; if [ $(hyprctl clients -j | grep -ci nautilus) -eq 0 ]; then pkill -9 -x nautilus 2>/dev/null; nautilus --gapplication-service >/dev/null 2>&1 & fi' &")
    else
        hl.dispatch(hl.dsp.window.close({ window = w }))
    end
end)

-- SUPER + SHIFT + C: Полное убийство активного приложения (включая Firefox, AyuGram и Throne)
hl.bind(mainMod .. " + SHIFT + C", function()
    local w = hl.get_active_window()
    if not w then return end

    if is_firefox_win(w) then
        hl.exec_cmd("killall -9 -q firefox firefox-bin || pkill -9 -f firefox")
    elseif w.class == "com.ayugram.desktop" then
        hl.exec_cmd("killall -q AyuGram")
    elseif w.class == "Throne" then
        hl.exec_cmd("killall -q Throne throne")
    else
        hl.dispatch(hl.dsp.window.close({ window = w }))
    end
end)

hl.bind(mainMod .. " + Y",            hl.dsp.window.pin())
hl.bind(mainMod .. " + X",            hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",            hl.dsp.window.fullscreen({ state = 0 }))

hl.bind(mainMod .. " + SHIFT + A",     hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + W",     hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "d" }))

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

-- Escape: всплывающие утилиты закрываются, а AyuGram и Throne прячутся обратно в трей
--hl.bind("Escape", hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/esc_close.sh"), { non_consuming = true })
hl.bind("Escape", function()
    local w = hl.get_active_window()
    if not w then return end

    if w.class == "com.ayugram.desktop" or w.class == "Throne" then
        hl.dispatch(hl.dsp.window.move({
            workspace = 10,
            window    = w,
            follow    = false,
        }))
        return
    end

    local close_on_esc = {
        ["org.kde.kcalc"]              = true,
        ["waybar-btop"]                = true,
        ["org.pulseaudio.pavucontrol"] = true,
        ["blueman-manager"]            = true,
        ["peaclok-clock"]              = true,
        ["fastfetch-widget"]           = true,
        ["com.whrr.WallpaperManager"]  = true,
    }

    if close_on_esc[w.class] then
        hl.dispatch(hl.dsp.window.close())
    end
end, { non_consuming = true })
-- Рабочие столы (1–5)
for i = 1, 5 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Мышь
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse:276",  hl.dsp.focus({ workspace = "r-1" }), { mouse = true })
hl.bind(mainMod .. " + mouse:275",  hl.dsp.focus({ workspace = "r+1" }), { mouse = true })

-- Мультимедиа и яркость
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Система
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd("/home/whrr/.config/hypr/scripts/lock.sh"))
hl.bind(mainMod .. " + M",          hl.dsp.exec_cmd("/home/whrr/logout_menu.sh"))
--hl.bind(mainMod .. " + Escape + P", hl.dsp.exec_cmd("systemctl poweroff"))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
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

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name   = "blueman-center",
    match  = { class = "blueman-manager" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "wifi-center",
    match  = { class = "nm-connection-editor" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "htop-center",
    match  = { class = "waybar-htop" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "btop-center",
    match  = { class = "waybar-btop" },
    float  = true,
    center = true,
    size   = { 1000, 650 },
})

hl.window_rule({
    name   = "volume-center",
    match  = { class = "org.pulseaudio.pavucontrol" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "hiddify-center",
    match  = { class = "app.hiddify.com" },
    float  = true,
    center = true,
    size   = { 450, 650 },
})

hl.window_rule({
    name   = "telegram-floating",
    match  = { class = "org.telegram.desktop" },
    float  = true,
    center = true,
    size   = { 1000, 700 },
})

hl.window_rule({
    name   = "ayugram-floating",
    match  = { class = "com.ayugram.desktop" },
    float  = true,
    center = true,
    size   = { 500, 700 },
})

hl.layer_rule({
    name  = "mako-blur",
    match = "mako",
    blur  = true,
})

hl.layer_rule({
    name  = "wlogout-blur",
    match = "wlogout",
    blur  = true,
})

hl.window_rule({
    name      = "minecraft-floating",
    match     = { class = "gamescope", title = "^Minecraft.*" },
    float     = true,
    center    = true,
    opacity   = "1.0 override 1.0 override",
    no_blur   = true,
})

hl.window_rule({
    name  = "wallpaper-manager-float",
    match = { class = "com.whrr.WallpaperManager" },
    float = true,
    move  = "410 850",
    size  = { 1100, 190 },
})

hl.layer_rule({
    name       = "anyrun-animation",
    match      = { namespace = "anyrun" },
    animation  = "popin 90%",
    dim_around = true,
})

hl.window_rule({
    name   = "throne-float-center",
    match  = { class = "Throne" },
    float  = true,
    center = true,
    size   = { 500, 600 },
})

hl.layer_rule({
    name         = "quickshell-overview-blur",
    match        = { namespace = "quickshell:overview-blur" },
    blur         = true,
    ignore_alpha = 0,
})

hl.layer_rule({
    name       = "rofi-dim",
    match      = { namespace = "rofi" },
    dim_around = true,
})

hl.layer_rule({
    name       = "quickshell-overview-dim",
    match      = { namespace = ".*quickshell.*" },
    dim_around = true,
})

hl.layer_rule({
    name  = "waybar-order",
    match = { namespace = "waybar" },
    order = -1,
})

hl.layer_rule({
    name         = "waybar-blur",
    match        = { namespace = "waybar" },
    blur         = true,
    ignore_alpha = 0,
    xray         = false,
})

hl.window_rule({
    name        = "no-gaps-wtv1",
    match       = { float = false, workspace = "w[tv1]" },
    border_size = 0,
})

hl.window_rule({
    name        = "no-gaps-f1",
    match       = { float = false, workspace = "f[1]" },
    border_size = 0,
})

hl.window_rule({
    name   = "peaclok-center",
    match  = { class = "peaclok-clock" },
    float  = true,
    center = true,
    size   = { 800, 380 },
})

blueman_gui = os.getenv("HOME") .. "/.config/hypr/hyprland-gui.conf"
if io.open(blueman_gui, "r") ~= nil then
    dofile(blueman_gui)
end

require("hyprland-gui")

hl.window_rule({
    name   = "kcalc-float-center",
    match  = { class = "org.kde.kcalc" },
    float  = true,
    center = true,
    size   = { 100, 320 },
})

hl.window_rule({
    name   = "file-chooser-portal",
    match  = { class = "xdg-desktop-portal-gtk" },
    float  = true,
    center = true,
    size   = { 1152, 648 },
})

hl.window_rule({
    name   = "file-chooser-title",
    match  = { title = ".*файл.*" },
    float  = true,
    center = true,
    size   = { 1152, 648 },
})

hl.window_rule({
    name  = "peaclock-widget",
    match = { class = "peaclok-clock" },
    float = true,
    move  = "900 500",
    size  = { 850, 400 },
    pin   = false,
})

hl.window_rule({
    name  = "fastfetch-widget",
    match = { class = "fastfetch-widget" },
    float = true,
    move  = "300 200",
    pin   = false,
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

hl.window_rule({
    name      = "control-center-floating",
    match     = { class = "com.whrr.HyprSettings" },
    float     = true,
    center    = true,
    size      = { 1040, 700 },
    opacity   = "1.0 override 1.0 override",
    animation = "popin 5%",
})

hl.window_rule({
    name        = "hysett-atmosphere-overlay",
    match       = { class = "hypratmooverlay" },
    float       = true,
    pin         = true,
    move        = "0 0",
    size        = { 1920, 1080 },
    border_size = 0,
    rounding    = 0,
    no_focus    = true,
    no_blur     = true,
    no_shadow   = true,
    no_anim     = true,
    opacity     = "1.0 override 1.0 override",
})

hl.window_rule({
    name        = "hysett-atmosphere-overlay-title",
    match       = { title = "HySettAtmosphereOverlay" },
    float       = true,
    pin         = true,
    move        = "0 0",
    size        = { 1920, 1080 },
    border_size = 0,
    rounding    = 0,
    no_focus    = true,
    no_blur     = true,
    no_shadow   = true,
    no_anim     = true,
    opacity     = "1.0 override 1.0 override",
})

hl.window_rule({
    match       = { title = "gamescope" },
    opacity     = "1.0 override 1.0 override",
})

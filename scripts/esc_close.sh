#!/usr/bin/env bash
hyprctl eval '
    local w = hl.get_active_window()
    if not w then return end
    local cls = string.lower(w.class or "")
    if string.find(cls, "ayugram") or string.find(cls, "throne") then
        hl.dispatch(hl.dsp.window.move({ workspace = 10, window = w, follow = false }))
        return
    end
    local close_on_esc = {
        ["org.kde.kcalc"] = true,
        ["waybar-btop"] = true,
        ["org.pulseaudio.pavucontrol"] = true,
        ["blueman-manager"] = true,
        ["peaclok-clock"] = true,
        ["fastfetch-widget"] = true,
        ["com.whrr.wallpapermanager"] = true,
    }
    if close_on_esc[cls] or close_on_esc[w.class or ""] then
        hl.dispatch(hl.dsp.window.close({ window = w }))
    end
' >/dev/null 2>&1

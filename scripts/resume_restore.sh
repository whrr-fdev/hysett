#!/usr/bin/env bash
LOCK="/tmp/hysett_resume.lock"
[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Ждем, пока монитор HDMI-A-1 полностью поднимется в Hyprland
for _ in $(seq 1 20); do
    if hyprctl monitors 2>/dev/null | grep -q "Monitor "; then
        break
    fi
    sleep 0.25
done
sleep 0.6

# 1. Восстанавливаем обои (mpvpaper / awww)
FILE=$(readlink -f ~/.cache/wallpaper-current 2>/dev/null)
if [ -n "$FILE" ] && [ -f "$FILE" ]; then
    case "${FILE,,}" in
        *.mp4|*.webm|*.mkv|*.mov|*.gif)
            if ! pgrep -x mpvpaper >/dev/null 2>&1 || ! hyprctl layers 2>/dev/null | grep -qi "mpvpaper"; then
                pkill -9 -x mpvpaper 2>/dev/null || true
                sleep 0.15
                nohup mpvpaper -p -o "no-audio --loop-file=inf --hwdec=auto --panscan=1.0" "*" "$FILE" >/dev/null 2>&1 &
                disown
            fi
            ;;
        *)
            pgrep -x awww-daemon >/dev/null 2>&1 || (nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.3)
            awww img "$FILE" --transition-type none >/dev/null 2>&1 || swww img "$FILE" >/dev/null 2>&1 || true
            ;;
    esac
fi

# 2. Восстанавливаем hysett, если процесс упал или его LayerShell-поверхность слетела при переподключении HDMI
if ! pgrep -f "hysett --daemon" >/dev/null 2>&1 || ! hyprctl layers 2>/dev/null | grep -q "waybar"; then
    pkill -9 -f "hysett" 2>/dev/null || true
    rm -f "${XDG_RUNTIME_DIR:-/run/user/1000}/com.whrr.HyprSettings.socket" /tmp/com.whrr.HyprSettings.socket
    sleep 0.25
    nohup /home/whrr/hysett/build/hysett --daemon >/dev/null 2>&1 &
    disown
fi

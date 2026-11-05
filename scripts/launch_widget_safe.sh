#!/bin/bash
TARGET="$1"
ACTION="$2" # start | stop | toggle

if [ "$TARGET" = "clock" ]; then
    if [ "$ACTION" = "stop" ] || pgrep -f "clock_overlay" >/dev/null; then
        pkill -f "clock_overlay"
        echo "0" > ~/.config/hypr/scripts/clock.conf
    else
        echo "1" > ~/.config/hypr/scripts/clock.conf
        BIN="$HOME/clock_overlay/target/release/clock_overlay"
        if [ -x "$BIN" ]; then
            "$BIN" >/dev/null 2>&1 &
        elif [ -x "$HOME/.config/hypr/scripts/clock_overlay" ]; then
            "$HOME/.config/hypr/scripts/clock_overlay" >/dev/null 2>&1 &
        fi
    fi
elif [ "$TARGET" = "kb" ]; then
    if [ "$ACTION" = "stop" ] || pgrep -f "kb_overlay" >/dev/null; then
        pkill -f "kb_overlay"
        pkill -f "kb_overlay.py"
    else
        if [ -x "$HOME/.config/hypr/scripts/kb_toggle.sh" ]; then
            /bin/bash "$HOME/.config/hypr/scripts/kb_toggle.sh" >/dev/null 2>&1 &
        elif [ -f "$HOME/.config/hypr/scripts/kb_overlay.py" ]; then
            python3 "$HOME/.config/hypr/scripts/kb_overlay.py" >/dev/null 2>&1 &
        fi
    fi
fi

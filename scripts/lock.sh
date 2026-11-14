#!/usr/bin/env bash
pidof hyprlock >/dev/null 2>&1 && exit 0
if [ ! -f "$HOME/.cache/lock_bg.png" ]; then
    ~/.config/hypr/scripts/update_lock_bg.sh
fi
exec hyprlock

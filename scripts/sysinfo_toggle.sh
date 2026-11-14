#!/usr/bin/env bash
if pgrep -f "sysinfo_overlay" > /dev/null; then
    pkill -f "sysinfo_overlay"
    echo "0" > ~/.config/hypr/scripts/sysinfo.conf
else
    echo "1" > ~/.config/hypr/scripts/sysinfo.conf
    for bin in "$HOME/sysinfo/target/release/sysinfo_overlay" "$HOME/.config/hypr/scripts/sysinfo_overlay" "$HOME/.local/bin/sysinfo_overlay"; do
        if [ -x "$bin" ]; then
            nohup "$bin" >/dev/null 2>&1 &
            exit 0
        fi
    done
fi

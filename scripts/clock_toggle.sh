#!/bin/bash
STATE_FILE="/home/whrr/hysett/scripts/clock.conf"
BIN="/home/whrr/hysett/bin/clock_overlay"
FALLBACK_BIN="$HOME/clock_overlay/target/release/clock_overlay"

if pgrep -f "clock_overlay" > /dev/null; then
    pkill -f "clock_overlay"
    echo "0" > "$STATE_FILE"
else
    echo "1" > "$STATE_FILE"
    if [ -x "$BIN" ]; then
        "$BIN" >/dev/null 2>&1 &
    elif [ -x "$FALLBACK_BIN" ]; then
        "$FALLBACK_BIN" >/dev/null 2>&1 &
    fi
fi

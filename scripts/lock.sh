#!/usr/bin/env bash
if [ -f /tmp/hysett_screen_locked ] && pidof -s hysett >/dev/null 2>&1; then
    exit 0
fi
touch /tmp/hysett_screen_locked
pkill -9 -x clock_overlay 2>/dev/null || true
sleep 0.04
pkill -CONT -x mpvpaper 2>/dev/null || true
exec /home/whrr/hysett/build/hysett --lock

#!/usr/bin/env bash
touch /tmp/hysett_screen_locked
pkill -9 -x clock_overlay 2>/dev/null || true
sleep 0.04
pkill -CONT -x mpvpaper 2>/dev/null || true
exec /home/whrr/hysett/build/hysett --lock

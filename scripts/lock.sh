#!/usr/bin/env bash
pkill -CONT -x mpvpaper 2>/dev/null || true
exec /home/whrr/hysett/build/hysett --lock

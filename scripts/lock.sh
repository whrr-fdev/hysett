#!/usr/bin/env bash
~/.config/hypr/scripts/update_lock_bg.sh >/dev/null 2>&1 &
exec /home/whrr/hysett/build/hysett --lock

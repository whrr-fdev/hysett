#!/bin/bash
STATE_FILE="/home/whrr/.config/hypr/scripts/theme_state.conf"
THEME_LUA="/home/whrr/.config/hypr/theme.lua"
mkdir -p "/home/whrr/.config/hypr/scripts"

CURRENT=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')

if [ "$1" = "rounded" ] || [ "$1" = "square" ]; then
    TARGET="$1"
elif [ "$CURRENT" = "square" ]; then
    TARGET="rounded"
else
    TARGET="square"
fi

if [ "$TARGET" = "rounded" ]; then
    ROUNDING=10
else
    ROUNDING=0
fi

echo "$TARGET" > "$STATE_FILE"
echo "hl.config({ decoration = { rounding = $ROUNDING, rounding_power = 2 } })" > "$THEME_LUA"
hyprctl eval "dofile('$THEME_LUA')" 2>/dev/null

if [ -f "/home/whrr/.config/waybar/style-${TARGET}.css" ]; then
    cp -f "/home/whrr/.config/waybar/style-${TARGET}.css" "/home/whrr/.config/waybar/style.css"
fi

killall -9 -q waybar 2>/dev/null
while pgrep -x waybar >/dev/null; do sleep 0.05; done
waybar &

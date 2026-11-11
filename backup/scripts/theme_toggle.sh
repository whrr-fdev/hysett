#!/bin/bash
STATE_FILE="/home/whrr/.config/hypr/scripts/theme_state.conf"
THEME_LUA="/home/whrr/.config/hypr/theme.lua"
LOOK_LUA="/home/whrr/.config/hypr/look.lua"
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
    ROUNDING=12
else
    ROUNDING=0
fi

echo "$TARGET" > "$STATE_FILE"
echo "hl.config({ decoration = { rounding = $ROUNDING, rounding_power = 2 } })" > "$THEME_LUA"

if [ -f "$LOOK_LUA" ]; then
    if grep -q "rounding[[:space:]]*=" "$LOOK_LUA"; then
        sed -i "s/rounding[[:space:]]*=[[:space:]]*[0-9]*/rounding         = $ROUNDING/" "$LOOK_LUA"
    else
        sed -i "s/decoration = {/decoration = {\n        rounding         = $ROUNDING,\n        rounding_power   = 2,/" "$LOOK_LUA"
    fi
fi

hyprctl keyword decoration:rounding "$ROUNDING" >/dev/null 2>&1
hyprctl eval "hl.config({ decoration = { rounding = $ROUNDING, rounding_power = 2 } })" >/dev/null 2>&1
hyprctl reload >/dev/null 2>&1

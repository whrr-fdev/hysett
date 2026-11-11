#!/bin/bash

CORNER_X=10
CORNER_Y=10
INTERVAL=0.05

inside=0

while true; do
    CURSOR=$(hyprctl cursorpos -j 2>/dev/null)
    X=$(echo "$CURSOR" | jq -r '.x')
    Y=$(echo "$CURSOR" | jq -r '.y')

    MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
    MON_H=$(echo "$MON" | jq -r '.height')

    if [ "$X" -le "$CORNER_X" ] && [ "$Y" -ge $((MON_H - CORNER_Y)) ]; then
        if [ "$inside" -eq 0 ]; then
            qs ipc -c overview call overview toggle
            inside=1
        fi
    else
        inside=0
    fi

    sleep $INTERVAL
done

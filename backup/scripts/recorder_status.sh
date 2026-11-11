#!/bin/bash

pid=$(pidof -s gpu-screen-recorder)
if [ -n "$pid" ]; then
    elapsed=$(ps -o etimes= -p "$pid" | tr -d " ")
    mins=$((elapsed / 60))
    secs=$((elapsed % 60))
    printf "{\"text\": \"<span color=\x27#ff3333\x27>●</span> %02d:%02d\", \"class\": \"recording\"}\n" "$mins" "$secs"
else
    printf "{\"text\": \"\", \"class\": \"stopped\"}\n"
fi

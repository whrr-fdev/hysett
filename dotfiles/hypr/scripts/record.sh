#!/bin/bash

videoPath="$HOME/Videos/Records"
mkdir -p "$videoPath"

if pgrep -f gpu-screen-recorder > /dev/null; then
    killall -SIGINT gpu-screen-recorder
    sleep 0.5
    pkill -RTMIN+9 waybar
    latest_video=$(ls -t "$videoPath"/video_*.mp4 2>/dev/null | head -n 1)
    if [ -n "$latest_video" ]; then
        wl-copy -t text/uri-list "file://$latest_video"
        notify-send "Запись экрана" "Запись сохранена и скопирована в буфер!"
    else
        notify-send "Запись экрана" "Запись остановлена"
    fi
else
    gpu-screen-recorder -w screen -f 60 -a default_output -fallback-cpu-encoding yes -o "$videoPath/video_$(date +%Y-%m-%d_%H-%M-%S).mp4" &
    sleep 0.2
    pkill -RTMIN+9 waybar
fi

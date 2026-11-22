#!/bin/bash
CONF="$HOME/.config/hypr/scripts/capture.conf"
REC_DIR="$HOME/Videos/Records"
REC_FPS="60"
REC_CODEC="h264"
REC_QUALITY="very_high"
REC_CONTAINER="mp4"
REC_ENCODER="gpu_fallback"
REC_AUDIO_MODE="0"
REC_CURSOR="1"
REC_COPY_CLIPBOARD="1"
REC_NOTIFY="1"
[ -f "$CONF" ] && source "$CONF"

mkdir -p "$REC_DIR"

if pgrep -f gpu-screen-recorder > /dev/null; then
    killall -SIGINT gpu-screen-recorder
    sleep 0.5
    latest_video=$(ls -t "$REC_DIR"/video_*."$REC_CONTAINER" "$REC_DIR"/video_*.mp4 "$REC_DIR"/video_*.mkv 2>/dev/null | head -n 1)
    if [ -n "$latest_video" ]; then
        if [ "$REC_COPY_CLIPBOARD" = "1" ]; then
            wl-copy -t text/uri-list "file://$latest_video"
            [ "$REC_NOTIFY" = "1" ] && notify-send "Запись экрана" "Запись сохранена и скопирована в буфер!"
        else
            [ "$REC_NOTIFY" = "1" ] && notify-send "Запись экрана" "Запись сохранена: $(basename "$latest_video")"
        fi
    else
        [ "$REC_NOTIFY" = "1" ] && notify-send "Запись экрана" "Запись остановлена"
    fi
else
    ARGS=(-w screen -f "$REC_FPS" -k "$REC_CODEC" -q "$REC_QUALITY")
    if [ "$REC_CURSOR" = "1" ]; then
        ARGS+=(-cursor yes)
    else
        ARGS+=(-cursor no)
    fi
    case "$REC_AUDIO_MODE" in
        0) ARGS+=(-a default_output) ;;
        1) ARGS+=(-a default_input) ;;
        2) ARGS+=(-a "default_output|default_input") ;;
        3) ;;
    esac
    case "$REC_ENCODER" in
        gpu_fallback) ARGS+=(-fallback-cpu-encoding yes) ;;
        gpu) ARGS+=(-encoder gpu) ;;
        cpu) ARGS+=(-encoder cpu) ;;
    esac
    OUT_FILE="$REC_DIR/video_$(date +%Y-%m-%d_%H-%M-%S).$REC_CONTAINER"
    gpu-screen-recorder "${ARGS[@]}" -o "$OUT_FILE" &
    [ "$REC_NOTIFY" = "1" ] && notify-send "Запись экрана" "Запись началась (${REC_FPS} FPS, ${REC_CODEC})"
fi

#!/usr/bin/env bash
WALL=$(readlink -f ~/.cache/wallpaper-current 2>/dev/null)
OUT="$HOME/.cache/lock_bg.png"
STAMP_FILE="$HOME/.cache/lock_bg_src.txt"

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    exit 0
fi

CUR_STAMP="${WALL}_$(stat -c '%Y_%s' "$WALL" 2>/dev/null)"
if [ -f "$OUT" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$CUR_STAMP" ]; then
    exit 0
fi

case "${WALL,,}" in
    *.mp4|*.webm|*.mkv|*.mov)
        ffmpeg -nostdin -loglevel quiet -y -ss 00:00:01 -i "$WALL" -frames:v 1 \
            -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080" "$OUT"
        ;;
    *.png)
        cp -f "$WALL" "$OUT"
        ;;
    *)
        ffmpeg -nostdin -loglevel quiet -y -i "$WALL" -frames:v 1 "$OUT" 2>/dev/null || cp -f "$WALL" "$OUT"
        ;;
esac

echo "$CUR_STAMP" > "$STAMP_FILE"
/usr/bin/python3 ~/.config/hypr/scripts/sync_m3_windows.py >/dev/null 2>echo "$CUR_STAMP" > "$STAMP_FILE"1 &

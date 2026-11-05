#!/usr/bin/env bash

THUMB_DIR="/tmp/cliphist-thumbs"
mkdir -p "$THUMB_DIR"
find "$THUMB_DIR" -mmin +60 -type f -delete

BORDER_RADIUS="0px"
if grep -q "ROUNDED" ~/.config/waybar/style.css 2>/dev/null; then
    BORDER_RADIUS="12px"
fi

cliphist list | head -n 30 > /tmp/cliphist_current
rofi_input=""
counter=1

while IFS= read -r line; do
    if [[ -z "$line" ]]; then continue; fi
    id=$(echo "$line" | cut -f1)
    content=$(echo "$line" | cut -f2-)
    
    if echo "$line" | grep -q "\[\[ binary data"; then
        thumb_path="$THUMB_DIR/${id}.png"
        if [ ! -f "$thumb_path" ]; then
            echo "$line" | cliphist decode > "$thumb_path"
        fi
        display_text=$(printf "%02d. screen_%s.png" "$counter" "$id")
        rofi_input+="${display_text}\0icon\x1f${thumb_path}\n"
    elif [[ "$content" == file://*.mp4* ]] || [[ "$content" == file://*.mkv* ]]; then
        video_path="${content#file://}"
        video_path=$(echo "$video_path" | tr -d '\r' | tr -d '\n')
        thumb_path="$THUMB_DIR/${id}.png"
        if [ ! -f "$thumb_path" ]; then
            ffmpeg -y -i "$video_path" -ss 00:00:00.500 -vframes 1 "$thumb_path" >/dev/null 2>&1
        fi
        filename=$(basename "$video_path")
        display_text=$(printf "%02d. %s" "$counter" "$filename")
        rofi_input+="${display_text}\0icon\x1f${thumb_path}\n"
    else
        clean_content="${content//\\/ }"
        clean_content=$(echo "$clean_content" | tr -s ' ' | cut -c1-65)
        display_text=$(printf "%02d. %s" "$counter" "$clean_content")
        rofi_input+="${display_text}\n"
    fi
    ((counter++))
done < /tmp/cliphist_current

chosen_index=$(echo -e -n "$rofi_input" | rofi -dmenu -no-config -me-select-entry "" -me-accept-entry MousePrimary -format 'i' -show-icons -theme-str "
* { font: \"JetBrainsMono NF 10\"; background-color: transparent; text-color: #ffffff; border: 0px; margin: 0px; }
window { width: 550px; background-color: #000000; border: 1px; border-color: #ffffff; border-radius: ${BORDER_RADIUS}; padding: 20px; location: center; anchor: center; }
mainbox { spacing: 12px; border: 0px; background-color: transparent; }
inputbar { padding: 4px 8px; background-color: transparent; border: 0px; children: [ entry ]; }
entry { placeholder: \"Поиск в буфере...\"; text-color: #ffffff; }
listview { lines: 5; columns: 1; spacing: 6px; fixed-height: true; border: 0px; scrollbar: true; }
scrollbar { width: 2px; border: 0px; handle-width: 2px; handle-color: #ffffff; background-color: transparent; }
element { children: [ element-text, element-icon ]; padding: 8px 12px; border-radius: ${BORDER_RADIUS}; spacing: 12px; orientation: horizontal; border: 1px; border-color: transparent; }
element normal.normal { background-color: transparent; }
element alternate.normal { background-color: transparent; }
element selected.normal { background-color: transparent; border: 1px; border-color: #ffffff; }
element selected.urgent { background-color: transparent; border: 1px; border-color: #ffffff; }
element selected.active { background-color: transparent; border: 1px; border-color: #ffffff; }
element-icon { size: 64px; background-color: transparent; }
element-text { expand: true; vertical-align: 0.5; horizontal-align: 0; text-color: #ffffff; background-color: transparent; }
" -p "󰅌")

if [ -n "$chosen_index" ]; then
    line_num=$((chosen_index + 1))
    chosen_line=$(sed -n "${line_num}p" /tmp/cliphist_current)
    if [ -n "$chosen_line" ]; then
        content=$(echo "$chosen_line" | cut -f2-)
        if [[ "$content" == file://* ]]; then
            # Копируем URI как файл
            clean_uri=$(echo "$content" | tr -d '\r' | tr -d '\n')
            echo -n "$clean_uri" | wl-copy -t text/uri-list
        else
            # Копируем стандартный текст и картинки
            printf "%s\n" "$chosen_line" | cliphist decode | wl-copy
        fi
    fi
fi

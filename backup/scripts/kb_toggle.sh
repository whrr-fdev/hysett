#!/usr/bin/env bash
if pgrep -f "kb_overlay.py" > /dev/null; then
    pkill -f "kb_overlay.py"
    rm -f /tmp/kb_overlay.pid
    echo "0" > ~/.config/hypr/scripts/kb.conf
else
    echo "1" > ~/.config/hypr/scripts/kb.conf
    POS=$(python3 -c 'import json,os; p=os.path.expanduser("~/.config/hypr/scripts/kb_overlay_config.json"); print(json.load(open(p)).get("position","bottom-right") if os.path.exists(p) else "bottom-right")' 2>/dev/null)
    SCRIPT="$HOME/.config/hypr/scripts/kb_overlay.py"
    [ ! -f "$SCRIPT" ] && SCRIPT="$HOME/hysett/scripts/kb_overlay.py"
    nohup python3 "$SCRIPT" "${POS:-bottom-right}" >/dev/null 2>&1 &
    echo $! > /tmp/kb_overlay.pid
fi

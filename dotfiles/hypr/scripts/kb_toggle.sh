#!/bin/bash
if pgrep -f "kb_overlay.py" > /dev/null; then
    pkill -f "kb_overlay.py"
    rm -f /tmp/kb_overlay.pid
else
    python3 "/home/whrr/hysett/scripts/kb_overlay.py" >/dev/null 2>&1 &
    echo $! > /tmp/kb_overlay.pid
fi

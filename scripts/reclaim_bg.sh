#!/usr/bin/env bash
~/.config/hypr/scripts/reclaim_mem $(pgrep -f "AyuGram|Throne") 2>/dev/null || true

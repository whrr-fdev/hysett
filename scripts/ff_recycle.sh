#!/usr/bin/env bash
OLD_ADDR="$1"
LOCK_FILE="/tmp/ff_recycle_lock"
DIRTY_FLAG="$HOME/.cache/ff_theme_dirty"
touch "$LOCK_FILE"

if [ -f "$DIRTY_FLAG" ]; then
    rm -f "$DIRTY_FLAG"
    hyprctl eval '
        for _, win in pairs(hl.get_windows()) do
            if string.find(string.lower(win.class or ""), "firefox") then
                hl.dispatch(hl.dsp.window.close({ window = win }))
            end
        end
    ' >/dev/null 2>&1
    for _ in $(seq 1 25); do
        pgrep -x firefox >/dev/null || break
        sleep 0.05
    done
    python3 ~/.config/hypr/scripts/sync_m3_windows.py >/dev/null 2>&1
    rm -f "$DIRTY_FLAG"
    hyprctl eval "hl.window_rule({ name = 'ff-prewarm-trap', match = { class = '.*(?i)firefox.*' }, workspace = '10 silent' })" >/dev/null 2>&1
    MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=65536 firefox >/dev/null 2>&1 &
    sleep 2.0
    rm -f "$LOCK_FILE"
    hyprctl eval "hl.window_rule({ name = 'ff-prewarm-trap', match = { class = '^__none__$' } })" >/dev/null 2>&1
    exit 0
fi

MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=65536 firefox --new-window >/dev/null 2>&1 &

for _ in $(seq 1 40); do
    sleep 0.04
    [ ! -f "$LOCK_FILE" ] && exit 0

    hyprctl eval "
        local ok = false
        for _, win in pairs(hl.get_windows()) do
            if string.find(string.lower(win.class or ''), 'firefox') and win.address ~= '$OLD_ADDR' then
                ok = true
                if win.workspace.id ~= 10 then
                    hl.dispatch(hl.dsp.window.move({ workspace = 10, window = win, follow = false }))
                end
            end
        end
        if ok then
            for _, win in pairs(hl.get_windows()) do
                if win.address == '$OLD_ADDR' and win.workspace.id == 10 then
                    hl.dispatch(hl.dsp.window.close({ window = win }))
                end
            end
            hl.window_rule({ name = 'ff-prewarm-trap', match = { class = '^__none__$' } })
            os.remove('$LOCK_FILE')
        end
    " >/dev/null 2>&1

    if [ ! -f "$LOCK_FILE" ]; then
        (sleep 0.8 && ~/.config/hypr/scripts/reclaim_mem $(pgrep -f firefox) 2>/dev/null) &
        exit 0
    fi
done

rm -f "$LOCK_FILE"
hyprctl eval "hl.window_rule({ name = 'ff-prewarm-trap', match = { class = '^__none__$' } })" >/dev/null 2>&1

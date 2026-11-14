#!/usr/bin/env bash
ACTION="$1"
STATE_FILE="/tmp/hysett_vol_hold_state"
NOW_MS=$(date +%s%3N)

trigger_media() {
    local cmd="$1"
    if [ -S /tmp/hysett_mpv.sock ]; then
        echo "$cmd" > /tmp/hysett_media_cmd
    else
        echo "$cmd" > /tmp/hysett_media_cmd
        playerctl "$cmd" 2>/dev/null || true
    fi
}

case "$ACTION" in
    next|previous|play-pause)
        trigger_media "$ACTION"
        exit 0
        ;;
    vol_up|vol_down)
        LAST_ACT=""
        LAST_MS=0
        HOLD_CNT=0
        LAST_TRIG=0
        if [ -f "$STATE_FILE" ]; then
            read -r LAST_ACT LAST_MS HOLD_CNT LAST_TRIG < "$STATE_FILE"
        fi
        DIFF=$((NOW_MS - LAST_MS))
        if [ "$LAST_ACT" = "$ACTION" ] && [ "$DIFF" -lt 260 ]; then
            HOLD_CNT=$((HOLD_CNT + 1))
        else
            HOLD_CNT=1
        fi

        # Если кнопку удерживают (4 быстрых тика автоповтора ~350 мс) — переключаем трек!
        if [ "$HOLD_CNT" -ge 4 ]; then
            if [ $((NOW_MS - LAST_TRIG)) -gt 1100 ]; then
                if [ "$ACTION" = "vol_up" ]; then
                    wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-
                    trigger_media "next"
                else
                    wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+
                    trigger_media "previous"
                fi
                LAST_TRIG=$NOW_MS
            fi
            echo "$ACTION $NOW_MS $HOLD_CNT $LAST_TRIG" > "$STATE_FILE"
            exit 0
        fi

        echo "$ACTION $NOW_MS $HOLD_CNT $LAST_TRIG" > "$STATE_FILE"
        if [ "$ACTION" = "vol_up" ]; then
            wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        else
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        fi
        ;;
esac

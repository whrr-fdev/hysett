#!/usr/bin/env bash

# --- 1. Функция создания визуальной «колбы» ---
make_flask() {
    local pct=$1
    [ -z "$pct" ] && pct=0
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100

    local total=10
    local filled=$(( (pct + 5) / 10 ))
    [ "$filled" -gt 10 ] && filled=10
    local empty=$(( total - filled ))

    # Цвет жидкости в зависимости от нагрузки
    local color="#89b4fa"
    if [ "$pct" -ge 90 ]; then
        color="#f38ba8"
    elif [ "$pct" -ge 75 ]; then
        color="#f9e2af"
    fi

    local fill_str=""
    local empty_str=""
    for ((i=0; i<filled; i++)); do fill_str="${fill_str}█"; done
    for ((i=0; i<empty; i++)); do empty_str="${empty_str}░"; done

    if [ "$filled" -eq 0 ]; then
        printf "<span color='#585b70'>[%s]</span>" "$empty_str"
    elif [ "$empty" -eq 0 ]; then
        printf "<span color='%s'>[%s]</span>" "$color" "$fill_str"
    else
        printf "<span color='%s'>[%s</span><span color='#585b70'>%s]</span>" "$color" "$fill_str" "$empty_str"
    fi
}

# --- 2. CPU Usage & Temp ---
read -r _ u n s idle iow irq sirq _ < /proc/stat
tot=$((u + n + s + idle + iow + irq + sirq))
cpu_pct=0
if [ -f /tmp/hyprlock_cpu ]; then
    read -r prev_tot prev_idle < /tmp/hyprlock_cpu
    dt=$((tot - prev_tot))
    di=$((idle - prev_idle))
    if [ "$dt" -gt 0 ]; then
        cpu_pct=$((100 * (dt - di) / dt))
    fi
fi
echo "$tot $idle" > /tmp/hyprlock_cpu

# CPU Temp
cpu_temp=""
for hw in /sys/class/hwmon/hwmon*; do
    name=$(cat "$hw/name" 2>/dev/null)
    if [[ "$name" == *"coretemp"* || "$name" == *"k10temp"* || "$name" == *"zenpower"* || "$name" == *"cpu"* ]]; then
        for tfile in "$hw"/temp*_input; do
            if [ -r "$tfile" ]; then
                t=$(cat "$tfile" 2>/dev/null)
                if [ -n "$t" ] && [ "$t" -gt 0 ]; then
                    cpu_temp="$((t / 1000))°C"
                    break 2
                fi
            fi
        done
    fi
done
if [ -z "$cpu_temp" ]; then
    for tz in /sys/class/thermal/thermal_zone*; do
        t=$(cat "$tz/temp" 2>/dev/null)
        if [ -n "$t" ] && [ "$t" -gt 0 ]; then
            cpu_temp="$((t / 1000))°C"
            break
        fi
    done
fi

# --- 3. RAM Usage ---
ram_total=0
ram_avail=0
while read -r key val _; do
    case "$key" in
        MemTotal:) ram_total=$val ;;
        MemAvailable:) ram_avail=$val ;;
    esac
    [ -n "$ram_total" ] && [ "$ram_total" -gt 0 ] && [ -n "$ram_avail" ] && [ "$ram_avail" -gt 0 ] && break
done < /proc/meminfo

ram_pct=0
if [ "$ram_total" -gt 0 ]; then
    ram_pct=$(( (ram_total - ram_avail) * 100 / ram_total ))
fi

# --- 4. GPU Usage ---
gpu_pct=""
if [ -e /dev/nvidia0 ] && command -v nvidia-smi >/dev/null 2>&1; then
    gpu_pct=$(timeout 0.2 nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -dc '0-9')
fi
if [ -z "$gpu_pct" ]; then
    for f in /sys/class/drm/card*/device/gpu_busy_percent; do
        if [ -r "$f" ]; then
            gpu_pct=$(cat "$f" 2>/dev/null | tr -dc '0-9')
            [ -n "$gpu_pct" ] && break
        fi
    done
fi
if [ -z "$gpu_pct" ]; then
    for d in /sys/class/drm/card*; do
        if [ -r "$d/gt_act_freq_mhz" ] && [ -r "$d/gt_max_freq_mhz" ]; then
            act=$(cat "$d/gt_act_freq_mhz" 2>/dev/null)
            max=$(cat "$d/gt_max_freq_mhz" 2>/dev/null)
            if [ -n "$act" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
                gpu_pct=$(( act * 100 / max ))
                break
            fi
        fi
    done
fi
gpu_pct=${gpu_pct:-0}

# --- 5. Вывод форматированной строки ---
cpu_bar=$(make_flask "$cpu_pct")
ram_bar=$(make_flask "$ram_pct")
gpu_bar=$(make_flask "$gpu_pct")

temp_str=""
if [ -n "$cpu_temp" ]; then
    temp_str=" <span color='#f9e2af'></span> ${cpu_temp}"
fi

echo " ${cpu_bar} ${cpu_pct}%${temp_str}   <span color='#6c7086'>•</span>   󰍛 ${ram_bar} ${ram_pct}%   <span color='#6c7086'>•</span>   󰢮 ${gpu_bar} ${gpu_pct}%"

#!/usr/bin/env bash
# gpu-stats.sh — outputs: GPU_PERCENT\nGPU_TEMP\nGPU_NAME
# Tries NVIDIA first, falls back to sysfs (Intel/AMD)
set -euo pipefail
IFS=$'\n\t'

readonly CACHE_FILE="/tmp/qs-gpu-cache"
readonly CACHE_TTL=3

if [[ -f "$CACHE_FILE" ]]; then
    now=$(date +%s)
    mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    if (( now - mtime < CACHE_TTL )); then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

write_cache() {
    local output="$1"
    local tmp="${CACHE_FILE}.tmp"
    printf "%s\n" "$output" > "$tmp"
    mv "$tmp" "$CACHE_FILE"
}

if command -v nvidia-smi >/dev/null 2>&1; then
    NVIDIA_OUT=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null || true)
    if [[ -n "$NVIDIA_OUT" ]] && ! printf "%s" "$NVIDIA_OUT" | grep -qi "failed"; then
        output=$(printf "%s\n" "$NVIDIA_OUT" | awk -F', ' '{
            gsub(/ /, "", $1); gsub(/ /, "", $2)
            print ($1 == "" ? -1 : $1)
            print ($2 == "" ? 0 : $2)
            name=$3; gsub(/NVIDIA GeForce /, "", name); gsub(/GeForce /, "", name)
            print name
        }')
        if [[ -n "$output" ]]; then
            write_cache "$output"
            printf "%s\n" "$output"
            exit 0
        fi
    fi
fi

get_vendor_name() {
    local vendor_id="$1"
    case "$vendor_id" in
        0x10de) echo "NVIDIA" ;;
        0x8086) echo "Intel" ;;
        0x1002) echo "AMD" ;;
        *) echo "GPU" ;;
    esac
}

percent="-1"
temp="0"
name="GPU"

for card in /sys/class/drm/card*; do
    [[ -d "$card" ]] || continue

    vendor_id=""
    if [[ -r "$card/device/vendor" ]]; then
        vendor_id=$(cat "$card/device/vendor" 2>/dev/null || true)
    fi
    name=$(get_vendor_name "$vendor_id")

    if [[ -r "$card/device/gpu_busy_percent" ]]; then
        p=$(cat "$card/device/gpu_busy_percent" 2>/dev/null || true)
        if [[ -n "$p" ]]; then
            percent=$(printf "%s" "$p" | tr -cd '0-9')
            break
        fi
    fi

    if [[ -r "$card/gt_act_freq_mhz" ]] || [[ -r "$card/gt_cur_freq_mhz" ]]; then
        freq=""
        max=""
        if [[ -r "$card/gt_act_freq_mhz" ]]; then
            freq=$(cat "$card/gt_act_freq_mhz" 2>/dev/null || true)
        elif [[ -r "$card/gt_cur_freq_mhz" ]]; then
            freq=$(cat "$card/gt_cur_freq_mhz" 2>/dev/null || true)
        fi
        if [[ -r "$card/gt_max_freq_mhz" ]]; then
            max=$(cat "$card/gt_max_freq_mhz" 2>/dev/null || true)
        elif [[ -r "$card/gt_RP0_freq_mhz" ]]; then
            max=$(cat "$card/gt_RP0_freq_mhz" 2>/dev/null || true)
        fi
        if [[ -n "$freq" && -n "$max" && "$max" -gt 0 ]]; then
            percent=$((freq * 100 / max))
            break
        fi
    fi
done

output=$(printf "%s\n%s\n%s" "$percent" "$temp" "$name")
write_cache "$output"
printf "%s\n" "$output"

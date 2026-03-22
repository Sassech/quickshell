#!/usr/bin/env bash
# ram-stats.sh — Estadísticas de uso de RAM en tiempo real
set -euo pipefail
IFS=$'\n\t'

readonly CACHE_FILE="/tmp/qs-ram-cache"
readonly CACHE_TTL=3

if [[ -f "$CACHE_FILE" ]]; then
    now=$(date +%s)
    mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    if (( now - mtime < CACHE_TTL )); then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

if [[ ! -r /proc/meminfo ]]; then
    exit 1
fi

output=$(awk '/MemTotal:|MemAvailable:|MemFree:|Buffers:|Cached:|SwapTotal:|SwapFree:/ {
    if ($1 == "MemTotal:") mem_total = $2
    else if ($1 == "MemAvailable:") mem_avail = $2
    else if ($1 == "MemFree:") mem_free = $2
    else if ($1 == "Buffers:") buffers = $2
    else if ($1 == "Cached:") cached = $2
    else if ($1 == "SwapTotal:") swap_total = $2
    else if ($1 == "SwapFree:") swap_free = $2
}
END {
    if (mem_total <= 0 || mem_avail <= 0) exit 1
    mem_used = mem_total - mem_avail
    mem_percent = int((mem_used * 100) / mem_total)
    mem_used_gb = mem_used / 1048576
    mem_total_gb = mem_total / 1048576
    mem_avail_gb = mem_avail / 1048576
    swap_used = swap_total - swap_free
    swap_percent = swap_total > 0 ? int((swap_used * 100) / swap_total) : 0
    printf "%d\n%.1f\n%.1f\n%.1f\n%d\n", mem_percent, mem_used_gb, mem_total_gb, mem_avail_gb, swap_percent
}' /proc/meminfo)

if [[ -z "${output}" ]]; then
    exit 1
fi

tmp="${CACHE_FILE}.tmp"
printf "%s\n" "$output" > "$tmp"
mv "$tmp" "$CACHE_FILE"
printf "%s\n" "$output"

#!/bin/bash
# gpu-stats.sh — outputs: GPU_PERCENT\nGPU_TEMP\nGPU_NAME
# Tries NVIDIA first, falls back to Intel UHD sysfs

# NVIDIA
NVIDIA_OUT=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null)
if [ -n "$NVIDIA_OUT" ] && ! echo "$NVIDIA_OUT" | grep -qi "failed"; then
    echo "$NVIDIA_OUT" | awk -F', ' '{
        gsub(/ /, "", $1); gsub(/ /, "", $2)
        print ($1 == "" ? -1 : $1)
        print ($2 == "" ? 0 : $2)
        name=$3; gsub(/NVIDIA GeForce /, "", name); gsub(/GeForce /, "", name)
        print name
    }'
    exit 0
fi

# Intel UHD fallback — GT frequency as activity proxy
INTEL_FREQ_MHZ=0; INTEL_MAX_MHZ=0
for path in /sys/class/drm/card1/gt_cur_freq_mhz /sys/class/drm/card1/gt_act_freq_mhz; do
    [ -f "$path" ] && INTEL_FREQ_MHZ=$(cat "$path" 2>/dev/null) && break
done
for path in /sys/class/drm/card1/gt_max_freq_mhz /sys/class/drm/card1/gt_RP0_freq_mhz; do
    [ -f "$path" ] && INTEL_MAX_MHZ=$(cat "$path" 2>/dev/null) && break
done

INTEL_PCT=-1
[ "${INTEL_MAX_MHZ:-0}" -gt 0 ] && [ "${INTEL_FREQ_MHZ:-0}" -gt 0 ] && \
    INTEL_PCT=$((INTEL_FREQ_MHZ * 100 / INTEL_MAX_MHZ))

echo "$INTEL_PCT"
echo "0"
echo "Intel UHD"



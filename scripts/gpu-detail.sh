#!/bin/bash
# gpu-detail.sh — KEY:VALUE output
# Shows both Intel UHD + NVIDIA (if driver active)

# ── Intel UHD ──────────────────────────────────────────────────
INTEL_NAME="Intel UHD (Tiger Lake-H)"
INTEL_FREQ_MHZ=0
INTEL_TEMP=0

# Try gt_cur_freq_mhz / gt_act_freq_mhz
for path in \
    /sys/class/drm/card1/gt_cur_freq_mhz \
    /sys/class/drm/card1/gt_act_freq_mhz \
    /sys/class/drm/card1/device/gt_cur_freq_mhz; do
    [ -f "$path" ] && INTEL_FREQ_MHZ=$(cat "$path" 2>/dev/null) && break
done

# Intel temp via hwmon with i915/xe
for d in /sys/class/hwmon/hwmon*/; do
    n=$(cat "$d/name" 2>/dev/null)
    [[ "$n" == "i915" || "$n" == "xe" ]] || continue
    t=$(cat "${d}temp1_input" 2>/dev/null)
    INTEL_TEMP=$((${t:-0}/1000))
    break
done

echo "INTEL_NAME:$INTEL_NAME"
echo "INTEL_FREQ:${INTEL_FREQ_MHZ:-0}"
echo "INTEL_TEMP:$INTEL_TEMP"

# ── NVIDIA ─────────────────────────────────────────────────────
NVIDIA_OUT=$(nvidia-smi \
    --query-gpu=name,utilization.gpu,temperature.gpu,\
memory.used,memory.total,power.draw,power.limit,\
clocks.current.graphics,clocks.current.memory,driver_version \
    --format=csv,noheader,nounits 2>/dev/null)

if [ -z "$NVIDIA_OUT" ] || echo "$NVIDIA_OUT" | grep -qi "failed\|error"; then
    echo "NVIDIA_STATUS:inactive"
    echo "NVIDIA_NAME:NVIDIA GeForce RTX 3050 Mobile"
else
    echo "$NVIDIA_OUT" | awk -F', ' '{
        gsub(/^ +| +$/, "", $1)
        name=$1; gsub(/NVIDIA GeForce /, "", name)
        util=($2+0); temp=($3+0)
        vram_used=($4+0); vram_tot=($5+0)
        pwr=($6+0); pwr_lim=($7+0)
        clk_gpu=($8+0); clk_mem=($9+0)
        driver=$10; gsub(/ /, "", driver)
        print "NVIDIA_STATUS:active"
        print "NVIDIA_NAME:" name
        print "NVIDIA_UTIL:" util
        print "NVIDIA_TEMP:" temp
        print "NVIDIA_VRAM_USED:" vram_used
        print "NVIDIA_VRAM_TOTAL:" vram_tot
        print "NVIDIA_POWER:" pwr
        print "NVIDIA_POWER_LIMIT:" pwr_lim
        print "NVIDIA_CLOCK:" clk_gpu
        print "NVIDIA_CLOCK_MEM:" clk_mem
        print "NVIDIA_DRIVER:" driver
    }'
fi

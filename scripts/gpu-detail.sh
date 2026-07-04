#!/bin/bash
# gpu-detail.sh — Multi-vendor GPU detection: Intel / AMD / NVIDIA
# Outputs KEY:VALUE lines. No hardcoded device names or paths.
set -euo pipefail
IFS=$'\n\t'

# ── Helpers ────────────────────────────────────────────────────────────────
read_mhz() {
    # Read a sysfs value in Hz or MHz, always return MHz as integer
    local file="$1" val
    [ -r "$file" ] || { echo 0; return; }
    val=$(< "$file")
    # If value > 100000 it's in Hz (amdgpu freq1_input), convert to MHz
    if [ "$val" -gt 100000 ] 2>/dev/null; then
        echo $(( val / 1000000 ))
    else
        echo "${val:-0}"
    fi
}

read_temp_mc() {
    # Read millicelsius file, return integer °C
    local file="$1" val
    [ -r "$file" ] || { echo 0; return; }
    val=$(< "$file")
    echo $(( ${val:-0} / 1000 ))
}

gpu_name_from_lspci() {
    # Extract GPU name for a PCI slot — single awk call, zero extra forks
    local slot="$1"
    lspci -s "$slot" 2>/dev/null \
        | awk 'NR==1{ sub(/.*: /,""); sub(/ \(rev[^)]*\)/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); print }'
}

# ── Enumerate all GPU cards ────────────────────────────────────────────────
# Process every DRM card that has a vendor file
declare -a GPU_ENTRIES  # each: "vendor:cardpath:pci_slot"

for card in /sys/class/drm/card[0-9]*/; do
    vendor_file="${card}device/vendor"
    [ -r "$vendor_file" ] || continue
    vendor=$(< "$vendor_file")

    # Get PCI slot from symlink target
    pci_slot=$(readlink -f "${card}device" 2>/dev/null | grep -oE '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]' | tail -1 || true)
    [ -z "$pci_slot" ] && pci_slot=$(basename "$(readlink "${card}device" 2>/dev/null)" | grep -oE '[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]' | head -1 || true)

    GPU_ENTRIES+=("${vendor}:${card}:${pci_slot:-unknown}")
done

GPU_INDEX=0

for entry in "${GPU_ENTRIES[@]:-}"; do
    [ -z "$entry" ] && continue
    IFS=':' read -r vendor card pci_slot <<< "$entry"
    IFS=$'\n\t'
    card="${card%:*}:${entry##*:}"  # restore full card path (re-split broke it)
    # Re-parse correctly
    vendor="${entry%%:*}"
    rest="${entry#*:}"
    card="${rest%%:*}"
    pci_short="${rest##*:}"

    GPU_INDEX=$(( GPU_INDEX + 1 ))
    prefix="GPU${GPU_INDEX}"

    case "$vendor" in

    # ── Intel ──────────────────────────────────────────────────────────────
    0x8086)
        # Name from lspci
        name=""
        if [ -n "$pci_short" ] && [ "$pci_short" != "unknown" ]; then
            name=$(gpu_name_from_lspci "$pci_short")
        fi
        [ -z "$name" ] && name=$(lspci 2>/dev/null | awk '/Intel.*VGA|Intel.*UHD|Intel.*Iris|Intel.*Arc/{sub(/.*: /,""); sub(/ \(rev[^)]*\)/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}')
        [ -z "$name" ] && name="Intel GPU"

        # GT base path — kernel ≥6.2 uses gt/gt0/, older uses card root
        gt_base=""
        for try in "${card}gt/gt0" "${card}gt0" "${card}device/gt0" "${card}"; do
            [ -r "${try}/rps_act_freq_mhz" ] && gt_base="$try" && break
            [ -r "${try}/gt_act_freq_mhz"  ] && gt_base="$try" && break
        done

        freq_act=0; freq_cur=0; freq_max=0; freq_min=0
        rc6=0; throttle=0; power_state="unknown"

        if [ -n "$gt_base" ]; then
            [ -r "${gt_base}/rps_act_freq_mhz" ] && freq_act=$(< "${gt_base}/rps_act_freq_mhz")
            [ -r "${gt_base}/gt_act_freq_mhz"  ] && freq_act=$(< "${gt_base}/gt_act_freq_mhz")
            [ -r "${gt_base}/rps_cur_freq_mhz" ] && freq_cur=$(< "${gt_base}/rps_cur_freq_mhz")
            [ -r "${gt_base}/gt_cur_freq_mhz"  ] && freq_cur=$(< "${gt_base}/gt_cur_freq_mhz")
            [ -r "${gt_base}/rps_max_freq_mhz" ] && freq_max=$(< "${gt_base}/rps_max_freq_mhz")
            [ -r "${gt_base}/gt_max_freq_mhz"  ] && freq_max=$(< "${gt_base}/gt_max_freq_mhz")
            [ -r "${gt_base}/rps_min_freq_mhz" ] && freq_min=$(< "${gt_base}/rps_min_freq_mhz")
            [ -r "${gt_base}/rc6_enable"              ] && rc6=$(< "${gt_base}/rc6_enable")
            [ -r "${gt_base}/throttle_reason_status"  ] && throttle=$(< "${gt_base}/throttle_reason_status")
        fi

        [ -r "${card}device/power_state" ] && power_state=$(< "${card}device/power_state")

        # Temperature via hwmon (i915 or xe)
        temp=0
        for d in /sys/class/hwmon/hwmon*/; do
            [ -r "${d}name" ] || continue
            n=$(< "${d}name")
            [[ "$n" == "i915" || "$n" == "xe" ]] || continue
            [ -r "${d}temp1_input" ] && temp=$(read_temp_mc "${d}temp1_input")
            break
        done

        echo "${prefix}_VENDOR:intel"
        echo "${prefix}_NAME:$name"
        echo "${prefix}_FREQ:${freq_act:-${freq_cur:-0}}"
        echo "${prefix}_FREQ_CUR:${freq_cur:-0}"
        echo "${prefix}_FREQ_MAX:${freq_max:-0}"
        echo "${prefix}_FREQ_MIN:${freq_min:-0}"
        echo "${prefix}_TEMP:$temp"
        echo "${prefix}_UTIL:-1"
        echo "${prefix}_RC6:${rc6:-0}"
        echo "${prefix}_THROTTLE:${throttle:-0}"
        echo "${prefix}_POWER_STATE:${power_state:-unknown}"
        ;;

    # ── AMD ────────────────────────────────────────────────────────────────
    0x1002)
        # Name
        name=""
        if [ -n "$pci_short" ] && [ "$pci_short" != "unknown" ]; then
            name=$(gpu_name_from_lspci "$pci_short")
        fi
        [ -z "$name" ] && name=$(lspci 2>/dev/null | awk '/AMD.*VGA|Radeon|RDNA/{sub(/.*: /,""); sub(/ \(rev[^)]*\)/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}')
        [ -z "$name" ] && name="AMD GPU"

        # hwmon linked to this card
        hwmon_dir=""
        for d in /sys/class/hwmon/hwmon*/; do
            [ -r "${d}name" ] || continue
            n=$(< "${d}name")
            [ "$n" = "amdgpu" ] || continue
            # Verify it belongs to this card by checking symlink target
            hw_dev=$(readlink -f "${d}device" 2>/dev/null || true)
            card_dev=$(readlink -f "${card}device" 2>/dev/null || true)
            [ "$hw_dev" = "$card_dev" ] && hwmon_dir="$d" && break
        done

        # Fallback: first amdgpu hwmon
        if [ -z "$hwmon_dir" ]; then
            for d in /sys/class/hwmon/hwmon*/; do
                [ -r "${d}name" ] || continue
                [ "$(< "${d}name")" = "amdgpu" ] && hwmon_dir="$d" && break
            done
        fi

        temp_edge=0; temp_junction=0; freq=0; power=0; vram_used=0; vram_total=0; util=0
        if [ -n "$hwmon_dir" ]; then
            [ -r "${hwmon_dir}temp1_input" ] && temp_edge=$(read_temp_mc "${hwmon_dir}temp1_input")
            [ -r "${hwmon_dir}temp2_input" ] && temp_junction=$(read_temp_mc "${hwmon_dir}temp2_input")
            [ -r "${hwmon_dir}freq1_input" ] && freq=$(read_mhz "${hwmon_dir}freq1_input")
            if [ -r "${hwmon_dir}power1_average" ]; then
                pw=$(< "${hwmon_dir}power1_average")
                power=$(( ${pw:-0} / 1000000 ))  # uW → W
            fi
        fi

        # VRAM (bytes → MiB)
        [ -r "${card}device/mem_info_vram_used"  ] && vram_used=$(( $(< "${card}device/mem_info_vram_used")  / 1048576 ))
        [ -r "${card}device/mem_info_vram_total" ] && vram_total=$(( $(< "${card}device/mem_info_vram_total") / 1048576 ))

        # Utilization
        [ -r "${card}device/gpu_busy_percent" ] && util=$(< "${card}device/gpu_busy_percent")

        echo "${prefix}_VENDOR:amd"
        echo "${prefix}_NAME:$name"
        echo "${prefix}_TEMP_EDGE:$temp_edge"
        echo "${prefix}_TEMP_JUN:$temp_junction"
        echo "${prefix}_FREQ:$freq"
        echo "${prefix}_POWER:$power"
        echo "${prefix}_VRAM_USED:$vram_used"
        echo "${prefix}_VRAM_TOTAL:$vram_total"
        echo "${prefix}_UTIL:$util"
        ;;

    # ── NVIDIA ─────────────────────────────────────────────────────────────
    0x10de)
        NVIDIA_OUT=$(nvidia-smi \
            --query-gpu=name,utilization.gpu,temperature.gpu,\
memory.used,memory.total,power.draw,power.limit,\
clocks.current.graphics,clocks.current.memory,driver_version \
            --format=csv,noheader,nounits 2>/dev/null || true)

        if [ -z "$NVIDIA_OUT" ] || echo "$NVIDIA_OUT" | grep -qi "failed\|error"; then
            echo "${prefix}_VENDOR:nvidia"
            echo "${prefix}_STATUS:inactive"
        else
            echo "$NVIDIA_OUT" | awk -F', ' -v p="$prefix" '{
                gsub(/^ +| +$/, "", $1)
                print p "_VENDOR:nvidia"
                print p "_STATUS:active"
                print p "_NAME:" $1
                print p "_UTIL:" ($2+0)
                print p "_TEMP:" ($3+0)
                print p "_VRAM_USED:" ($4+0)
                print p "_VRAM_TOTAL:" ($5+0)
                print p "_POWER:" $6+0
                print p "_POWER_LIMIT:" $7+0
                print p "_FREQ:" ($8+0)
                print p "_FREQ_MEM:" ($9+0)
                driver=$10; gsub(/ /, "", driver)
                print p "_DRIVER:" driver
            }'
        fi
        ;;
    esac
done

# Total GPU count for the QML parser
echo "GPU_COUNT:$GPU_INDEX"

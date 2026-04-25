#!/bin/bash
# set-power-mode.sh — requiere root (ejecutar con pkexec)
set -eo pipefail

MODE=$1

set_gov() {
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$1" > "$f" 2>/dev/null
    done
}

set_epp() {
    for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        echo "$1" > "$f" 2>/dev/null
    done
}

case $MODE in
    powersaver)
        set_gov powersave
        set_epp power
        ;;
    balanced)
        set_gov powersave
        set_epp balance_performance
        ;;
    performance)
        set_gov performance
        set_epp performance
        ;;
esac

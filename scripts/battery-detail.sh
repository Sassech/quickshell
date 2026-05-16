#!/bin/bash
# battery-detail.sh — health, capacity (Wh), cycle count
# Outputs KEY:VALUE lines. Supports energy_full and charge_full batteries.
set -euo pipefail
IFS=$'\n\t'

# Find first battery
bat=""
for p in /sys/class/power_supply/*/; do
    [ -r "${p}type" ] || continue
    [ "$(< "${p}type")" = "Battery" ] || continue
    bat="$p"
    break
done

[ -z "$bat" ] && exit 0

# Determine mode: energy (uWh) or charge (uAh)
ef=0; efd=0; volt=0

if [ -r "${bat}energy_full" ] && [ -r "${bat}energy_full_design" ]; then
    ef=$(< "${bat}energy_full")
    efd=$(< "${bat}energy_full_design")
    # Health
    [ "$efd" -gt 0 ] && awk -v a="$ef" -v b="$efd" 'BEGIN{printf "HEALTH:%.1f\n", a*100/b}'
    # Capacity in Wh (energy_full is in µWh)
    [ "$ef" -gt 0 ] && awk -v a="$ef" 'BEGIN{printf "CAP_WH:%.1f\n", a/1000000}'

elif [ -r "${bat}charge_full" ] && [ -r "${bat}charge_full_design" ]; then
    ef=$(< "${bat}charge_full")
    efd=$(< "${bat}charge_full_design")
    # Health
    [ "$efd" -gt 0 ] && awk -v a="$ef" -v b="$efd" 'BEGIN{printf "HEALTH:%.1f\n", a*100/b}'
    # Capacity in Wh: charge_full (µAh) × voltage_now (µV) ÷ 1e12
    if [ -r "${bat}voltage_now" ]; then
        volt=$(< "${bat}voltage_now")
        [ "$ef" -gt 0 ] && [ "$volt" -gt 0 ] && \
            awk -v c="$ef" -v v="$volt" 'BEGIN{printf "CAP_WH:%.1f\n", c*v/1e12}'
    fi
fi

# Cycle count
if [ -r "${bat}cycle_count" ]; then
    cycles=$(< "${bat}cycle_count")
    [ "${cycles:-0}" -gt 0 ] && echo "CYCLES:$cycles"
fi

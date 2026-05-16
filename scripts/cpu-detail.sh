#!/bin/bash
# cpu-detail.sh — datos detallados de CPU via dgop + sysfs
set -euo pipefail
IFS=$'\n\t'

CURSOR_FILE="/tmp/qs-cpu-detail-cursor"
CURSOR=""
if [ -r "$CURSOR_FILE" ]; then
    CURSOR="$(<"$CURSOR_FILE")"
fi

if [ -n "$CURSOR" ]; then
    dgop meta --modules cpu --cpu-cursor "$CURSOR" --json 2>/dev/null
else
    dgop meta --modules cpu --json 2>/dev/null
fi | python3 -c "
import sys, json, re
d = json.load(sys.stdin)
c = d['cpu']

cursor = c.get('cursor', '')
if cursor:
    open('/tmp/qs-cpu-detail-cursor', 'w').write(cursor)

model = c['model']
model = re.sub(r'\(R\)|\(TM\)|11th Gen ', '', model)
model = re.sub(r' @ [\d.]+GHz', '', model)
model = re.sub(r'  +', ' ', model).strip()

core_pcts = ','.join(str(round(x)) for x in c['coreUsage'])

print('MODEL:' + model)
print('NCORES:' + str(c['count']))
print('CORE_PCTS:' + core_pcts)
print('PKG_TEMP:' + str(c['temperature']))
print('AVG_FREQ:' + str(round(c['frequency'])))
"

# Per-core temps — supports Intel (coretemp) and AMD (k10temp)
# Uses bash built-in reads — zero forks in the temperature loop
CPU_VENDOR=$(awk -F': ' '/vendor_id/{print $2; exit}' /proc/cpuinfo)

for d in /sys/class/hwmon/hwmon*/; do
    [ -r "${d}name" ] || continue
    hwmon_name=$(< "${d}name")

    # Intel: coretemp exposes per-core temp*_input with label "Core N"
    if [ "$hwmon_name" = "coretemp" ]; then
        ct=""
        for f in "${d}"temp*_input; do
            [ -r "$f" ] || continue
            lbl_file="${f/_input/_label}"
            [ -r "$lbl_file" ] || continue
            label=$(< "$lbl_file")
            [[ "$label" == Core* ]] || continue
            raw=$(< "$f")
            ct="${ct},$(( ${raw:-0} / 1000 ))"
        done
        echo "CORE_TEMPS:${ct#,}"
        echo "CPU_VENDOR:intel"
        break
    fi

    # AMD: k10temp exposes Tdie/Tctl (temp1) and optionally Tccd cores (temp3+)
    if [ "$hwmon_name" = "k10temp" ]; then
        # Tdie is the package temp (already reported as PKG_TEMP by dgop)
        # Tccd cores: temp3_input, temp5_input, ... (every 2nd starting at 3)
        ct=""
        for f in "${d}"temp*_input; do
            [ -r "$f" ] || continue
            lbl_file="${f/_input/_label}"
            [ -r "$lbl_file" ] || continue
            label=$(< "$lbl_file")
            # Tccd labels look like "Tccd1", "Tccd2" — each covers a CCD
            [[ "$label" == Tccd* ]] || continue
            raw=$(< "$f")
            ct="${ct},$(( ${raw:-0} / 1000 ))"
        done
        # If no Tccd, at least emit Tdie repeated per core count as approximation
        if [ -z "$ct" ] && [ -r "${d}temp1_input" ]; then
            tdie=$(( $(< "${d}temp1_input") / 1000 ))
            ncores=$(nproc 2>/dev/null || echo 1)
            for (( i=0; i<ncores; i++ )); do ct="${ct},${tdie}"; done
        fi
        echo "CORE_TEMPS:${ct#,}"
        echo "CPU_VENDOR:amd"
        break
    fi
done

MAX_FREQ=""
GOV=""
EPP=""
[ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]         && MAX_FREQ=$(< /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]          && GOV=$(< /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
[ -r /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ] && EPP=$(< /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)
echo "MAX_FREQ:$(( ${MAX_FREQ:-0} / 1000 ))"
echo "GOV:${GOV:-unknown}"
echo "EPP:${EPP:-unknown}"

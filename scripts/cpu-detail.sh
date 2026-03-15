#!/bin/bash
# cpu-detail.sh — datos detallados de CPU via dgop + sysfs para campos que dgop no provee

CURSOR_FILE="/tmp/qs-cpu-detail-cursor"
CURSOR=$(cat "$CURSOR_FILE" 2>/dev/null)

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

# Per-core temps y max freq desde sysfs (dgop no los provee)
for d in /sys/class/hwmon/hwmon*/; do
    [ "$(cat "$d/name" 2>/dev/null)" = "coretemp" ] || continue
    ct=""
    for f in "${d}"temp*_input; do
        lbl_file="${f/_input/_label}"
        label=$(cat "$lbl_file" 2>/dev/null)
        [[ "$label" == Core* ]] || continue
        t=$(($(cat "$f" 2>/dev/null || echo 0)/1000))
        ct="${ct},${t}"
    done
    echo "CORE_TEMPS:${ct#,}"
    break
done

MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
echo "MAX_FREQ:$((${MAX_FREQ:-0}/1000))"
echo "GOV:${GOV:-unknown}"
echo "EPP:${EPP:-unknown}"

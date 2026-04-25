#!/bin/bash
# disk-detail.sh — detalle de disco via dgop + sysfs
set -euo pipefail
IFS=$'\n\t'

# Modelo y firmware desde sysfs (dgop no los provee)
NVME_MODEL=$(cat /sys/class/nvme/nvme0/model 2>/dev/null | sed 's/  */ /g;s/^ //;s/ $//')
NVME_FW=$(cat /sys/class/nvme/nvme0/firmware_rev 2>/dev/null | tr -d ' ')

# Temperatura NVMe desde hwmon
NVME_TEMP=0
for d in /sys/class/hwmon/hwmon*/; do
    [ "$(cat "$d/name" 2>/dev/null)" = "nvme" ] || continue
    t=$(cat "${d}temp1_input" 2>/dev/null)
    NVME_TEMP=$((${t:-0}/1000))
    break
done

# Uso del disco raíz via dgop
dgop disk --json 2>/dev/null | python3 -c "
import sys, json

d = json.load(sys.stdin)
for m in d.get('mounts', []):
    if m['mount'] == '/':
        def parse_g(s):
            s = s.strip()
            num = float(s.rstrip('GMKT'))
            unit = s[-1].upper()
            if unit == 'T': num *= 1024
            elif unit == 'M': num /= 1024
            return round(num)
        print('TOTAL:' + str(parse_g(m['size'])))
        print('USED:'  + str(parse_g(m['used'])))
        print('AVAIL:' + str(parse_g(m['avail'])))
        print('PCT:'   + m['percent'].rstrip('%'))
        break
"

echo "MODEL:${NVME_MODEL:-NVMe SSD}"
echo "FW:${NVME_FW:-N/A}"
echo "TEMP:$NVME_TEMP"

# Tasas de lectura/escritura via /proc/diskstats (dgop no provee deltas de I/O)
ROOT_DEV=$(df / | tail -1 | awk '{print $1}' | sed 's|/dev/||;s|p[0-9]*$||')
read_diskstats() {
    grep " $1 " /proc/diskstats 2>/dev/null | awk '{print $6, $10}'
}
s1=$(read_diskstats "$ROOT_DEV"); sleep 0.4; s2=$(read_diskstats "$ROOT_DEV")
READ_MBS=0; WRITE_MBS=0
if [ -n "$s1" ] && [ -n "$s2" ]; then
    READ_MBS=$(awk -v a="$s1" -v b="$s2" 'BEGIN{
        split(a,x); split(b,y)
        dr=(y[1]-x[1])*512/1048576/0.4
        printf "%.1f", (dr<0)?0:dr }')
    WRITE_MBS=$(awk -v a="$s1" -v b="$s2" 'BEGIN{
        split(a,x); split(b,y)
        dw=(y[2]-x[2])*512/1048576/0.4
        printf "%.1f", (dw<0)?0:dw }')
fi
echo "READ_MBS:$READ_MBS"
echo "WRITE_MBS:$WRITE_MBS"

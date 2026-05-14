#!/bin/bash
# disk-detail.sh — detalle de disco via dgop + sysfs
set -euo pipefail
IFS=$'\n\t'

# Modelo y firmware desde sysfs (dgop no los provee)
NVME_MODEL=""
if [ -r /sys/class/nvme/nvme0/model ]; then
    NVME_MODEL=$(< /sys/class/nvme/nvme0/model)
    NVME_MODEL="${NVME_MODEL#"${NVME_MODEL%%[![:space:]]*}"}"  # ltrim
    NVME_MODEL="${NVME_MODEL%"${NVME_MODEL##*[![:space:]]}"}"  # rtrim
fi
NVME_FW=""
if [ -r /sys/class/nvme/nvme0/firmware_rev ]; then
    NVME_FW=$(< /sys/class/nvme/nvme0/firmware_rev)
    NVME_FW="${NVME_FW// /}"  # trim spaces (bash, no tr)
fi

# Temperatura NVMe desde hwmon (bash built-in reads, sin fork)
NVME_TEMP=0
for d in /sys/class/hwmon/hwmon*/; do
    [ -r "${d}name" ] || continue
    hwmon_name=$(< "${d}name")
    [ "$hwmon_name" = "nvme" ] || continue
    if [ -r "${d}temp1_input" ]; then
        t=$(< "${d}temp1_input")
        NVME_TEMP=$(( ${t:-0} / 1000 ))
    fi
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
# df + awk en un solo fork (antes eran 4 forks: df | tail | awk | sed)
ROOT_DEV=$(df --output=source / | awk 'NR==2{ sub(/^\/dev\//,""); sub(/p[0-9]+$/,""); print }')
read_diskstats() {
    # awk solo, sin grep previo (antes eran 2 forks por llamada)
    awk -v d="$1" '$3==d{print $6,$10}' /proc/diskstats
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

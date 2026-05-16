#!/bin/bash
# disk-detail.sh — detalle de disco via dgop + sysfs
set -euo pipefail
IFS=$'\n\t'

# Modelo y firmware — detectar primer NVMe disponible dinámicamente
NVME_DEV=""
for dev in /sys/class/nvme/nvme*/; do
    [ -r "${dev}model" ] && NVME_DEV="$dev" && break
done

NVME_MODEL=""
NVME_FW=""
if [ -n "$NVME_DEV" ]; then
    if [ -r "${NVME_DEV}model" ]; then
        NVME_MODEL=$(< "${NVME_DEV}model")
        NVME_MODEL="${NVME_MODEL#"${NVME_MODEL%%[![:space:]]*}"}"  # ltrim
        NVME_MODEL="${NVME_MODEL%"${NVME_MODEL##*[![:space:]]}"}"  # rtrim
    fi
    if [ -r "${NVME_DEV}firmware_rev" ]; then
        NVME_FW=$(< "${NVME_DEV}firmware_rev")
        NVME_FW="${NVME_FW// /}"
    fi
fi

# Temperatura NVMe desde hwmon — cualquier dispositivo nvme
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

# Uso del disco: raíz y home via dgop
dgop disk --json 2>/dev/null | python3 -c "
import sys, json

def parse_g(s):
    s = s.strip()
    if not s: return 0
    num = float(s.rstrip('GMKTgmkt'))
    unit = s[-1].upper()
    if unit == 'T': num *= 1024
    elif unit == 'M': num /= 1024
    return round(num)

d = json.load(sys.stdin)
root_done = False
home_done = False
for m in d.get('mounts', []):
    mp = m.get('mount', '')
    if mp == '/' and not root_done:
        print('TOTAL:'      + str(parse_g(m['size'])))
        print('USED:'       + str(parse_g(m['used'])))
        print('AVAIL:'      + str(parse_g(m['avail'])))
        print('PCT:'        + m['percent'].rstrip('%'))
        root_done = True
    elif mp == '/home' and not home_done:
        print('HOME_TOTAL:' + str(parse_g(m['size'])))
        print('HOME_USED:'  + str(parse_g(m['used'])))
        print('HOME_AVAIL:' + str(parse_g(m['avail'])))
        print('HOME_PCT:'   + m['percent'].rstrip('%'))
        home_done = True
    if root_done and home_done:
        break

# Si /home no es un mount separado, fallback via df
if not home_done:
    import subprocess, shlex
    try:
        out = subprocess.check_output(['df', '-BG', '--output=size,used,avail,pcent', '/home'],
                                      text=True, timeout=3)
        lines = out.strip().splitlines()
        if len(lines) >= 2:
            parts = lines[1].split()
            print('HOME_TOTAL:' + parts[0].rstrip('G'))
            print('HOME_USED:'  + parts[1].rstrip('G'))
            print('HOME_AVAIL:' + parts[2].rstrip('G'))
            print('HOME_PCT:'   + parts[3].rstrip('%'))
    except Exception:
        print('HOME_TOTAL:0')
        print('HOME_USED:0')
        print('HOME_AVAIL:0')
        print('HOME_PCT:0')
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

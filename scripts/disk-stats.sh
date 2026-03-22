#!/usr/bin/env bash
# disk-stats.sh — uso de disco raiz via dgop
set -euo pipefail
IFS=$'\n\t'

readonly CACHE_FILE="/tmp/qs-disk-cache"
readonly CACHE_TTL=20

if [[ -f "$CACHE_FILE" ]]; then
    now=$(date +%s)
    mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    if (( now - mtime < CACHE_TTL )); then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

if ! command -v dgop >/dev/null 2>&1; then
    exit 1
fi

output=$(dgop disk --json 2>/dev/null | python3 -c "
import sys, json

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)

for m in d.get('mounts', []):
    if m.get('mount') == '/':
        def parse_g(s):
            s = s.strip()
            num = float(s.rstrip('GMKT'))
            unit = s[-1].upper()
            if unit == 'T':
                num *= 1024
            elif unit == 'M':
                num /= 1024
            return round(num)
        print(parse_g(m['used']))
        print(parse_g(m['avail']))
        print(int(m['percent'].rstrip('%')))
        break
")

if [[ -z "${output}" ]]; then
    exit 1
fi

tmp="${CACHE_FILE}.tmp"
printf "%s\n" "$output" > "$tmp"
mv "$tmp" "$CACHE_FILE"
printf "%s\n" "$output"

#!/usr/bin/env bash
# cpu-stats.sh — CPU% y temp via dgop (cursor-based para delta preciso)
set -euo pipefail
IFS=$'\n\t'

readonly CURSOR_FILE="/tmp/qs-cpu-cursor"
readonly CACHE_FILE="/tmp/qs-cpu-cache"
readonly CACHE_TTL=2

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

cursor=""
if [[ -r "$CURSOR_FILE" ]]; then
    cursor=$(cat "$CURSOR_FILE" 2>/dev/null || true)
fi

if [[ -n "$cursor" ]]; then
    json=$(dgop meta --modules cpu --cpu-cursor "$cursor" --json 2>/dev/null || true)
else
    json=$(dgop meta --modules cpu --json 2>/dev/null || true)
fi

if [[ -z "${json}" ]]; then
    exit 1
fi

output=$(printf "%s" "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
c = d.get('cpu', {})
if 'usage' not in c:
    sys.exit(1)
usage = round(c.get('usage', 0))
temp = c.get('temperature', 0)
print(usage)
print(temp)
cursor = c.get('cursor', '')
if cursor:
    open('/tmp/qs-cpu-cursor', 'w').write(cursor)
")

if [[ -z "${output}" ]]; then
    exit 1
fi

tmp="${CACHE_FILE}.tmp"
printf "%s\n" "$output" > "$tmp"
mv "$tmp" "$CACHE_FILE"
printf "%s\n" "$output"

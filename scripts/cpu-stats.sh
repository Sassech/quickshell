#!/bin/bash
# cpu-stats.sh — CPU% y temp via dgop (cursor-based para delta preciso)

CURSOR_FILE="/tmp/qs-cpu-cursor"
CURSOR=$(cat "$CURSOR_FILE" 2>/dev/null)

if [ -n "$CURSOR" ]; then
    dgop meta --modules cpu --cpu-cursor "$CURSOR" --json 2>/dev/null
else
    dgop meta --modules cpu --json 2>/dev/null
fi | python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d['cpu']
print(round(c['usage']))
print(c['temperature'])
cursor = c.get('cursor', '')
if cursor:
    open('/tmp/qs-cpu-cursor', 'w').write(cursor)
"

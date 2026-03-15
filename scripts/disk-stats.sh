#!/bin/bash
# disk-stats.sh — uso de disco raiz via dgop

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
        print(parse_g(m['used']))
        print(parse_g(m['avail']))
        print(int(m['percent'].rstrip('%')))
        break
"

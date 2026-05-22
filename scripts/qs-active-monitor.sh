#!/usr/bin/env bash
# qs-active-monitor.sh — imprime el nombre del monitor donde está el cursor
# Uso: qs-active-monitor.sh
# Retorna: nombre del monitor (ej: "DP-1") o el monitor focused como fallback
set -eo pipefail

python3 - <<'EOF'
import json, subprocess, sys

cursor = subprocess.run(
    ["hyprctl", "cursorpos"],
    capture_output=True, text=True
).stdout.strip()

monitors = json.loads(subprocess.run(
    ["hyprctl", "monitors", "-j"],
    capture_output=True, text=True
).stdout)

if cursor and "," in cursor:
    cx, cy = [int(x.strip()) for x in cursor.split(",", 1)]
    for m in monitors:
        mx, my = m["x"], m["y"]
        mw = int(m["width"]  / m.get("scale", 1.0))
        mh = int(m["height"] / m.get("scale", 1.0))
        if mx <= cx < mx + mw and my <= cy < my + mh:
            print(m["name"])
            sys.exit(0)

# Fallback: monitor con focused=true
focused = next((m["name"] for m in monitors if m.get("focused")), None)
print(focused or (monitors[0]["name"] if monitors else ""))
EOF

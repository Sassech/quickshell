#!/usr/bin/env bash
# qs-active-monitor.sh — imprime el nombre del monitor con foco activo del teclado
# Uso: qs-active-monitor.sh
# Retorna: nombre del monitor (ej: "DP-1")
# Prioridad:
#   1) monitor de la ventana activa (si existe y tiene monitor válido)
#   2) monitor marcado como focused=true por Hyprland
#   3) monitor donde está el cursor
#   4) primer monitor
set -eo pipefail

python3 - <<'EOF'
import json, subprocess, sys

monitors = json.loads(subprocess.run(
    ["hyprctl", "monitors", "-j"],
    capture_output=True, text=True
).stdout)

if not monitors:
    print("")
    sys.exit(0)

# 1) Monitor donde está la ventana con foco de teclado activo
active_raw = subprocess.run(
    ["hyprctl", "activewindow", "-j"],
    capture_output=True, text=True
).stdout.strip()

if active_raw:
    try:
        aw = json.loads(active_raw)
        mon_id = aw.get("monitor", -1)
        if mon_id >= 0:
            for m in monitors:
                if m.get("id") == mon_id:
                    print(m["name"])
                    sys.exit(0)
    except (json.JSONDecodeError, KeyError):
        pass

# 2) Monitor marcado como focused por Hyprland
for m in monitors:
    if m.get("focused"):
        print(m["name"])
        sys.exit(0)

# 3) Monitor donde está el cursor (más confiable que focused cuando hay layershells)
try:
    cursor = json.loads(subprocess.run(
        ["hyprctl", "cursorpos", "-j"],
        capture_output=True, text=True
    ).stdout)
    cx, cy = cursor.get("x", -1), cursor.get("y", -1)
    if cx >= 0 and cy >= 0:
        for m in monitors:
            x, y = m["x"], m["y"]
            w = m["width"]
            h = m["height"]
            if x <= cx < x + w and y <= cy < y + h:
                print(m["name"])
                sys.exit(0)
except Exception:
    pass

# 4) Primer monitor como último recurso
print(monitors[0]["name"])
EOF

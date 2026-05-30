#!/usr/bin/env bash
# qs-active-monitor.sh — imprime el nombre del monitor con foco activo del teclado
# Uso: qs-active-monitor.sh
# Retorna: nombre del monitor (ej: "DP-1")
# Prioridad: 1) monitor de la ventana activa  2) monitor con focused=true  3) primer monitor
set -eo pipefail

python3 - <<'EOF'
import json, subprocess, sys

monitors = json.loads(subprocess.run(
    ["hyprctl", "monitors", "-j"],
    capture_output=True, text=True
).stdout)

# 1) Monitor donde está la ventana con foco de teclado activo
active_raw = subprocess.run(
    ["hyprctl", "activewindow", "-j"],
    capture_output=True, text=True
).stdout.strip()

if active_raw:
    try:
        aw = json.loads(active_raw)
        mon_id = aw.get("monitor", -1)
        for m in monitors:
            if m.get("id") == mon_id:
                print(m["name"])
                sys.exit(0)
    except (json.JSONDecodeError, KeyError):
        pass

# 2) Monitor marcado como focused por Hyprland
focused = next((m["name"] for m in monitors if m.get("focused")), None)
print(focused or (monitors[0]["name"] if monitors else ""))
EOF

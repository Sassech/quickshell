#!/bin/bash
# qs-reload.sh — Recarga la configuración de quickshell
# Mata la instancia actual y la relanza (como exec-once del login).
set -euo pipefail

LOG_FILE="/tmp/qs-reload.log"

# Mata la instancia actual (si hay). quickshell kill existe como subcomando.
quickshell kill >> "$LOG_FILE" 2>&1 || true
sleep 0.3

# Relanza detached. Hereda WAYLAND_DISPLAY del entorno del bind (hyprland).
nohup quickshell >> "$LOG_FILE" 2>&1 &

echo "Quickshell recargado (PID $!)" >> "$LOG_FILE"

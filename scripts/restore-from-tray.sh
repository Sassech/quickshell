#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# restore-from-tray.sh — Restaura ventanas desde workspace especial "minimized"
#
# Uso:
#   restore-from-tray.sh <class>   → Busca y restaura ventana por clase
#
# Llamado cuando se hace click en un ícono del system tray
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

CLASS="${1:-}"

if [[ -z "$CLASS" ]]; then
    exit 1
fi

# Obtener todas las ventanas en el workspace especial "minimized"
CLIENTS=$(hyprctl clients -j 2>/dev/null)

# Buscar ventana que coincida con la clase (case-insensitive)
WINDOW_ADDRESS=$(echo "$CLIENTS" | jq -r --arg class "$CLASS" '
    .[] | select(
        .workspace.name == "special:minimized" and 
        (.class | ascii_downcase) == ($class | ascii_downcase)
    ) | .address' | head -n1)

if [[ -n "$WINDOW_ADDRESS" && "$WINDOW_ADDRESS" != "null" ]]; then
    # Mover ventana al workspace actual y enfocarla
    hyprctl dispatch movetoworkspace "name:*,address:$WINDOW_ADDRESS"
    hyprctl dispatch focuswindow "address:$WINDOW_ADDRESS"
fi

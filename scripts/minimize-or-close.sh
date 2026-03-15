#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# minimize-or-close.sh — Minimiza apps SNI al tray o cierra ventanas normales
#
# Uso:
#   SUPER+Q → Este script decide si minimizar (apps SNI) o cerrar la ventana
#
# Apps SNI se mueven a workspace especial en lugar de cerrarse,
# manteniendo la música/procesos activos en segundo plano.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN: Apps que deben minimizarse al tray en lugar de cerrarse
# ══════════════════════════════════════════════════════════════════════════════

# Lista de clases de ventanas que implementan StatusNotifierItem
# Estas apps se minimizan al tray y siguen corriendo en segundo plano
TRAY_APPS=(
    "spotify"
    "Spotify"
    "discord"
    "Discord"
    "telegram"
    "telegramdesktop"
    "TelegramDesktop"
    "slack"
    "Slack"
    "element"
    "Element"
    "signal"
    "Signal"
    "steam"
    "Steam"
    "vesktop"
    "Vesktop"
)

# Archivo de configuración opcional (puede no existir)
CONFIG_FILE="$HOME/.config/quickshell/config/tray-apps.conf"

# ══════════════════════════════════════════════════════════════════════════════
# FUNCIONES
# ══════════════════════════════════════════════════════════════════════════════

# Cargar apps adicionales desde archivo de configuración
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            # Ignorar líneas vacías y comentarios
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            TRAY_APPS+=("$line")
        done < "$CONFIG_FILE"
    fi
}

# Verificar si una clase está en la lista de apps SNI
is_tray_app() {
    local class="$1"
    local app
    
    for app in "${TRAY_APPS[@]}"; do
        # Comparación case-insensitive
        if [[ "${class,,}" == "${app,,}" ]]; then
            return 0
        fi
    done
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

# Cargar configuración adicional
load_config

# Obtener información de la ventana activa
ACTIVE_WINDOW=$(hyprctl activewindow -j 2>/dev/null)

# Verificar que hay una ventana activa
if [[ -z "$ACTIVE_WINDOW" || "$ACTIVE_WINDOW" == "{}" ]]; then
    # No hay ventana activa, no hacer nada
    exit 0
fi

# Extraer datos relevantes usando jq
ADDRESS=$(echo "$ACTIVE_WINDOW" | jq -r '.address // empty')
CLASS=$(echo "$ACTIVE_WINDOW" | jq -r '.class // empty')
TITLE=$(echo "$ACTIVE_WINDOW" | jq -r '.title // empty')

# Validar que tenemos datos
if [[ -z "$ADDRESS" || "$ADDRESS" == "null" ]]; then
    # No hay address válida, salir
    exit 0
fi

# Logging opcional (descomenta para debug)
# echo "Window: class=$CLASS, title=$TITLE, address=$ADDRESS" >> /tmp/minimize-or-close.log

# ──────────────────────────────────────────────────────────────────────────────
# DECISIÓN: ¿Minimizar al tray o cerrar?
# ──────────────────────────────────────────────────────────────────────────────

if is_tray_app "$CLASS"; then
    # App SNI → minimizar a workspace especial (mantiene procesos activos)
    hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDRESS"
    
    # Cambiar foco a la ventana anterior para que el workspace especial se oculte
    hyprctl dispatch focuscurrentorlast 2>/dev/null || true
    
    # Si el workspace especial sigue visible, ocultarlo explícitamente
    sleep 0.1  # Pequeña pausa para que Hyprland procese
    WORKSPACE_VISIBLE=$(hyprctl workspaces -j 2>/dev/null | jq -r '.[] | select(.name=="special:minimized") | .monitor')
    if [[ -n "$WORKSPACE_VISIBLE" && "$WORKSPACE_VISIBLE" != "null" ]]; then
        hyprctl dispatch togglespecialworkspace "minimized" 2>/dev/null || true
    fi
    
    # Notificación opcional (requiere notify-send)
    if command -v notify-send &>/dev/null; then
        notify-send -a "System Tray" -i "window-minimize" \
            "$CLASS minimizado" \
            "La app sigue corriendo en segundo plano" \
            -t 2000 2>/dev/null || true
    fi
else
    # App normal → cerrar ventana
    hyprctl dispatch closewindow "address:$ADDRESS"
fi

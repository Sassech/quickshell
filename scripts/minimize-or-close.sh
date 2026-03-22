#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# minimize-or-close.sh — Cierra o minimiza ventana activa
#
# Detecta dinámicamente si la app implementa SNI via D-Bus comparando
# el nombre del servicio D-Bus contra la clase de la ventana activa.
# Si hay match → mueve a special:minimized (minimize al tray).
# Si no hay match → cierra la ventana.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Devuelve el nombre final del path de cada item SNI registrado, en minúsculas.
# Formato raw:  ":1.485/org/ayatana/NotificationItem/spotify_client"
# Resultado:    "spotify_client"
get_registered_sni_items() {
    dbus-send --print-reply --dest=org.kde.StatusNotifierWatcher \
        --type=method_call /StatusNotifierWatcher \
        org.freedesktop.DBus.Properties.Get \
        string:"org.kde.StatusNotifierWatcher" \
        string:"RegisteredStatusNotifierItems" 2>/dev/null \
    | grep -oP '(?<=string ")[^"]+' \
    | sed 's|.*/||' \
    || true
}

# ── Ventana activa ────────────────────────────────────────────────────────────
ACTIVE_WINDOW=$(hyprctl activewindow -j 2>/dev/null)
[[ -z "$ACTIVE_WINDOW" || "$ACTIVE_WINDOW" == "{}" ]] && exit 0

CLASS=$(echo "$ACTIVE_WINDOW" | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')
[[ -z "$CLASS" ]] && exit 0

ADDRESS=$(echo "$ACTIVE_WINDOW" | jq -r '.address')

# ── Comparación SNI ───────────────────────────────────────────────────────────
# Busca si alguno de los servicios registrados contiene la clase de la ventana.
# Se compara contra el nombre del servicio completo (ej: org.telegram.desktop)
# para reducir falsos positivos respecto a comparar solo el basename.
SNI_ITEMS=$(get_registered_sni_items)

# Verifica si algún item SNI contiene la clase de la ventana.
# ej: "spotify_client" contiene "spotify"  → match
has_sni_match() {
    local class="$1"
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        if [[ "${item,,}" == *"${class,,}"* ]]; then
            return 0
        fi
    done <<< "$SNI_ITEMS"
    return 1
}

# ── Acción ────────────────────────────────────────────────────────────────────
if has_sni_match "$CLASS"; then
    # Minimizar: mover al workspace especial sin mostrarlo
    hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDRESS"

    # Si el workspace special:minimized estaba visible antes de mover,
    # ocultarlo para que no quede flotando vacío.
    # (movetoworkspacesilent no lo muestra, pero si ya estaba abierto sí queda visible)
    sleep 0.1
    MINIMIZED_VISIBLE=$(hyprctl workspaces -j 2>/dev/null \
        | jq -r '.[] | select(.name == "special:minimized") | .monitor // empty')

    if [[ -n "$MINIMIZED_VISIBLE" ]]; then
        hyprctl dispatch togglespecialworkspace "minimized"
    fi
else
    # Cerrar normalmente
    hyprctl dispatch closewindow "address:$ADDRESS"
fi
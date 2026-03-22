#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# minimize-or-close.sh — Cierra o minimiza ventana activa
#
# Detecta dinámicamente si la app implementa SNI via D-Bus
# y la minimiza al workspace special:minimized si es el caso.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

get_registered_sni_apps() {
    dbus-send --print-reply --dest=org.kde.StatusNotifierWatcher \
        --type=method_call /StatusNotifierWatcher \
        org.freedesktop.DBus.Properties.Get \
        string:"org.kde.StatusNotifierWatcher" \
        string:"RegisteredStatusNotifierItems" 2>/dev/null | \
        grep 'string ":' | \
        sed 's/.*string "//;s/"$//' | \
        while IFS= read -r item; do
            basename "$item" | tr '[:upper:]' '[:lower:]'
        done
}

ACTIVE_WINDOW=$(hyprctl activewindow -j 2>/dev/null)
[[ -z "$ACTIVE_WINDOW" || "$ACTIVE_WINDOW" == "{}" ]] && exit 0

CLASS=$(echo "$ACTIVE_WINDOW" | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')
[[ -z "$CLASS" ]] && exit 0

SNI_APPS=$(get_registered_sni_apps)

if echo "$SNI_APPS" | grep -qiF "$CLASS"; then
    ADDRESS=$(echo "$ACTIVE_WINDOW" | jq -r '.address')
    hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDRESS"
    sleep 0.1
    WORKSPACE_VISIBLE=$(hyprctl workspaces -j 2>/dev/null | \
        jq -r '.[] | select(.name=="special:minimized") | .monitor')
    [[ -n "$WORKSPACE_VISIBLE" ]] && \
        hyprctl dispatch togglespecialworkspace "minimized"
else
    hyprctl dispatch closewindow address:$(echo "$ACTIVE_WINDOW" | jq -r '.address')
fi

#!/usr/bin/env bash
# screenshot.sh — captura con grimblast (freeze, sin cursor)
# Uso: screenshot.sh [fullscreen|active|region]

set -euo pipefail
IFS=$'\n\t'

PICTURES="${XDG_PICTURES_DIR:-}"
[[ -z "$PICTURES" && -d "$HOME/Imágenes" ]] && PICTURES="$HOME/Imágenes"
[[ -z "$PICTURES" ]] && PICTURES="$HOME/Pictures"
SAVE_DIR="$PICTURES/Screenshots"
mkdir -p "$SAVE_DIR"
FILE="$SAVE_DIR/screenshot_$(date +"%Y-%m-%d_%H-%M-%S").png"
MODE="${1:-region}"

case "$MODE" in
    fullscreen|full)
        grimblast --freeze copysave output "$FILE"
        ;;

    active|window)
        # Selector interactivo: hover ilumina la ventana, click la captura.
        # (grimblast active captura la ventana enfocada al instante; acá se elige con el cursor)
        if command -v slurp >/dev/null && command -v hyprpicker >/dev/null; then
            hyprpicker -rz &
            HPID=$!
            sleep 0.2
            hyprctl keyword layerrule "noanim,selection" >/dev/null 2>&1 || true
            workspaces="$(hyprctl monitors -j | jq -r '[(foreach .[] as $monitor (0; if $monitor.specialWorkspace.name == "" then $monitor.activeWorkspace else $monitor.specialWorkspace end)).id]')"
            windows="$(hyprctl clients -j | jq -c --argjson workspaces "$workspaces" 'map(select([.workspace.id] | inside($workspaces)))')"
            GEOM="$(jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<<"$windows" | slurp -r 2>/dev/null)" || true
            kill "$HPID" 2>/dev/null || true
            [[ -z "$GEOM" ]] && exit 1
            grim -g "$GEOM" "$FILE"
        else
            grimblast --freeze copysave active "$FILE"
        fi
        ;;

    region|*)
        grimblast --freeze copysave area "$FILE"
        ;;
esac

[[ -f "$FILE" ]] || exit 0

wl-copy < "$FILE"

case "$MODE" in
    fullscreen|full) LABEL="Full screen"   ;;
    active|window)   LABEL="Active window" ;;
    *)               LABEL="Region"        ;;
esac

notify-send \
    --urgency=normal \
    --expire-time=4000 \
    --icon="$FILE" \
    "Screenshot saved" \
    "$LABEL — $(basename "$FILE")"

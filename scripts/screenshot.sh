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
        # Overlay interactivo: hover sobre ventana la ilumina, click la captura
        grimblast --freeze copysave area "$FILE"
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

#!/usr/bin/env bash
# screenshot.sh — captura con grimblast (freeze)
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
        grimblast --freeze copysave active "$FILE"
        ;;

    region|*)
        grimblast --freeze copysave area "$FILE"
        ;;
esac

[[ -f "$FILE" ]] || exit 0

wl-copy < "$FILE"

case "$MODE" in
    fullscreen|full) LABEL="Pantalla completa" ;;
    active|window)   LABEL="Ventana activa"    ;;
    *)               LABEL="Región"            ;;
esac

notify-send \
    --urgency=normal \
    --expire-time=4000 \
    --icon="$FILE" \
    "$(basename "$FILE")"

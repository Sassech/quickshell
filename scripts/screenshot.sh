#!/usr/bin/env bash
# screenshot.sh — captura con grim
# Uso: screenshot.sh [fullscreen|active|region]

PICTURES="${XDG_PICTURES_DIR:-}"
[[ -z "$PICTURES" && -d "$HOME/Imágenes" ]] && PICTURES="$HOME/Imágenes"
[[ -z "$PICTURES" ]] && PICTURES="$HOME/Pictures"
SAVE_DIR="$PICTURES/Screenshots"
mkdir -p "$SAVE_DIR"
FILE="$SAVE_DIR/screenshot_$(date +"%Y-%m-%d_%H-%M-%S").png"
MODE="${1:-region}"

case "$MODE" in
    fullscreen|full)
        OUTPUT=$(hyprctl monitors -j 2>/dev/null | \
            python3 -c "import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))" 2>/dev/null)
        if [[ -n "$OUTPUT" ]]; then
            grim -o "$OUTPUT" "$FILE"
        else
            grim "$FILE"
        fi
        ;;

    active|window)
        GEOM=$(hyprctl activewindow -j 2>/dev/null | \
            python3 -c "
import json,sys
w=json.load(sys.stdin)
x,y=w['at']; ww,wh=w['size']
print(f'{x},{y} {ww}x{wh}')
" 2>/dev/null)
        if [[ -n "$GEOM" ]]; then
            grim -g "$GEOM" "$FILE"
        else
            grim "$FILE"
        fi
        ;;

    region|*)
        # slurp | grim -g - lee la región desde stdin
        GEOM=$(slurp 2>/dev/null) || exit 0
        [[ -z "$GEOM" ]] && exit 0
        grim -g "$GEOM" "$FILE"
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


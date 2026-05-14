#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# wallpaper-set.sh — Cambia el fondo de pantalla y regenera el tema de colores
#                    (Material You via matugen) para quickshell, hyprlock y mako.
#
# Uso:
#   wallpaper-set.sh /ruta/imagen.png   → cambia fondo + aplica tema
#   wallpaper-set.sh                    → solo aplica tema desde el fondo actual
#
# Hyprland keybind:
#   bind = $mod SHIFT, T, exec, ~/.config/quickshell/scripts/wallpaper-set.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

QS_DIR="$HOME/.config/quickshell"
THEME_FILE="$QS_DIR/Components/Theme.qml"
PARSE_SCRIPT="$QS_DIR/scripts/parse-matugen.py"
HYPRLOCK="$HOME/.config/hypr/hyprlock.conf"
MAKO_CONFIG="$HOME/.config/mako/config"

# ── 1. Resolver wallpaper ─────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
    WALLPAPER="$1"

    # ── 2. Cambiar fondo con swww ─────────────────────────────────────────
    if ! pgrep -x swww-daemon > /dev/null; then
        swww-daemon --no-cache &
        for i in $(seq 1 20); do swww query &>/dev/null && break; sleep 0.3; done
    fi

    swww img "$WALLPAPER" \
        --transition-type wipe \
        --transition-duration 0.8 \
        --transition-angle 30 \
        --transition-fps 60

    echo "$WALLPAPER" > /tmp/qs-current-wallpaper
    echo "$WALLPAPER" > "$QS_DIR/config/current-wallpaper"
else
    # Auto-detectar desde swww
    WALLPAPER=$(swww query 2>/dev/null | grep -oP '(?<=image: )[^\n]+' | head -1)
    if [[ -z "$WALLPAPER" ]]; then
        echo "ERROR: No se detectó fondo activo. Pasa la ruta como argumento."
        exit 1
    fi
fi

[[ ! -f "$WALLPAPER" ]] && { echo "ERROR: Imagen no encontrada: $WALLPAPER"; exit 1; }

echo "Aplicando tema desde: $WALLPAPER"

# ── 3. Regenerar Theme.qml + hyprlock.conf ───────────────────────────────
python3 "$PARSE_SCRIPT" "$WALLPAPER" "$THEME_FILE" "$HYPRLOCK"

# ── 4. Reiniciar quickshell ──────────────────────────────────────────────
if pgrep -x quickshell > /dev/null; then
    pkill -x quickshell
    sleep 0.6
fi
nohup quickshell > /tmp/quickshell.log 2>&1 &

# ── 5. Actualizar mako con los nuevos colores ─────────────────────────────
BASE_COLOR=$(grep   'readonly property color _bg:'    "$THEME_FILE" | awk -F'"' '{print $2}')
ACCENT_COLOR=$(grep 'readonly property color accent:' "$THEME_FILE" | awk -F'"' '{print $2}')
TEXT_COLOR=$(grep   'readonly property color text:'   "$THEME_FILE" | awk -F'"' '{print $2}')

cat > "$MAKO_CONFIG" <<EOF
background-color=$BASE_COLOR
border-color=$ACCENT_COLOR
text-color=$TEXT_COLOR
border-radius=8
border-size=2
padding=16
margin=24
font=JetBrains Mono 12
max-icon-size=64
width=400
height=120
anchor=top-right
progress-color=$ACCENT_COLOR

default-timeout=5000

[urgency=critical]
border-color=#e53e3e
progress-color=#e53e3e
EOF

pkill mako 2>/dev/null || true
nohup mako > /dev/null 2>&1 &

echo "Listo — tema aplicado."

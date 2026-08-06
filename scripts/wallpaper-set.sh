#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# wallpaper-set.sh — Cambia el fondo de pantalla (por monitor o global) y
#                    regenera el tema de colores (Material You via matugen)
#                    para quickshell, hyprlock y mako.
#
# Uso:
#   wallpaper-set.sh                       → solo aplica tema desde el fondo actual
#   wallpaper-set.sh /ruta/imagen.png      → cambia fondo en TODOS los monitores + tema
#   wallpaper-set.sh /ruta/imagen.png OUT  → cambia fondo solo en el monitor OUT (p.ej. eDP-1)
#   wallpaper-set.sh --restore             → restaura el fondo de cada monitor conectado
#                                             desde lo persistido (usado al arrancar)
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
CURRENT_FILE="$QS_DIR/config/current-wallpaper"
MONITORS_FILE="$QS_DIR/config/wallpaper-monitors.json"

mkdir -p "$QS_DIR/config"
[[ -f "$MONITORS_FILE" ]] || echo '{}' > "$MONITORS_FILE"

ensure_daemon() {
    if ! pgrep -x swww-daemon > /dev/null; then
        swww-daemon --no-cache &
        for i in $(seq 1 20); do swww query &>/dev/null && break; sleep 0.3; done
    fi
}

connected_monitors() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[].name'
}

# Guarda/actualiza la entrada de un monitor en el JSON (atómico).
save_monitor_entry() {
    local output="$1" path="$2"
    local tmp="$MONITORS_FILE.tmp"
    jq --arg o "$output" --arg p "$path" '.[$o] = $p' "$MONITORS_FILE" > "$tmp"
    mv "$tmp" "$MONITORS_FILE"
}

regenerate_theme() {
    local ref="$1"
    echo "Aplicando tema desde: $ref"
    python3 "$PARSE_SCRIPT" "$ref" "$THEME_FILE" "$HYPRLOCK"
}

update_mako() {
    local base accent text
    base=$(grep   'readonly property color _bg:'    "$THEME_FILE" | awk -F'"' '{print $2}')
    accent=$(grep 'readonly property color accent:' "$THEME_FILE" | awk -F'"' '{print $2}')
    text=$(grep   'readonly property color text:'   "$THEME_FILE" | awk -F'"' '{print $2}')

    mkdir -p "$(dirname "$MAKO_CONFIG")"
    cat > "$MAKO_CONFIG" <<EOF
background-color=$base
border-color=$accent
text-color=$text
border-radius=8
border-size=2
padding=16
margin=24
font=JetBrains Mono 12
max-icon-size=64
width=400
height=120
anchor=top-right
progress-color=$accent

default-timeout=5000

[urgency=critical]
border-color=#e53e3e
progress-color=#e53e3e
EOF

    pkill mako 2>/dev/null || true
    nohup mako > /dev/null 2>&1 &
}

restart_quickshell() {
    if pgrep -x quickshell > /dev/null; then
        pkill -x quickshell
        sleep 0.6
    fi
    nohup quickshell > /tmp/quickshell.log 2>&1 &
}

# ── Modo --restore: llamado una vez al arrancar Hyprland ────────────────────
# Restaura el wallpaper de CADA monitor conectado desde wallpaper-monitors.json.
# No reinicia quickshell (todavía no arrancó en esta etapa del startup).
if [[ "${1:-}" == "--restore" ]]; then
    ensure_daemon

    fallback=""
    [[ -f "$CURRENT_FILE" ]] && fallback=$(tr -d '\n' < "$CURRENT_FILE")

    ref=""
    while IFS= read -r out; do
        [[ -z "$out" ]] && continue
        wp=$(jq -r --arg o "$out" '.[$o] // empty' "$MONITORS_FILE")
        [[ -z "$wp" ]] && wp="$fallback"
        [[ -z "$wp" || ! -f "$wp" ]] && continue

        swww img "$wp" -o "$out" --transition-type none || true
        [[ -z "$ref" ]] && ref="$wp"
    done < <(connected_monitors)

    if [[ -n "$ref" ]]; then
        regenerate_theme "$ref"
        update_mako
    fi
    exit 0
fi

# ── 1. Resolver wallpaper ─────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
    WALLPAPER="$1"
    OUTPUT="${2:-}"

    [[ ! -f "$WALLPAPER" ]] && { echo "ERROR: Imagen no encontrada: $WALLPAPER"; exit 1; }

    # ── 2. Cambiar fondo con swww ─────────────────────────────────────────
    ensure_daemon

    if [[ -n "$OUTPUT" ]]; then
        # Fondo solo para ese monitor
        swww img "$WALLPAPER" -o "$OUTPUT" \
            --transition-type wipe \
            --transition-duration 0.8 \
            --transition-angle 30 \
            --transition-fps 60
        save_monitor_entry "$OUTPUT" "$WALLPAPER"
    else
        # Sin monitor especificado: fondo global (todos los monitores conectados)
        swww img "$WALLPAPER" \
            --transition-type wipe \
            --transition-duration 0.8 \
            --transition-angle 30 \
            --transition-fps 60
        while IFS= read -r out; do
            [[ -n "$out" ]] && save_monitor_entry "$out" "$WALLPAPER"
        done < <(connected_monitors)
    fi

    echo "$WALLPAPER" > /tmp/qs-current-wallpaper
    echo "$WALLPAPER" > "$CURRENT_FILE"
else
    # Auto-detectar desde swww (toma el primero que reporte)
    WALLPAPER=$(swww query 2>/dev/null | grep -oP '(?<=image: )[^\n]+' | head -1)
    if [[ -z "$WALLPAPER" ]]; then
        echo "ERROR: No se detectó fondo activo. Pasa la ruta como argumento."
        exit 1
    fi
fi

[[ ! -f "$WALLPAPER" ]] && { echo "ERROR: Imagen no encontrada: $WALLPAPER"; exit 1; }

# ── 3. Regenerar Theme.qml + hyprlock.conf ───────────────────────────────
regenerate_theme "$WALLPAPER"

# ── 4. Reiniciar quickshell ──────────────────────────────────────────────
restart_quickshell

# ── 5. Actualizar mako con los nuevos colores ─────────────────────────────
update_mako

echo "Listo — tema aplicado."

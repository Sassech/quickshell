#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# wallpaper-set.sh — Cambia el fondo de pantalla (por monitor o global) y
#                    regenera el tema de colores (Material You via matugen)
#                    para quickshell e hyprlock.
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

# ── Helpers de video (mpvpaper) ──────────────────────────────────────────────
is_video() {
    local path="$1"
    case "${path,,}" in
        *.mp4|*.webm|*.mkv|*.mov) return 0 ;;
        *) return 1 ;;
    esac
}

has_mpvpaper() {
    command -v mpvpaper &>/dev/null
}

kill_mpvpaper() {
    local output="$1"
    local pidfile="/tmp/qs-mpvpaper-$output.pid"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(cat "$pidfile")"
        if kill -0 "$pid" 2>/dev/null; then
            # mpvpaper 1.8 ignores SIGTERM/SIGINT entirely (verified empirically:
            # process survives 7+ seconds after both signals) — escalate to
            # SIGKILL after a brief grace period so switches stay responsive
            # and no orphaned renderer is ever left behind.
            kill "$pid" 2>/dev/null
            for _ in 1 2 3; do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.1
            done
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
        fi
    fi
    rm -f "$pidfile"
}

start_mpvpaper() {
    local path="$1" output="$2"
    # -p/-s are boolean flags (no value) and mpvpaper rejects using both at
    # once ("You cannot use auto-pause and auto-stop together") — verified
    # empirically. -s (auto-stop) alone: heavier resource savings, matches
    # the original resource-usage rationale. loop-file=inf: without it mpv
    # plays the clip once and exits, silently reverting to the swww layer
    # underneath — verified empirically (an 8s test clip vanished after
    # finishing). A wallpaper must loop.
    mpvpaper -l bottom -s -o "hwdec=auto-safe no-audio loop-file=inf" "$output" "$path" \
        &>"/tmp/qs-mpvpaper-$output.log" &
    local pid=$!
    echo "$pid" > "/tmp/qs-mpvpaper-$output.pid"
    disown

    # Liveness probe: launching a background process is not the same as it
    # working. A crash or a fatal startup error (bad codec, corrupt file)
    # otherwise leaves a black wallpaper while the script already reported
    # success. Poll briefly (up to ~2s) because mpvpaper takes ~1.8s to give
    # up on a corrupt file (verified empirically: "Failed to recognize file
    # format." appears in the log while the process stays alive). Fail fast on
    # either a dead PID or a fatal log line, and clean up the stray process.
    local log="/tmp/qs-mpvpaper-$output.log"
    local fail="failed to recognize|moov atom not found|failed to open|no such file or directory"
    local ok=0
    for _ in 1 2 3 4 5 6 7; do
        sleep 0.3
        if grep -qiE "$fail" "$log" 2>/dev/null; then
            ok=1
            break
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            ok=1
            break
        fi
    done
    if [[ $ok -eq 1 ]]; then
        echo "ERROR: mpvpaper no pudo reproducir el video en $output (revisá $log)" >&2
        kill_mpvpaper "$output"
        return 1
    fi
    return 0
}

extract_frame() {
    local path="$1"
    local safe="${path//\//_}"
    safe="${safe// /_}"
    local thumb="/tmp/qs-wallpaper-thumbs/$safe.jpg"
    mkdir -p /tmp/qs-wallpaper-thumbs
    if [[ ! -f "$thumb" ]]; then
        ffmpeg -y -ss 00:00:00.5 -i "$path" -frames:v 1 -q:v 3 \
            -vf "scale=180:120:force_original_aspect_ratio=increase,crop=180:120" \
            "$thumb" &>/dev/null || true
    fi
    echo "$thumb"
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
    if is_video "$ref"; then
        ref=$(extract_frame "$ref")
    fi
    echo "Aplicando tema desde: $ref"
    python3 "$PARSE_SCRIPT" "$ref" "$THEME_FILE" "$HYPRLOCK"
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

        if is_video "$wp"; then
            has_mpvpaper || continue
            kill_mpvpaper "$out"
            # Best-effort en restore: un video que falla no debe impedir que
            # los otros monitores recuperen su wallpaper (el error ya quedó
            # en stderr + log de start_mpvpaper).
            start_mpvpaper "$wp" "$out" || true
        else
            kill_mpvpaper "$out"
            swww img "$wp" -o "$out" --transition-type none || true
        fi
        [[ -z "$ref" ]] && ref="$wp"
    done < <(connected_monitors)

    if [[ -n "$ref" ]]; then
        regenerate_theme "$ref"
    fi
    exit 0
fi

# ── 1. Resolver wallpaper ─────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
    WALLPAPER="$1"
    OUTPUT="${2:-}"

    [[ ! -f "$WALLPAPER" ]] && { echo "ERROR: Imagen no encontrada: $WALLPAPER"; exit 1; }

    if is_video "$WALLPAPER" && ! has_mpvpaper; then
        echo "ERROR: mpvpaper no está instalado; no se puede aplicar un video de fondo."
        exit 1
    fi

    # ── 2. Cambiar fondo (swww para imagen/gif, mpvpaper para video) ──────
    ensure_daemon

    if [[ -n "$OUTPUT" ]]; then
        # Fondo solo para ese monitor
        kill_mpvpaper "$OUTPUT"
        if is_video "$WALLPAPER"; then
            # Sin `|| true`: si el probe falla, set -e saca al script con exit
            # code != 0 → el picker QML muestra el error (onExited exitCode).
            start_mpvpaper "$WALLPAPER" "$OUTPUT"
        else
            swww img "$WALLPAPER" -o "$OUTPUT" \
                --transition-type wipe \
                --transition-duration 0.8 \
                --transition-angle 30 \
                --transition-fps 60
        fi
        save_monitor_entry "$OUTPUT" "$WALLPAPER"
    else
        # Sin monitor especificado: fondo global (todos los monitores conectados)
        while IFS= read -r out; do
            [[ -n "$out" ]] && kill_mpvpaper "$out"
        done < <(connected_monitors)
        if is_video "$WALLPAPER"; then
            while IFS= read -r out; do
                # Best-effort en modo global: un monitor que falla no aborta
                # el resto (error ya en stderr + log).
                [[ -n "$out" ]] && start_mpvpaper "$WALLPAPER" "$out" || true
            done < <(connected_monitors)
        else
            swww img "$WALLPAPER" \
                --transition-type wipe \
                --transition-duration 0.8 \
                --transition-angle 30 \
                --transition-fps 60
        fi
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
# quickshell 0.3.0 recarga Theme.qml automáticamente (hot-reload),
# no hace falta reiniciar el shell — evita huérfanos de los readers FIFO.

echo "Listo — tema aplicado."

#!/usr/bin/env bash
# qs-volume-fifo — ran by Quickshell at startup
# Reads commands from FIFO, executes volume changes.
set -eo pipefail

FIFO=/tmp/qs-volume

# Limpiar FIFO al salir (SIGTERM, SIGINT, exit normal)
trap 'rm -f "$FIFO"' EXIT INT TERM

rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

while IFS= read -r cmd <&3; do
    case "$cmd" in
        increment\ *)
            n="${cmd#increment }"
            wpctl set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ "${n}%+" >/dev/null 2>&1
            ;;
        decrement\ *)
            n="${cmd#decrement }"
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${n}%-" >/dev/null 2>&1
            ;;
        mute)
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1
            ;;
    esac

    state=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
    if [[ "$state" =~ Volume:[[:space:]]*([0-9.]+) ]]; then
        vol="${BASH_REMATCH[1]}"
        pct=$(awk -v v="$vol" 'BEGIN { printf "%d", v * 100 }')
        muted=0
        if [[ "$state" == *"[MUTED]"* ]]; then
            muted=1
        fi
        printf "%s:%s\n" "$pct" "$muted"
    fi
done

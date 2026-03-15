#!/usr/bin/env bash
# qs-volume-fifo — ran by Quickshell at startup
# Reads commands from FIFO and outputs current volume as "pct:muted"

FIFO=/tmp/qs-volume

rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

while IFS= read -r cmd <&3; do
    case "$cmd" in
        increment\ *)
            n="${cmd#increment }"
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${n}%+" >/dev/null 2>&1
            ;;
        decrement\ *)
            n="${cmd#decrement }"
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${n}%-" >/dev/null 2>&1
            ;;
        mute)
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1
            ;;
    esac

    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    pct=$(echo "$vol" | awk '{printf "%d", $2 * 100}')
    muted=$(echo "$vol" | grep -c MUTED || true)
    echo "${pct}:${muted}"
done

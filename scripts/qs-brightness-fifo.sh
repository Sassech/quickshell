#!/usr/bin/env bash
# qs-brightness-fifo — ran by Quickshell at startup
# Reads commands from FIFO and outputs current brightness as percentage

FIFO=/tmp/qs-brightness

rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

while IFS= read -r cmd <&3; do
    case "$cmd" in
        increment\ *)
            n="${cmd#increment }"
            brightnessctl set "${n}%+" >/dev/null 2>&1
            ;;
        decrement\ *)
            n="${cmd#decrement }"
            brightnessctl set "${n}%-" >/dev/null 2>&1
            ;;
    esac

    echo $(( $(brightnessctl get) * 100 / $(brightnessctl max) ))
done

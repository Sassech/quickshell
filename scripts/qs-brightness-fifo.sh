#!/usr/bin/env bash
# qs-brightness-fifo — ran by Quickshell at startup
# Reads commands from FIFO and outputs current brightness as percentage
set -eo pipefail

FIFO=/tmp/qs-brightness

# Limpiar FIFO al salir (SIGTERM, SIGINT, exit normal)
trap 'rm -f "$FIFO"' EXIT INT TERM

rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

# Cachear el máximo — no cambia en runtime, ahorra 1 fork por cada lectura
BRIGHT_MAX=$(brightnessctl max)

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

    echo $(( $(brightnessctl get) * 100 / BRIGHT_MAX ))
done

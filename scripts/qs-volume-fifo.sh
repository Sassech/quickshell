#!/usr/bin/env bash
# qs-volume-fifo — ran by Quickshell at startup
# Reads commands from FIFO, executes volume changes.
# Volume/mute state updates arrive via PipeWire native bindings.

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

    # Trigger OSD in shell.qml (values are ignored there now)
    echo "0:0"
done

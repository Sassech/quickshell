#!/usr/bin/env bash
# screenshot-fifo.sh — FIFO monitor para el modal de captura (SUPER+SHIFT+S)
# Quickshell lee este proceso; al recibir una línea emite broadcastScreenshot.

set -eo pipefail

FIFO="/tmp/qs-screenshot"

trap 'rm -f "$FIFO"' EXIT INT TERM

rm -f "$FIFO"
mkfifo "$FIFO"

exec 3<>"$FIFO"
while IFS= read -r line <&3; do
    printf '%s\n' "$line"
done

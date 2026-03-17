#!/bin/bash
# clipboard-delete.sh <id> — Elimina entrada del historial
set -euo pipefail

LOG_FILE="/tmp/qs-clipboard.log"
ID="${1:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

if [[ -z "$ID" ]]; then
    log "[delete] Error: ID vacío"
    exit 1
fi

DELETED=$(cliphist list 2>&1 | awk -v id="$ID" -F'\t' '$1 == id {print; exit}')

if [[ -z "$DELETED" ]]; then
    log "[delete] Warning: ID '$ID' no encontrado"
    exit 0
fi

echo "$DELETED" | cliphist delete 2>/dev/null
log "[delete] OK: $ID"
exit 0
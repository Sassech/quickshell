#!/bin/bash
# clipboard-copy.sh <id> — Copia entrada al portapapeles
set -euo pipefail

LOG_FILE="/tmp/qs-clipboard.log"
ID="${1:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

if [[ -z "$ID" ]]; then
    log "[copy] Error: ID vacío"
    exit 1
fi

TMPDIR="/tmp/qs-clip"
mkdir -p "$TMPDIR"
TMPFILE=$(mktemp --suffix=.bin -p "$TMPDIR")
TMPDEC=$(mktemp -p "$TMPDIR")
trap "rm -f '$TMPFILE' '$TMPDEC'" RETURN

LIST=$(cliphist list 2>/dev/null) || {
    log "[copy] Error: cliphist list falló"
    exit 2
}

ENTRY=$(echo "$LIST" | awk -v id="$ID" -F'\t' '$1 == id {print; exit}')

if [[ -z "$ENTRY" ]]; then
    log "[copy] Error: ID '$ID' no encontrado en cliphist"
    exit 3
fi

PREVIEW=$(echo "$ENTRY" | cut -f2-)

echo "$ENTRY" | cliphist decode > "$TMPDEC"

if [[ "$PREVIEW" =~ \[\[\ binary ]]; then
    if [[ "$PREVIEW" =~ png ]]; then
        MIME="image/png"
    elif [[ "$PREVIEW" =~ jpe?g ]]; then
        MIME="image/jpeg"
    elif [[ "$PREVIEW" =~ gif ]]; then
        MIME="image/gif"
    elif [[ "$PREVIEW" =~ webp ]]; then
        MIME="image/webp"
    elif [[ "$PREVIEW" =~ svg ]]; then
        MIME="image/svg+xml"
    else
        MIME="application/octet-stream"
    fi
    
    cp "$TMPDEC" "$TMPFILE"
    wl-copy --type "$MIME" < "$TMPFILE"
    log "[copy] OK: $ID ($MIME)"
else
    MIME_TYPE=$(file -b --mime-type "$TMPDEC" 2>/dev/null || echo "text/plain")
    
    if [[ "$MIME_TYPE" =~ ^image/ ]]; then
        wl-copy --type "$MIME_TYPE" < "$TMPDEC"
        log "[copy] OK: $ID ($MIME_TYPE - auto-detected)"
    else
        wl-copy < "$TMPDEC"
        log "[copy] OK: $ID (text)"
    fi
fi

exit 0
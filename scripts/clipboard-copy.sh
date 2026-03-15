#!/bin/bash
# clipboard-copy.sh <id>
ID="$1"

# Usar grep con -F para búsqueda literal (evita problemas con caracteres especiales)
ENTRY=$(cliphist list 2>/dev/null | grep -F -P "^${ID}\t")
[[ -z "$ENTRY" ]] && exit 1

PREVIEW=$(echo "$ENTRY" | cut -f2-)

# Detectar si es binario (imagen)
if [[ "$PREVIEW" =~ ^\[\[\ binary ]]; then
    # Es binario, determinar el tipo MIME
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
    # Copiar binario con tipo MIME
    echo "$ENTRY" | cliphist decode 2>/dev/null | wl-copy --type "$MIME"
else
    # Es texto, copiar normalmente
    echo "$ENTRY" | cliphist decode 2>/dev/null | wl-copy
fi

#!/bin/bash
# clipboard-debug.sh — Diagnóstico del clipboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Clipboard Debug ==="
echo ""
echo "Dependencias:"
echo "  cliphist:     $(command -v cliphist 2>/dev/null || echo 'NO INSTALADO')"
echo "  wl-copy:      $(command -v wl-copy 2>/dev/null || echo 'NO INSTALADO')"
echo "  wl-paste:     $(command -v wl-paste 2>/dev/null || echo 'NO INSTALADO')"
echo "  ImageMagick:  $(command -v magick 2>/dev/null || echo 'NO INSTALADO')"
echo ""

echo "Últimas 5 entradas:"
cliphist list 2>/dev/null | head -5 || echo "  (sin entradas o cliphist falló)"
echo ""

echo "Últimos errores:"
if [[ -f /tmp/qs-clipboard.log ]]; then
    tail -10 /tmp/qs-clipboard.log
else
    echo "  (sin errores registrados)"
fi
echo ""

echo "Prueba de copia de primera entrada:"
FIRST_ID=$(cliphist list 2>/dev/null | head -1 | cut -f1)
if [[ -n "$FIRST_ID" ]]; then
    echo "  ID: $FIRST_ID"
    if bash "$SCRIPT_DIR/clipboard-copy.sh" "$FIRST_ID" 2>/dev/null; then
        echo "  OK"
    else
        echo "  FALLO (exit code: $?)"
    fi
else
    echo "  (sin entradas para probar)"
fi
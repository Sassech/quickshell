#!/bin/bash
# qs-helper-install.sh — Baja e instala qs-helper desde GitHub Releases.
# Descarga el binario precompilado qs-helper-linux-amd64 (linux x64 únicamente)
# desde el release "latest" del repo. Verifica el checksum SHA-256 contra el
# archivo SHA256SUMS publicado en el release.

# Uso: qs-helper-install.sh [destino]   (destino por defecto: scripts/qs-helper)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Override de repo/base URL por env var (útil para testing y forks).
REPO="${QS_HELPER_REPO:-Sassech/quickshell}"
BASE_URL="${QS_HELPER_BASE_URL:-https://github.com/${REPO}/releases/latest/download}"
DEST="${1:-$SCRIPT_DIR/qs-helper}"
LOG_FILE="${QS_HELPER_INSTALL_LOG:-/tmp/qs-helper-install.log}"

log() { echo "  $*" | tee -a "$LOG_FILE"; }

# ── Descarga desde GitHub Releases ───────────────────────────────────────────
download_from_release() {
    local asset="qs-helper-linux-amd64"
    local url="${BASE_URL}/${asset}"
    local sums_url="${BASE_URL}/qs-helper-SHA256SUMS.txt"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    log "Descargando ${asset} desde GitHub Releases..."
    if ! curl -fsSL --max-time 60 -o "$tmp/$asset" "$url" 2>>"$LOG_FILE"; then
        log "Falló la descarga desde Releases."
        return 1
    fi

    # Checksum: descarga SHA256SUMS y verifica; si el checksum no está publicado,
    # advierte pero no aborta (la conexión https ya valida la fuente).
    if curl -fsSL --max-time 30 -o "$tmp/SHA256SUMS.txt" "$sums_url" 2>>"$LOG_FILE"; then
        if (cd "$tmp" && sha256sum -c --ignore-missing SHA256SUMS.txt 2>>"$LOG_FILE"); then
            log "Checksum SHA-256 verificado."
        else
            log "ERROR: checksum no coincide. Abortando instalación."
            return 2
        fi
    else
        log "Aviso: no se pudo verificar checksum (SHA256SUMS no disponible)."
    fi

    install -m 0755 "$tmp/$asset" "$DEST/qs-helper"
    log "Instalado en $DEST/qs-helper (linux/amd64)."
    return 0
}

# ── Main ─────────────────────────────────────────────────────────────────────
: > "$LOG_FILE"
echo "qs-helper install — $(date)" >> "$LOG_FILE"

mkdir -p "$DEST"
echo ""

if download_from_release; then
    exit 0
else
    err=$?
    echo "ERROR: no se pudo descargar el binario 'qs-helper-linux-amd64' desde ${REPO}."
    echo "Publica un release 'v*' en GitHub para que 'releases/latest/download' resuelva."
    echo "Revisa el log en ${LOG_FILE}."
    exit "$err"
fi

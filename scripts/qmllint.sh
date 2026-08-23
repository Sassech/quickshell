#!/bin/bash
# qmllint.sh — Lint QML con setup automático del esquema qs:
#
# Quickshell registra `qs:@/` (la raíz de la config) como import path en
# runtime, así que `import qs.Modals.cc` resuelve a Modals/cc/qmldir. qmllint
# no conoce ese esquema y mapea la URI a <importPath>/qs/Modals/cc, que no
# existe. Este wrapper crea (o repara) el import path artificial `.qmllint`
# con un symlink de `qs/Modals/cc` a la carpeta real, y luego lintea con
# `-I`, sin depender del .qmllint.ini.
#
# El árbol se reconstruye en cada invocación: si movés/renombrás Modals/cc,
# el symlink roto se repara solo.
#
# Uso: qmllint.sh [flags y archivos de qmllint]
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

QMLLINT_DIR="$ROOT/.qmllint"
mkdir -p "$QMLLINT_DIR/qs/Modals"
# Target relativo al dir del enlace (.qmllint/qs/Modals/): ../../../ sube a
# la raíz de la config y entra a Modals/cc. El `-n` evita seguir un symlink
# existente (reemplazo directo).
ln -sfn ../../../Modals/cc "$QMLLINT_DIR/qs/Modals/cc"

# Portable .qmllint.ini for IDEs that invoke qmllint without -I (gitignored).
# Wrapper is source of truth via -I; this file is only for direct IDE calls.
# Regenerate if missing or stale (wrong absolute path).
if [[ ! -f "$ROOT/.qmllint.ini" ]] || ! grep -Fq "$ROOT/.qmllint" "$ROOT/.qmllint.ini" 2>/dev/null; then
    printf "[General]\nAdditionalQmlImportPaths=%s/.qmllint\n" "$ROOT" > "$ROOT/.qmllint.ini"
fi

QMLLINT="${QMLLINT:-$(command -v qmllint || echo /usr/lib64/qt6/bin/qmllint)}"
exec "$QMLLINT" -I "$QMLLINT_DIR" "$@"

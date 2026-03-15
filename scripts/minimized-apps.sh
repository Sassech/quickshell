#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# minimized-apps.sh — Lista apps minimizadas en special:minimized con íconos
#
# Salida: class|title|address (una por línea)
# ─────────────────────────────────────────────────────────────────────────────

hyprctl clients -j 2>/dev/null | jq -r '
.[] | 
select(.workspace.name == "special:minimized") | 
"\(.class)|\(.title)|\(.address)"
' 2>/dev/null || echo ""

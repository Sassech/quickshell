#!/usr/bin/env python3
"""
One-time script: replace all hardcoded hex color strings in QML files with
Theme.* references.  Run once after adding Components/Theme.qml.
"""
import re
import os
import glob

BASE = os.path.expanduser("~/.config/quickshell")

# -------------------------------------------------------------------
# Mapping: exact hex string (lower-case) → Theme expression
# Order matters: longer patterns first to avoid partial matches.
# -------------------------------------------------------------------
REPLACEMENTS = [
    # ARGB (8-digit) colours — must come before 6-digit matches
    ("#cc0d0d12",  "Theme.dim"),
    ("#e81e1e2e",  "Theme.cardBg"),
    ("#991e1e2e",  "Theme.cardBg2"),
    ("#14ffffff",  "Theme.hover"),
    ("#33ffffff",  "Theme.hover2"),

    # Ace / accent variants
    ("#2d1f42",    "Theme.accentDim"),
    ("#2e1e3a",    "Theme.accentDim"),
    ("#2a3a5a",    "Theme.accentSurface"),
    ("#1e2a4a",    "Theme.accentSurface"),
    ("#2a2a3e",    "Theme.accentSurface"),
    ("#3d59a1",    "Theme.accent"),
    ("#1c3a2e",    "Theme.successSurface"),
    ("#1e3a2e",    "Theme.successSurface"),
    # amber-tinted surface → nearest neutral
    ("#3a3020",    "Theme.surface3"),

    # Surfaces / backgrounds
    ("#111118",    "Theme.surface1"),
    ("#1a1a28",    "Theme.surface1"),
    ("#252533",    "Theme.surface1"),
    ("#252535",    "Theme.surface1"),
    ("#181825",    "Theme.base"),
    ("#1e1e2a",    "Theme.base"),
    ("#1e1e2e",    "Theme.base"),
    ("#2a2a3a",    "Theme.surface2"),
    ("#2a2a3c",    "Theme.surface2"),
    ("#313244",    "Theme.surface2"),
    ("#45475a",    "Theme.surface3"),

    # Text / muted
    ("#585b70",    "Theme.muted3"),
    ("#6c7086",    "Theme.muted3"),
    ("#7f849c",    "Theme.muted2"),
    ("#a6adc8",    "Theme.muted1"),
    ("#cdd6f4",    "Theme.text"),

    # Accent / primary
    ("#b4befe",    "Theme.accent"),
    ("#89b4fa",    "Theme.accent"),
    ("#cba6f7",    "Theme.accent2"),

    # Semantic
    ("#f38ba8",    "Theme.error"),
    ("#fab387",    "Theme.warning"),
    ("#f9e2af",    "Theme.yellow"),
    ("#a6e3a1",    "Theme.success"),
    ("#89dceb",    "Theme.sky"),
    ("#94e2d5",    "Theme.sky"),
]

IMPORT_LINE = 'import "../Components"'


def patch_file(path):
    with open(path, "r") as f:
        src = f.read()

    original = src

    # 1. Add `import "../Components"` if file is NOT in Components/ and
    #    doesn't already have it.
    if "/Components/" not in path and IMPORT_LINE not in src:
        # Insert right after the last consecutive import line block
        lines = src.split("\n")
        last_import = -1
        for i, line in enumerate(lines):
            if line.strip().startswith("import "):
                last_import = i
        if last_import >= 0:
            lines.insert(last_import + 1, IMPORT_LINE)
            src = "\n".join(lines)

    # 2. Replace hex colour strings (quoted) with Theme.* (unquoted).
    for hex_val, theme_expr in REPLACEMENTS:
        # Match the quoted hex string, case-insensitive
        pattern = re.compile(
            r'"' + re.escape(hex_val) + r'"',
            re.IGNORECASE
        )
        src = pattern.sub(theme_expr, src)

    if src != original:
        with open(path, "w") as f:
            f.write(src)
        print(f"  PATCHED  {os.path.relpath(path, BASE)}")
    else:
        print(f"  no change {os.path.relpath(path, BASE)}")


# -------------------------------------------------------------------
# Run on all QML files except Theme.qml itself
# -------------------------------------------------------------------
qml_files = glob.glob(os.path.join(BASE, "**", "*.qml"), recursive=True)
qml_files = [p for p in qml_files if not p.endswith("Theme.qml")]

print(f"Patching {len(qml_files)} QML files...\n")
for p in sorted(qml_files):
    patch_file(p)
print("\nDone.")

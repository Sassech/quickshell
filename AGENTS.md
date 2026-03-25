# AGENTS.md — Quickshell Desktop Shell Guidelines

Quickshell is a Wayland compositor shell built with QML/Qt, providing a Hyprland-based desktop environment.

**Key Directories:**
- `shell.qml`: Main entry point with global event broadcasting
- `Components/`: Reusable UI elements (Theme.qml, TopBar.qml)
- `Widgets/`: Status bar components (CpuWidget.qml, Battery.qml)
- `Modals/`: Overlay pop-up windows (AudioModal.qml, WeatherModal.qml)
- `scripts/`: Backend scripts (Bash/Python)
- `config/`: JSON configuration files

## Build / Lint / Test Commands

No compilation step; QML changes apply on reload.

### Full Codebase
```bash
# QML syntax validation
find . -name "*.qml" -exec /usr/lib64/qt6/bin/qmllint {} \;
# Python type checking
find scripts -name "*.py" -exec python3 -m mypy {} --ignore-missing-imports \;
# Bash linting
shellcheck scripts/*.sh
# JSON validation
find config -name "*.json" -exec python3 -c "import json,sys; json.load(open('{}'))" {} \;
```

### Single File
```bash
/usr/lib64/qt6/bin/qmllint <path/to/file.qml>
python3 -m mypy <path/to/script.py> --ignore-missing-imports
python3 <path/to/test_script.py>
shellcheck <path/to/script.sh>
python3 -c "import json; json.load(open('<path>'))" && echo "OK"
```

## Code Style Guidelines

### 3.1 QML

**Imports:** System (QtQuick, QtQuick.Layouts) → Quickshell modules → relative local.

**Root Element:** Always `id: root`.

**Section Headers:**
```qml
// ── Section name ───────────────────────────────────────
```

**Property Naming:** `camelCase` public, `_underscorePrefix` private.

**Process Handling:**
```qml
property string _buf: ""
Process {
    stdout: SplitParser { splitMarker: "\n"; onRead: data => root._buf += data }
    onExited: function(code) { ... }
}
```

**Signal/Handler:** `signal clicked()` → `onClicked: root.clicked()`

**Repeater:**
```qml
Rectangle { required property var modelData }
```

**Widget Template:**
```qml
Rectangle {
    id: root
    implicitWidth: 104; implicitHeight: 24; radius: 8; color: Theme.surface2
    signal clicked()
    Row { anchors.centerIn: parent }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
```

**Modal Template:** PanelWindow with `visible: false`, backdrop Rectangle + centered card.

**Animation:** 100-150ms. **Hover:** Theme.hover (8% white), Theme.hover2 (20% white).

### 3.2 Python

```python
#!/usr/bin/env python3
"""Module docstring."""
import os, sys, json, subprocess
def _run_cmd(cmd: list[str], timeout: int = 5) -> tuple[int, str, str]:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0: return (1, "", result.stderr)
    return (0, result.stdout.strip(), "")
```
Return `{}` or `""` on error, not `None`. Logging: f-strings general, `%` format for messages.

### 3.3 Bash

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
readonly CURSOR_FILE="/tmp/qs-cpu-cursor"
```
JSON via inline Python: `printf "%s" "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['key'])"`

## Architecture Patterns

- **Global Broadcasting:** shell.qml signals (broadcastNotify, broadcastCloseAll) caught by modals via Connections filtering by screen.
- **FIFO Pattern:** Hyprland keybinds write to FIFOs; Quickshell Process elements monitor via SplitParser.
- **Per-Screen Instances:** `Variants { model: Quickshell.screens }` creates one modal per screen.

## Key Dependencies

Quickshell, Hyprland, dgop (metrics), cliphist+wl-clipboard, mpDris2 (MPRIS), pactl/wpctl (audio), NetworkManager, bluetoothctl/bluez, curl, Open-Meteo API.

## UI/UX Principles

- Comments/UI text in **Spanish**
- Color scheme: Material You (Matugen) or Catppuccin Mocha via Theme.qml
- Widgets: left accent borders for status; Modals: centered rounded cards with backdrop

## Cursor/Copilot Rules

None found (`.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`).
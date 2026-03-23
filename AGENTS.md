# AGENTS.md — Quickshell Desktop Shell Guidelines for AI Agents

Quickshell is a Wayland compositor shell built with QML/Qt, providing a Hyprland-based desktop environment. This document outlines guidelines for understanding, building, and maintaining the codebase.

## 1. Project Overview

Quickshell integrates QML for its declarative UI, with Bash and Python scripts handling backend logic and system interactions.

**Key Directories:**
- `shell.qml`: Main entry point.
- `Components/`: Reusable UI elements (e.g., `Theme.qml`, `TopBar.qml`).
- `Widgets/`: Status bar components (e.g., `CpuWidget.qml`, `Battery.qml`).
- `Modals/`: Overlay pop-up windows (e.g., `AudioModal.qml`, `WeatherModal.qml`).
- `scripts/`: Backend scripts (Bash for system metrics, Python for data parsing).
- `config/`: JSON configuration files.

## 2. Build / Lint / Test Commands

Quickshell does not have a traditional compilation step; changes to QML files apply on reload.
The project relies on linters and type checkers for code quality.

### Full Codebase Checks

*   **QML Syntax Validation:**
    ```bash
    qmllint Components/Theme.qml # (Replace with specific file or run on all)
    # Install: sudo pacman -S qt6-declarative or qt5-declarative
    ```
*   **Python Type Checking:**
    ```bash
    find scripts -name "*.py" -exec python3 -m mypy {} --ignore-missing-imports \;
    ```
*   **Bash Script Linting:**
    ```bash
    shellcheck scripts/*.sh
    ```
*   **JSON Config Validation:**
    ```bash
    find config -name "*.json" -exec python3 -c "import json,sys; json.load(open('{}'))" {} \; && echo "All JSON valid"
    ```

### Single File / Test Execution

*   **QML Lint a single file:**
    ```bash
    qmllint <path/to/file.qml>
    ```
*   **Python Type Check a single file:**
    ```bash
    python3 -m mypy <path/to/script.py> --ignore-missing-imports
    ```
*   **Run a Python test script (if applicable):**
    ```bash
    python3 <path/to/test_script.py> # e.g., python3 scripts/lyricsgenius/test.py
    ```
*   **Bash Lint a single file:**
    ```bash
    shellcheck <path/to/script.sh>
    ```
*   **Validate a single JSON config:**
    ```bash
    python3 -c "import json; json.load(open('<path/to/config.json>'))" && echo "OK"
    ```

## 3. Code Style Guidelines

### 3.1 QML

*   **Imports:** Order system imports first (e.g., `QtQuick`, `QtQuick.Layouts`), then Quickshell-specific modules (e.g., `Quickshell`, `Quickshell.Io`), followed by relative local imports (`"../Components"`).
*   **Root Element:** Always use `id: root` for the root element of any QML file.
*   **Property Naming:** `camelCase` for public API properties, `_underscorePrefix` for private properties. Use `property alias` to expose child properties.
*   **Section Headers:** Use `// ── Section name ───────────────────────────────────────` for clear code organization.
*   **Signals:** Declare signals (e.g., `signal clicked()`) and use `onClicked: { /* handler */ }` for handlers.
*   **Repeater Delegates:** Use `required property var modelData` for model data in delegates.
*   **Functions:** Prefer arrow functions (`data => root._buf += data`) over the `function` keyword for concise handlers.
*   **Error Handling (Process):** Handle `Process` exit codes in `onExited: function(code)` and `SplitParser` errors or unexpected output in `onRead` handlers.
*   **Comments & UI Text:** Primarily in **Spanish**.

### 3.2 Python

*   **Shebang:** Start scripts with `#!/usr/bin/env python3`.
*   **Docstrings:** Include a module docstring at the beginning of each file.
*   **Imports:** Group standard library imports, then third-party, then local application imports. Alphabetize within each group.
*   **Type Hints:** Use type hints for function arguments and return values (e.g., `def log(msg: str) -> None:`).
*   **Naming Conventions:** Use `snake_case` for function and variable names, `PascalCase` for class names.
*   **Subprocess:** Use `subprocess.run` with `capture_output=True`, `text=True`, and `timeout=N`. Always check `result.returncode != 0` for errors. Handle `subprocess.TimeoutExpired` explicitly.
*   **Error Handling:** Implement `try...except` blocks for robust error handling. Return `""` (empty string) from helper functions on error, rather than `None`.
*   **Logging:** Use `f-strings` for general formatting, and `%`-format for log messages (as shown in the `log` helper).

### 3.3 Bash

*   **Strict Mode:** Always include `set -euo pipefail` at the beginning of scripts for robust error handling.
*   **Script Directory:** Use `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` for reliable relative pathing.
*   **Variable Naming:** Use `UPPER_SNAKE_CASE` for global constants and `snake_case` for local variables.
*   **JSON Processing:** Use inline Python (`| python3 -c "import json,sys; d=json.load(sys.stdin); print(d['key'])"`) for parsing JSON output from commands.

## 4. Architecture Highlights

*   **Global Event Broadcasting:** `shell.qml` broadcasts signals (`broadcastNotify`, `broadcastCloseAll`) that modals listen to via `Connections` to filter events by screen.
*   **FIFO Pattern:** Hyprland keybinds write to FIFOs (e.g., `/tmp/qs-clipboard`), which Quickshell `Process` elements monitor to trigger actions.

## 5. Key Dependencies

*   **Quickshell** (core module), **Hyprland** (Wayland compositor), **dgop** (system metrics), **cliphist** + **wl-clipboard** (clipboard), **mpDris2** (MPRIS2 bridge), **geoclue2** + **BeaconDB** (geolocation), **pactl/wpctl** (audio), **NetworkManager** (wifi), **bluetoothctl/bluez** (bluetooth), **curl** (HTTP), **Open-Meteo API** (weather).

## 6. UI/UX Principles

*   Comments and UI text are in **Spanish**.
*   Color scheme uses Material You (Matugen) or Catppuccin Mocha.
*   Widgets use left accent borders for status indication.
*   Modals are centered, rounded cards with subtle borders and backdrop overlays.
*   Hover states use `Theme.hover` (8% white) and `Theme.hover2` (20% white).
*   Animation durations are typically 100-150ms for UI transitions.

## 7. Cursor/Copilot Rules

No explicit Cursor rules (`.cursor/rules/`, `.cursorrules`) or Copilot rules (`.github/copilot-instructions.md`) were found in this repository.

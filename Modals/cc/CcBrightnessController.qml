// Controlador de brillo — lee y aplica brillo vía brightnessctl
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // ── Estado público ────────────────────────────────────────────────────
    property int  brightness:       50
    property bool _brightnessReady: false

    // ── Buffer interno de lectura ─────────────────────────────────────────
    property string _buf: ""

    // ── Leer brillo actual ────────────────────────────────────────────────
    property var _getBrightnessProc: Process {
        id: getBrightnessProc
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._buf += d }
        // qmllint disable signal-handler-parameters
        onExited: {
            var v = parseInt(root._buf.trim())
            root._buf = ""
            if (!isNaN(v)) { root.brightness = v; root._brightnessReady = true }
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Aplicar brillo ────────────────────────────────────────────────────
    property var _setBrightnessProc: Process {
        id: setBrightnessProc
        property int targetPct: 50
        command: ["bash", "-c", "brightnessctl set " + targetPct + "% 2>/dev/null"]
    }

    // ── API pública ───────────────────────────────────────────────────────
    function refresh() {
        root._buf = ""
        getBrightnessProc.running = true
    }

    function setBrightness(pct) {
        root.brightness = pct
        setBrightnessProc.targetPct = pct
        if (!setBrightnessProc.running) setBrightnessProc.running = true
    }
}

// qmllint disable uncreatable-type
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Components"

// ─────────────────────────────────────────────────────────────────────────────
// VolumeOsd — OSD de volumen. Hereda OsdBase (ciclo de vida + layout) y bindea
// su contenido: icono por mute/umbrales, label Mudo/%, barra sobre max=150
// (admite boost >100%) con marcador de 100%. La lectura del sink es la única
// lógica propia: Pipewire reactivo + fallback wpctl.
// ─────────────────────────────────────────────────────────────────────────────
OsdBase {
    id: root

    cardWidth:       292
    max:             150
    labelWidth:      46
    showHundredTick: true

    // ── Contenido parametrizado (reactivo al estado del sink) ─────────────
    value:      _volumePct
    icon:       IconHelpers.volIcon(root._volumePct / 100, root._muted)
    label:      root._muted ? "Mudo" : root._volumePct + "%"
    barColor:   root._muted ? Theme.muted2 : Theme.accent
    iconColor:  root._muted ? Theme.muted2 : Theme.accent
    labelColor: root._muted ? Theme.muted2 : Theme.text

    // ── Estado interno ─────────────────────────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    property int    _volumePct: 0
    property bool   _muted: false
    property string _buf: ""

    // ── Bind the sink node — REQUIRED for .audio.volume/.muted to be valid ──
    PwObjectTracker {
        objects: [root.sink]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() {
            const v = root.sink?.audio?.volume
            if (v !== undefined && v !== null && !isNaN(v)) root._volumePct = Math.round(v * 100)
        }
        function onMutedChanged() {
            const m = root.sink?.audio?.muted
            if (m !== undefined && m !== null) root._muted = m
        }
    }

    // ── Refresh on sink switch (node may not be bound yet) ──────────────
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (!readVolProc.running) {
                root._buf = ""
                readVolProc.running = true
            }
        }
    }

    Process {
        id: readVolProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._buf += d }
        // qmllint disable signal-handler-parameters
        onExited: {
            const s = root._buf.trim()
            root._buf = ""
            const m = s.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (m) {
                const v = parseFloat(m[1])
                if (!isNaN(v)) root._volumePct = Math.round(v * 100)
                root._muted = !!m[2]
            }
        }
        // qmllint enable signal-handler-parameters
    }

    function show() {
        if (!readVolProc.running) {
            root._buf = ""
            readVolProc.running = true
        }
        root.showCard()
    }
}

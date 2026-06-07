import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Components"

Rectangle {
    id: root
    signal clicked()

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 26
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    Behavior on color { ColorAnimation { duration: 100 } }

    readonly property var sink: Pipewire.defaultAudioSink
    property real volume: 0.75
    property bool muted: false

    // ── Bind the sink node — REQUIRED for .audio.volume/.muted to be valid ──
    PwObjectTracker {
        objects: [root.sink]
    }

    // ── Sync from PipeWire (instant, event-driven) ──────────────────────
    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() {
            const v = root.sink?.audio?.volume
            if (v !== undefined && v !== null && !isNaN(v)) root.volume = v
        }
        function onMutedChanged() {
            const m = root.sink?.audio?.muted
            if (m !== undefined && m !== null) root.muted = m
        }
    }

    // ── Refresh on default sink change ──────────────────────────────────
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (!wpctlRefresh.running) {
                root._buf = ""
                wpctlRefresh.running = true
            }
        }
    }

    // ── wpctl fallback: read at startup + on sink change ────────────────
    property string _buf: ""
    Process {
        id: wpctlRefresh
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._buf += d }
        // qmllint disable signal-handler-parameters
        onExited: {
            const m = root._buf.trim().match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            root._buf = ""
            if (m) {
                const v = parseFloat(m[1])
                if (!isNaN(v)) root.volume = v
                root.muted = !!m[2]
            }
        }
        // qmllint enable signal-handler-parameters
    }

    function volIcon() {
        if (muted || volume === 0) return "󰝟"
        if (volume < 0.33) return "󰕿"
        if (volume < 0.67) return "󰖀"
        return "󰕾"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.volIcon()
            font.pixelSize: 13
            color: root.muted ? Theme.muted2 : Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.muted ? "Mudo" : Math.round(root.volume * 100) + "%"
            font.pixelSize: 11
            color: root.muted ? Theme.muted2 : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

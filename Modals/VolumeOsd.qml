import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode:  ExclusionMode.Ignore

    anchors.bottom: true
    implicitWidth:  296
    implicitHeight: 60
    margins.bottom: 48

    mask: Region { item: osdCard }

    // ── State ─────────────────────────────────────────────────────────────
    readonly property var sink:   Pipewire.defaultAudioSink
    property int  volumePct: 0
    property bool muted: false
    property string _buf: ""

    // ── Bind the sink node — REQUIRED for .audio.volume/.muted to be valid ──
    PwObjectTracker {
        objects: [root.sink]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() {
            const v = root.sink?.audio?.volume
            if (v !== undefined && v !== null && !isNaN(v)) root.volumePct = Math.round(v * 100)
        }
        function onMutedChanged() {
            const m = root.sink?.audio?.muted
            if (m !== undefined && m !== null) root.muted = m
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
                if (!isNaN(v)) root.volumePct = Math.round(v * 100)
                root.muted = !!m[2]
            }
        }
        // qmllint enable signal-handler-parameters
    }

    function show() {
        if (!readVolProc.running) {
            root._buf = ""
            readVolProc.running = true
        }
        if (!root.visible) {
            root.visible    = true
            osdCard.opacity = 1
            osdCard.yOffset = 60
            slideAnim.restart()
        }
        dismissTimer.restart()
    }

    // ── Timers & Animations ────────────────────────────────────────────────
    Timer {
        id: dismissTimer
        interval: 2500
        onTriggered: dismissFade.restart()
    }

    NumberAnimation {
        id: slideAnim
        target: osdCard; property: "yOffset"
        from: 60; to: 0
        duration: 200; easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: dismissFade
        target: osdCard; property: "opacity"
        from: 1; to: 0
        duration: 200; easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── OSD Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: yOffset
        width: 292; height: 52; radius: 13
        color: Theme.cardBg3

        property real yOffset: 0

        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12

            // Volume icon
            Text {
                text: root.muted || root.volumePct === 0 ? "󰝟"
                    : root.volumePct < 33               ? "󰕿"
                    : root.volumePct < 67               ? "󰖀"
                    : "󰕾"
                font.pixelSize: 18
                color: root.muted ? Theme.muted2 : Theme.accent
            }

            // Progress bar + 100% marker
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 6

                Rectangle {
                    id: track
                    anchors.fill: parent; radius: 3
                    color: Theme.surface3

                    // Filled part
                    Rectangle {
                        width: (Math.min(150, Math.max(0, root.volumePct)) / 150) * track.width
                        height: track.height; radius: track.radius
                        color: root.muted ? Theme.muted2 : Theme.accent
                        Behavior on width  { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 120 } }
                    }

                    // 100% marker tick
                    Rectangle {
                        x: (100 / 150) * track.width - 1
                        height: 10; width: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                        radius: 1
                    }
                }
            }

            // Label
            Text {
                text: root.muted ? "Mudo" : root.volumePct + "%"
                font.pixelSize: 13; font.weight: Font.Normal
                color: root.muted ? Theme.muted2 : Theme.text
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}

import QtQuick
import Quickshell.Services.Pipewire
import "../Components"

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 26
    radius: 8
    color: Theme.surface2

    Behavior on color { ColorAnimation { duration: 100 } }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: root.sink?.audio?.volume ?? 0.75
    readonly property bool muted:  root.sink?.audio?.muted  ?? false

    // ── Bind the sink node — REQUIRED for .audio.volume/.muted to be valid ──
    PwObjectTracker {
        objects: [root.sink]
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


}

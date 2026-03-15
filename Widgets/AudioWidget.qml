import QtQuick
import Quickshell.Io
import "../Components"

Item {
    id: root
    signal clicked()

    implicitWidth:  pill.width
    implicitHeight: 26

    property real   volume: 0.75
    property bool   muted:  false
    property string _buf:   ""

    function volIcon() {
        if (muted || volume === 0) return "󰝟"
        if (volume < 0.33) return "󰕿"
        if (volume < 0.67) return "󰖀"
        return "󰕾"
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    Process {
        id: pollProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._buf += d }
        onExited: {
            var s = root._buf.trim()
            root._buf = ""
            var m = s.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (m) {
                root.volume = parseFloat(m[1])
                root.muted  = !!m[2]
            }
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width:  pillRow.implicitWidth + 16
        height: 26; radius: 8
        color: pillMA.containsMouse ? Theme.surface3 : Theme.surface2
        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
            id: pillRow
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
            id: pillMA
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}

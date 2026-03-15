import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: 104
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()
    property int ramPercent: 0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0
    property real ramAvailGb: 0.0
    property int swapPercent: 0

    property color accentColor: {
        if (ramPercent >= 90) return Theme.error   // rojo - crítico
        if (ramPercent >= 75) return Theme.warning   // naranja - alto
        if (ramPercent >= 60) return Theme.yellow   // amarillo - medio
        return Theme.accent                          // azul - normal
    }

    // Left accent border
    Rectangle {
        width: 3; height: parent.height * 0.6
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: 4
        color: root.accentColor
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.ramPercent + "%"
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 34
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.ramUsedGb.toFixed(1) + "G"
            font.pixelSize: 10
            color: Theme.muted1
            width: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        interval: 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: ramProc.running = true
    }

    property string _buf: ""
    Process {
        id: ramProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/ram-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            if (lines.length >= 1) { var p = parseInt(lines[0]); if (!isNaN(p)) root.ramPercent = p }
            if (lines.length >= 2) { var u = parseFloat(lines[1]); if (!isNaN(u)) root.ramUsedGb = u }
            if (lines.length >= 3) { var t = parseFloat(lines[2]); if (!isNaN(t)) root.ramTotalGb = t }
            if (lines.length >= 4) { var a = parseFloat(lines[3]); if (!isNaN(a)) root.ramAvailGb = a }
            if (lines.length >= 5) { var s = parseInt(lines[4]); if (!isNaN(s)) root.swapPercent = s }
            root._buf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

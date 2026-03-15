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
    property int cpuPercent: 0
    property int cpuTemp: 0

    property color accentColor: {
        if (cpuTemp >= 85) return Theme.error   // rojo
        if (cpuTemp >= 70) return Theme.warning   // naranja
        if (cpuTemp >= 55) return Theme.yellow   // amarillo
        return Theme.accent                       // azul
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
            text: "󰻠"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.cpuPercent + "%"
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 34
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.cpuTemp + "°"
            font.pixelSize: 10
            color: Theme.muted1
            width: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        interval: 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }

    property string _buf: ""
    Process {
        id: cpuProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/cpu-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            if (lines.length >= 1) { var p = parseInt(lines[0]); if (!isNaN(p)) root.cpuPercent = p }
            if (lines.length >= 2) { var t = parseInt(lines[1]); if (!isNaN(t)) root.cpuTemp = t }
            root._buf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

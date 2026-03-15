import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: 96
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()
    property int gpuPercent: -1
    property int gpuTemp: 0
    property string gpuName: ""

    property bool hasData: gpuPercent >= 0

    property color accentColor: {
        if (!hasData) return Theme.muted3
        if (gpuTemp >= 85) return Theme.error
        if (gpuTemp >= 70) return Theme.warning
        return Theme.accent2
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
            text: "󰍹"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasData ? root.gpuPercent + "%" : "N/A"
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: root.hasData ? Theme.text : Theme.muted3
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            visible: root.hasData && root.gpuTemp > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.gpuTemp + "°"
            font.pixelSize: 10
            color: Theme.muted1
            width: 28
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        interval: 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: gpuProc.running = true
    }

    property string _buf: ""
    Process {
        id: gpuProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/gpu-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            if (lines.length >= 1) { var p = parseInt(lines[0]); root.gpuPercent = isNaN(p) ? -1 : p }
            if (lines.length >= 2) { var t = parseInt(lines[1]); if (!isNaN(t)) root.gpuTemp = t }
            if (lines.length >= 3) root.gpuName = lines[2].trim()
            root._buf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

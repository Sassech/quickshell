import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: 118
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()
    property int diskUsedGb: 0
    property int diskAvailGb: 0
    property int diskPercent: 0

    property color accentColor: {
        if (diskPercent >= 90) return Theme.error
        if (diskPercent >= 75) return Theme.warning
        return Theme.success
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
            text: "󰋊"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.diskPercent + "%"
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.diskAvailGb + "G libre"
            font.pixelSize: 10
            color: Theme.muted1
            width: 54
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        interval: 60000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    property string _buf: ""
    Process {
        id: diskProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/disk-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            if (lines.length >= 1) { var u = parseInt(lines[0]); if (!isNaN(u)) root.diskUsedGb = u }
            if (lines.length >= 2) { var a = parseInt(lines[1]); if (!isNaN(a)) root.diskAvailGb = a }
            if (lines.length >= 3) { var p = parseInt(lines[2]); if (!isNaN(p)) root.diskPercent = p }
            root._buf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

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
    property int _failCount: 0

    property bool hasData: gpuPercent >= 0

    property color accentColor: {
        if (!hasData) return Theme.muted3
        if (gpuTemp >= 85) return Theme.error
        if (gpuTemp >= 70) return Theme.warning
        return Theme.accent2
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍹"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasData ? root.gpuPercent + "%" : "—%"
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
        id: pollTimer
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: gpuProc.running = true
    }

    Timer {
        id: backoffTimer
        interval: 300000
        onTriggered: {
            root._failCount = 0
            pollTimer.start()
        }
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
            var ok = false
            var p = root.gpuPercent
            var t = root.gpuTemp
            var n = root.gpuName
            if (lines.length >= 1) {
                var p0 = parseInt(lines[0])
                if (!isNaN(p0) && p0 >= 0) { p = p0; ok = true }
            }
            if (lines.length >= 2) { var t0 = parseInt(lines[1]); if (!isNaN(t0)) t = t0 }
            if (lines.length >= 3) n = lines[2].trim()

            if (ok) {
                if (p !== root.gpuPercent) root.gpuPercent = p
                if (t !== root.gpuTemp) root.gpuTemp = t
                if (n !== root.gpuName) root.gpuName = n
                root._failCount = 0
            } else {
                root.gpuPercent = -1
                root._failCount++
                if (root._failCount >= 3) {
                    pollTimer.stop()
                    backoffTimer.restart()
                }
            }
            root._buf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

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
    property bool dataAvailable: false
    property int _failCount: 0
    property bool _hasSuccessfulRead: false

    property color accentColor: {
        if (!dataAvailable) return Theme.muted2
        if (cpuTemp >= 85) return Theme.error   // rojo
        if (cpuTemp >= 70) return Theme.warning   // naranja
        if (cpuTemp >= 55) return Theme.yellow   // amarillo
        return Theme.accent                       // azul
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰻠"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dataAvailable ? (root.cpuPercent + "%") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: root.dataAvailable ? Theme.text : Theme.muted3
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            visible: root.dataAvailable && root.cpuTemp > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.cpuTemp + "°"
            font.pixelSize: 10
            color: Theme.muted1
            width: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        id: pollTimer
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
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
        id: cpuProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/cpu-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            var ok = false
            var p = root.cpuPercent
            var t = root.cpuTemp
            if (lines.length >= 1) {
                var p0 = parseInt(lines[0])
                if (!isNaN(p0)) { p = p0; ok = true }
            }
            if (lines.length >= 2) { var t0 = parseInt(lines[1]); if (!isNaN(t0)) t = t0 }

            if (ok) {
                if (!root.dataAvailable || p !== root.cpuPercent) root.cpuPercent = p
                if (t !== root.cpuTemp) root.cpuTemp = t
                root.dataAvailable = true
                root._hasSuccessfulRead = true
                root._failCount = 0
            } else {
                root._failCount++
                if (!root._hasSuccessfulRead) {
                    root.dataAvailable = false
                }
                if (!root._hasSuccessfulRead && root._failCount >= 3) {
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

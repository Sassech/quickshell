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
    property bool dataAvailable: false
    property int _failCount: 0
    property bool _hasSuccessfulRead: false
    property string _scriptsPath: Qt.resolvedUrl("../scripts").toString().replace("file://", "")

    property color accentColor: {
        if (!dataAvailable) return Theme.muted2
        if (diskPercent >= 90) return Theme.error
        if (diskPercent >= 75) return Theme.warning
        return Theme.success
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰋊"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dataAvailable ? (root.diskPercent + "%") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dataAvailable ? (root.diskAvailGb + "GB libre") : ""
            font.pixelSize: 10
            color: Theme.muted1
            width: 62
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        id: pollTimer
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
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
        id: diskProc
        command: ["bash", root._scriptsPath + "/disk-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            var ok = false
            var u = root.diskUsedGb
            var a = root.diskAvailGb
            var p = root.diskPercent
            if (lines.length >= 1) { var u0 = parseInt(lines[0]); if (!isNaN(u0)) u = u0 }
            if (lines.length >= 2) { var a0 = parseInt(lines[1]); if (!isNaN(a0)) a = a0 }
            if (lines.length >= 3) {
                var p0 = parseInt(lines[2])
                if (!isNaN(p0)) { p = p0; ok = true }
            }

            if (ok) {
                if (!root.dataAvailable || u !== root.diskUsedGb || a !== root.diskAvailGb || p !== root.diskPercent) {
                    root.diskUsedGb = u
                    root.diskAvailGb = a
                    root.diskPercent = p
                }
                root.dataAvailable = true
                root._hasSuccessfulRead = true
                root._failCount = 0
            } else {
                root._failCount++
                if (!root._hasSuccessfulRead && root._failCount >= 3) {
                    pollTimer.stop()
                    backoffTimer.restart()
                }
                if (!root._hasSuccessfulRead) {
                    root.dataAvailable = false
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

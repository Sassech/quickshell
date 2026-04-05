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
    property bool dataAvailable: false
    property int _failCount: 0
    property bool _hasSuccessfulRead: false
    property string _scriptsPath: Qt.resolvedUrl("../scripts").toString().replace("file://", "")

    property color accentColor: {
        if (!dataAvailable) return Theme.muted2
        if (ramPercent >= 90) return Theme.error   // rojo - crítico
        if (ramPercent >= 75) return Theme.warning   // naranja - alto
        if (ramPercent >= 60) return Theme.yellow   // amarillo - medio
        return Theme.accent                          // azul - normal
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰘚"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dataAvailable ? (root.ramPercent + "%") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: root.dataAvailable ? Theme.text : Theme.muted3
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dataAvailable ? (root.ramUsedGb.toFixed(1) + "GB") : ""
            font.pixelSize: 10
            color: Theme.muted1
            width: 34
            horizontalAlignment: Text.AlignRight
        }
    }

    Timer {
        id: pollTimer
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ramProc.running = true
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
        id: ramProc
        command: ["bash", root._scriptsPath + "/ram-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            var ok = false
            var p = root.ramPercent
            var u = root.ramUsedGb
            var t = root.ramTotalGb
            var a = root.ramAvailGb
            var s = root.swapPercent

            if (lines.length >= 1) {
                var p0 = parseInt(lines[0])
                if (!isNaN(p0)) { p = p0; ok = true }
            }
            if (lines.length >= 2) { var u0 = parseFloat(lines[1]); if (!isNaN(u0)) u = u0 }
            if (lines.length >= 3) { var t0 = parseFloat(lines[2]); if (!isNaN(t0)) t = t0 }
            if (lines.length >= 4) { var a0 = parseFloat(lines[3]); if (!isNaN(a0)) a = a0 }
            if (lines.length >= 5) { var s0 = parseInt(lines[4]); if (!isNaN(s0)) s = s0 }

            if (ok) {
                if (!root.dataAvailable || p !== root.ramPercent) root.ramPercent = p
                if (u !== root.ramUsedGb) root.ramUsedGb = u
                if (t !== root.ramTotalGb) root.ramTotalGb = t
                if (a !== root.ramAvailGb) root.ramAvailGb = a
                if (s !== root.swapPercent) root.swapPercent = s
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

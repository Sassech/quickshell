import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: 104
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    // Fan properties
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan1Percent: 0
    property int fan2Percent: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property string fanProfile: ""
    property bool fanAvailable: true
    property string _scriptsPath: Qt.resolvedUrl("../scripts").toString().replace("file://", "")

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰈐"
            font.pixelSize: 13
            color: root.fanAvailable ? Theme.accent : Theme.muted2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.fanAvailable ? (root.fan1Rpm + "") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: root.fanAvailable ? Theme.text : Theme.muted3
            width: 34
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.fanAvailable ? (root.cpuTemp + "°") : ""
            font.pixelSize: 10
            font.family: "monospace"
            color: Theme.muted1
            width: 24
            horizontalAlignment: Text.AlignRight
        }
    }

    // Polling timer (every 30s)
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fanRpmProc.running = true
            fanPercentProc.running = true
            tempProc.running = true
            profileProc.running = true
        }
    }

    // Read fan RPM
    property string _fanRpmBuf: ""
    Process {
        id: fanRpmProc
        command: [root._scriptsPath + "/fan-control.sh", "get_rpm"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._fanRpmBuf += data
        }
        onExited: {
            var parts = root._fanRpmBuf.trim().split(",")
            if (parts.length >= 2) {
                root.fan1Rpm = parseInt(parts[0]) || 0
                root.fan2Rpm = parseInt(parts[1]) || 0
                root.fanAvailable = root.fan1Rpm > 0 || root.fan2Rpm > 0
            }
            root._fanRpmBuf = ""
        }
    }

    // Read fan percent
    property string _fanPercentBuf: ""
    Process {
        id: fanPercentProc
        command: [root._scriptsPath + "/fan-control.sh", "get_percent"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._fanPercentBuf += data
        }
        onExited: {
            var parts = root._fanPercentBuf.trim().split(",")
            if (parts.length >= 2) {
                root.fan1Percent = parseInt(parts[0]) || 0
                root.fan2Percent = parseInt(parts[1]) || 0
            }
            root._fanPercentBuf = ""
        }
    }

    // Read temperature
    property string _tempBuf: ""
    Process {
        id: tempProc
        command: [root._scriptsPath + "/fan-control.sh", "get_temp"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._tempBuf += data
        }
        onExited: {
            var parts = root._tempBuf.trim().split(",")
            if (parts.length >= 2) {
                root.cpuTemp = parseInt(parts[0]) || 0
                root.gpuTemp = parseInt(parts[1]) || 0
            }
            root._tempBuf = ""
        }
    }

    // Read profile
    property string _profileBuf: ""
    Process {
        id: profileProc
        command: [root._scriptsPath + "/fan-control.sh", "get_profile"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._profileBuf += data
        }
        onExited: {
            root.fanProfile = root._profileBuf.trim()
            root._profileBuf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

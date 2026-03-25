import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    property int batteryLevel: 0
    property string batteryStatus: "Unknown"
    property bool isCharging: false
    property bool batteryAvailable: true
    property string batteryPath: ""

    // Fan properties
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan1Percent: 0
    property int fan2Percent: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property string fanProfile: ""
    property bool fanAvailable: true

    property color levelColor: {
        if (!batteryAvailable) return Theme.muted2
        if (isCharging) return Theme.success
        if (batteryLevel > 50) return Theme.accent
        if (batteryLevel > 20) return Theme.yellow
        return Theme.error
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // Battery icon
        Item {
            width: 18
            height: 12
            anchors.verticalCenter: parent.verticalCenter

            // Battery body
            Rectangle {
                id: battBody
                x: 0
                y: 1
                width: 15
                height: 10
                radius: 2
                color: "transparent"
                border.color: root.levelColor
                border.width: 1.5

                // Fill
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.max(2, (parent.width - 4) * root.batteryLevel / 100)
                    radius: 1
                    color: root.levelColor
                }
            }
            // Battery terminal
            Rectangle {
                x: battBody.width + 1
                y: 3.5
                width: 2
                height: 5
                radius: 1
                color: root.levelColor
            }
            // Charging bolt
            Text {
                visible: root.isCharging
                anchors.centerIn: battBody
                text: "⚡"
                font.pixelSize: 7
                color: Theme.base
            }
        }

        // Fan indicator (small)
        Text {
            visible: root.fanAvailable
            anchors.verticalCenter: parent.verticalCenter
            text: "🌀"
            font.pixelSize: 9
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batteryAvailable ? (root.batteryLevel + "%") : "—%"
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
        }
    }

    // Polling timer
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.batteryPath) {
                detectProc.running = true
            } else {
                capacityProc.running = true
                statusProc.running = true
            }
        }
    }

    // Detect battery path
    property string _detectBuf: ""
    Process {
        id: detectProc
        command: ["sh", "-c",
            "ls -1 /sys/class/power_supply 2>/dev/null | grep '^BAT' | head -1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._detectBuf += data
        }
        onExited: {
            var v = root._detectBuf.trim()
            root._detectBuf = ""
            if (v) {
                root.batteryPath = "/sys/class/power_supply/" + v
                root.batteryAvailable = true
                capacityProc.running = true
                statusProc.running = true
            } else {
                root.batteryPath = ""
                root.batteryAvailable = false
            }
        }
    }

    // Read capacity
    property string _capBuf: ""
    Process {
        id: capacityProc
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/capacity\" 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._capBuf += data
        }
        onExited: {
            var v = parseInt(root._capBuf.trim())
            if (!isNaN(v)) root.batteryLevel = v
            root._capBuf = ""
        }
    }

    // Read status
    property string _statusBuf: ""
    Process {
        id: statusProc
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/status\" 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._statusBuf += data
        }
        onExited: {
            var s = root._statusBuf.trim()
            root.batteryStatus = s
            root.isCharging = (s === "Charging")
            root._statusBuf = ""
        }
    }

    // Read fan RPM
    property string _fanRpmBuf: ""
    Process {
        id: fanRpmProc
        command: ["/home/sassech/.config/quickshell/scripts/fan-control.sh", "get_rpm"]
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
        command: ["/home/sassech/.config/quickshell/scripts/fan-control.sh", "get_percent"]
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
        command: ["/home/sassech/.config/quickshell/scripts/fan-control.sh", "get_temp"]
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
        command: ["/home/sassech/.config/quickshell/scripts/fan-control.sh", "get_profile"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._profileBuf += data
        }
        onExited: {
            root.fanProfile = root._profileBuf.trim()
            root._profileBuf = ""
        }
    }

    // Fan polling timer (every 30s when widget visible)
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

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

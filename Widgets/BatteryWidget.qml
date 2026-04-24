import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: 70
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    // ── Properties ───────────────────────────────────────────
    property int batteryLevel: 0
    property string batteryStatus: "Unknown"
    property bool isCharging: false
    property bool batteryAvailable: true
    property string batteryPath: ""
    property string stateIcon: {
        if (!root.batteryAvailable) return ""
        if (root.batteryStatus === "Charging") return "󰂄"
        if (root.batteryStatus === "Discharging") return "󰂃"
        if (root.batteryStatus === "Full") return "󰁹"
        if (root.batteryStatus === "Not charging") return "󰂂"
        return "󰂑"
    }

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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.stateIcon
            font.pixelSize: 13
            color: root.levelColor
            visible: root.batteryAvailable
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batteryLevel + "%"
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 32
            horizontalAlignment: Text.AlignRight
            visible: root.batteryAvailable
        }

        Item { width: 0; height: 1 }
    }

    // ── Polling timer (every 30s) ─────────────────────────────
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

    // ── Detect battery path ──────────────────────────────────
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

    // ── Read capacity ────────────────────────────────────────
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

    // ── Read status ──────────────────────────────────────────
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

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

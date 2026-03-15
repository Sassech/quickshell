import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth:  rowContent.implicitWidth + 24
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    // ── State ────────────────────────────────────────────────────────────
    property real downSpeed: 0   // bytes/s
    property real upSpeed:   0   // bytes/s

    property real _prevRx: -1
    property real _prevTx: -1

    // ── Helpers ──────────────────────────────────────────────────────────
    function fmt(bps) {
        if (bps < 1024)            return Math.round(bps)       + " B/s"
        if (bps < 1024 * 1024)     return (bps / 1024).toFixed(1)        + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / (1024*1024)).toFixed(1) + " MB/s"
        return (bps / (1024*1024*1024)).toFixed(2) + " GB/s"
    }

    // Left accent strip
    Rectangle {
        width: 3; height: parent.height * 0.6
        radius: 2
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 4 }
        color: Theme.accent
    }

    Row {
        id: rowContent
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 6

        // Network icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰈀"
            font.pixelSize: 13
            color: Theme.accent
        }

        // Down
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "↓"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.success
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.fmt(root.downSpeed)
                font.pixelSize: 11
                font.weight: Font.Normal
                font.family: "monospace"
                color: Theme.text
                width: 68
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Up
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "↑"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.fmt(root.upSpeed)
                font.pixelSize: 11
                font.weight: Font.Normal
                font.family: "monospace"
                color: Theme.text
                width: 68
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Poll every 2 seconds ─────────────────────────────────────────────────
    Timer {
        interval: 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    property string _buf: ""
    Process {
        id: netProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/net-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => root._buf += d
        }
        onExited: {
            var parts = root._buf.trim().split(/\s+/)
            root._buf = ""
            if (parts.length < 2) return
            var rx = parseFloat(parts[0])
            var tx = parseFloat(parts[1])
            if (root._prevRx >= 0) {
                root.downSpeed = Math.max(0, rx - root._prevRx)
                root.upSpeed   = Math.max(0, tx - root._prevTx)
            }
            root._prevRx = rx
            root._prevTx = tx
        }
    }
}

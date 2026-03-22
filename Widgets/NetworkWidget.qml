import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 24
    radius: 8
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2

    // ── State ────────────────────────────────────────────────────────────
    property bool   radioOn:        true
    property bool   connected:     false
    property string connectionType: "none"  // "wifi", "ethernet", "none"
    property string ssid:          ""
    property int    signal_:       0   // 0-100
    property real   downSpeed:     0   // bytes/s
    property real   upSpeed:       0   // bytes/s
    property real   _prevRx:       -1
    property real   _prevTx:       -1

    // ── Icon based on connection type ────────────────────────────────────
    property string networkIcon: {
        if (connectionType === "ethernet") return "󰈀"
        if (!radioOn) return "󰤮"
        if (!connected) return "󰤭"
        if (signal_ >= 80) return "󰤨"
        if (signal_ >= 60) return "󰤥"
        if (signal_ >= 40) return "󰤢"
        return "󰤟"
    }

    property color iconColor: {
        if (connectionType === "ethernet") return Theme.success
        if (!radioOn) return Theme.muted1
        if (!connected) return Theme.muted2
        if (signal_ >= 60) return Theme.success
        if (signal_ >= 40) return Theme.warning
        return Theme.error
    }

    // ── Speed formatting ──────────────────────────────────────────────────
    function fmtSpeed(bps) {
        if (bps < 1024)            return Math.round(bps) + " B/s"
        if (bps < 1024 * 1024)     return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / (1024*1024)).toFixed(1) + " MB/s"
        return (bps / (1024*1024*1024)).toFixed(2) + " GB/s"
    }

    // ── Content Row ──────────────────────────────────────────────────────
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        // Network icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.networkIcon
            font.pixelSize: 13
            color: root.iconColor
        }

        // Connection text
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (connectionType === "ethernet") return "Ethernet"
                if (!radioOn) return "Apagado"
                if (!connected) return "Desc."
                return root.ssid || "WiFi"
            }
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
            elide: Text.ElideRight
            maximumLineCount: 1
            width: 90
        }

        // Download speed
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connected

            Text {
                text: "↓"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.success
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: fmtSpeed(root.downSpeed)
                font.pixelSize: 10
                font.weight: Font.Normal
                font.family: "monospace"
                color: Theme.text
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
            }
        }

        // Upload speed
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connected

            Text {
                text: "↑"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: fmtSpeed(root.upSpeed)
                font.pixelSize: 10
                font.weight: Font.Normal
                font.family: "monospace"
                color: Theme.text
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ── Poll every 2 seconds ─────────────────────────────────────────────
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    property string _netBuf: ""

    Process {
        id: pollProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/network-stats.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => root._netBuf += d + "\n"
        }
        onExited: {
            var lines = root._netBuf.trim().split("\n")
            root._netBuf = ""

            // Line 1: wifi radio state
            var radioLine = (lines[0] || "").trim()
            root.radioOn = radioLine === "enabled"

            // Line 2: connection_type:ssid (wifi:SSID or ethernet: or none:)
            var connLine = (lines[1] || "").trim()
            if (connLine.startsWith("ethernet:")) {
                root.connectionType = "ethernet"
                root.connected = true
                root.ssid = ""
                root.signal_ = 0
            } else if (connLine.startsWith("wifi:")) {
                root.connectionType = "wifi"
                var parts = connLine.split(":")
                root.connected = true
                root.ssid = parts[1] || ""
                // Get signal from nmcli if available
                var signalLine = (lines[1] || "").trim()
                // Already have ssid, signal will be updated separately
            } else {
                root.connectionType = "none"
                root.connected = false
                root.ssid = ""
                root.signal_ = 0
            }

            // Get wifi signal strength if connected via wifi
            if (root.connectionType === "wifi") {
                wifiSignalProc.running = true
            }

            // Line 5: rx_bytes tx_bytes
            if (lines.length >= 5) {
                var netParts = (lines[4] || "").trim().split(/\s+/)
                if (netParts.length >= 2) {
                    var rx = parseFloat(netParts[0]) || 0
                    var tx = parseFloat(netParts[1]) || 0
                    if (root._prevRx >= 0) {
                        root.downSpeed = Math.max(0, rx - root._prevRx)
                        root.upSpeed = Math.max(0, tx - root._prevTx)
                    }
                    root._prevRx = rx
                    root._prevTx = tx
                }
            }
        }
    }

    // Get WiFi signal strength
    Process {
        id: wifiSignalProc
        command: ["bash", "-c",
            "LANG=C nmcli -t -f active,ssid,signal dev wifi list 2>/dev/null | " +
            "grep '^yes:' | cut -d: -f3 | head -1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var sig = parseInt(data.trim()) || 0
                root.signal_ = sig
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    signal clicked()
}

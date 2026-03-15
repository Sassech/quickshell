import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth:  labelRow.implicitWidth + 20
    implicitHeight: 24
    radius: 8
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    property bool   radioOn:    true
    property bool   connected:  false
    property string ssid:       ""
    property int    signal_:    0   // 0-100

    Behavior on color { ColorAnimation { duration: 100 } }

    // ── Icon based on state ───────────────────────────────────────────────
    property string wifiIcon: {
        if (!radioOn)   return "󰤮"
        if (!connected) return "󰤭"
        if (signal_ >= 80) return "󰤨"
        if (signal_ >= 60) return "󰤥"
        if (signal_ >= 40) return "󰤢"
        return "󰤟"
    }

    property color iconColor: connected ? Theme.accent : Theme.muted2

    // ── Poll every 5 s ────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    property string _buf: ""

    Process {
        id: pollProc
        // Line 1: radio state ("enabled"/"disabled")
        // Line 2: active:ssid:signal (empty if not connected)
        command: ["bash", "-c",
            "LANG=C nmcli radio wifi 2>/dev/null; "
            + "LANG=C nmcli -t -f active,ssid,signal dev wifi list 2>/dev/null "
            + "| grep '^yes:' | head -1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines = root._buf.trim().split("\n")
            root._buf = ""
            root.radioOn   = (lines[0] || "").trim() === "enabled"
            var net = (lines[1] || "").trim()
            if (net && net.startsWith("yes:")) {
                var parts = net.split(":")
                root.connected = true
                root.ssid      = parts[1] || ""
                root.signal_   = parseInt(parts[2]) || 0
            } else {
                root.connected = false
                root.ssid      = ""
                root.signal_   = 0
            }
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.wifiIcon
            font.pixelSize: 13
            color: root.iconColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.connected ? (root.ssid || "WiFi") : (root.radioOn ? "Desc." : "Apagado")
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

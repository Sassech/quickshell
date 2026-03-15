import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth:  labelRow.implicitWidth + 20
    implicitHeight: 24
    radius:         8
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    property bool   available:    false  // adapter present
    property bool   powered:      false
    property bool   connected:    false
    property string deviceName:   ""

    Behavior on color { ColorAnimation { duration: 100 } }

    property string btIcon: {
        if (!available) return "󰂲"
        if (!powered)   return "󰂲"
        if (connected)  return "󰂱"
        return "󰂯"
    }

    property color btColor: {
        if (!available || !powered) return Theme.muted2
        if (connected) return Theme.accent
        return Theme.muted1
    }

    // ── Poll every 5 s ────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: btProc.running = true
    }

    property string _buf: ""

    Process {
        id: btProc
        // Line 1: "yes" if adapter found and powered, "no" otherwise
        // Line 2: first connected device name (empty if none)
        command: ["bash", "-c",
            "result=$(printf 'show\\ndevices Connected\\n' | bluetoothctl 2>/dev/null); "
            + "powered=$(echo \"$result\" | grep 'Powered:' | awk '{print $2}'); "
            + "if [ -z \"$powered\" ]; then echo 'unavailable'; echo ''; exit 0; fi; "
            + "echo \"$powered\"; "
            + "echo \"$result\" | grep '^Device' | head -1 | sed 's/Device [^ ]* //'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var lines   = root._buf.trim().split("\n")
            root._buf   = ""
            var line0   = (lines[0] || "").trim()
            if (line0 === "unavailable") {
                root.available  = false
                root.powered    = false
                root.connected  = false
                root.deviceName = ""
            } else {
                root.available  = true
                root.powered    = line0.toLowerCase() === "yes"
                var dev         = (lines[1] || "").trim()
                root.connected  = dev !== ""
                root.deviceName = dev
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
            text: root.btIcon
            font.pixelSize: 14
            color: root.btColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.available) return "No disp."
                if (!root.powered)   return "Apagado"
                if (root.connected)  return root.deviceName || "Conectado"
                return "BT"
            }
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

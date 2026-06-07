import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../Components"

Rectangle {
    id: root

    implicitWidth:  labelRow.implicitWidth + 20
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()
    property string layout:  "—"
    property string locale:  "—"

    Behavior on color { ColorAnimation { duration: 100 } }

    // ── Hyprland rawEvent — actualiza layout en tiempo real sin polling ────
    // El evento "activelayout" se emite cada vez que cambia el layout activo.
    // Formato de data: "<device-name>,<layout-name>"
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",")
                if (parts.length >= 2) {
                    const name = parts[1].trim()
                    if (name) root.layout = name.substring(0, 3).toUpperCase()
                }
            }
        }
    }

    // ── Fetch inicial del layout al arrancar ──────────────────────────────
    // Solo se ejecuta una vez — el socket mantiene el estado actualizado de ahí en más.
    Process {
        id: initLayoutProc
        command: ["hyprctl", "devices", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    const obj = JSON.parse(data)
                    const keyboards = obj.keyboards ?? []
                    const main = keyboards.find(k => k.main) ?? keyboards[0]
                    if (main && main.active_keymap) {
                        root.layout = main.active_keymap.substring(0, 3).toUpperCase()
                    }
                } catch(e) {}
            }
        }
        Component.onCompleted: running = true
    }

    // Poll system locale once at startup
    Process {
        id: localeProc
        command: ["sh", "-c",
            "localectl status 2>/dev/null | awk '/System Locale/{print $3}' | cut -d= -f2 | cut -d_ -f1"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { const v = data.trim(); if (v) root.locale = v.toUpperCase() }
        }
        Component.onCompleted: running = true
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌌"
            font.pixelSize: 13
            color: Theme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.layout
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 12
            color: Theme.muted3
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.locale
            font.pixelSize: 11
            color: Theme.muted1
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

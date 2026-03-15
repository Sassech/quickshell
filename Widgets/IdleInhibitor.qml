import QtQuick
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    width:  24
    height: 24
    radius: 5
    color:  mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    property bool inhibiting: false

    Behavior on color { ColorAnimation { duration: 120 } }

    // ── Idle inhibit ────────────────────────────────────────────────
    Process {
        id: inhibitProc
        command: [
            "systemd-inhibit",
            "--what=idle",
            "--who=Quickshell",
            "--why=Manual inhibit",
            "--mode=block",
            "sleep", "infinity"
        ]
        running: false

        onExited: () => {
            root.inhibiting = false
        }
    }

    // ── notify-send helper
    Process {
        id: notifProc
        running: false
    }

    // ── Icono café ────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text:           "☕"
        font.pixelSize: 13
        // Activo: cálido (amarillo-naranja); inactivo: gris frío
        color:          root.inhibiting ? Theme.warning : Theme.muted3

        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // ── Punto indicador activo ────────────────────────────────────────────
    Rectangle {
        visible:         root.inhibiting
        width:           5
        height:          5
        radius:          3
        color:           Theme.error
        anchors.top:     parent.top
        anchors.right:   parent.right
        anchors.margins: 2
    }

    // ── Click ─────────────────────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor

        onClicked: {
            root.inhibiting     = !root.inhibiting
            inhibitProc.running = root.inhibiting
            notifProc.command   = root.inhibiting
                ? ["notify-send", "-u", "critical", "-i", "media-playback-pause", "☕ Idle bloqueado", "La pantalla no se apagará automáticamente"]
                : ["notify-send", "-u", "normal",   "-i", "media-playback-start", "Idle restaurado",    "El sistema volverá al comportamiento normal"]
            notifProc.running   = true
        }
    }

    // ── Tooltip ───────────────────────────────────────────────────────────
    Rectangle {
        visible:         mouseArea.containsMouse
        width:           tipText.implicitWidth + 12
        height:          18
        radius:          4
        color:           Theme.base
        border.color:    Theme.surface2
        border.width:    1
        anchors.bottom:  parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 4
        z: 10

        Text {
            id: tipText
            anchors.centerIn: parent
            text:           root.inhibiting ? "☕ Idle bloqueado" : "Idle activo"
            color:          Theme.text
            font.pixelSize: 9
        }
    }
}

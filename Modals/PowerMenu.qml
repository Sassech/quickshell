import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // ── Confirmación corta ────────────────────────────────────────────────
    property string pendingAction: ""

    Timer {
        id: confirmTimer
        interval: 2500
        onTriggered: root.pendingAction = ""
    }

    onVisibleChanged: {
        if (!visible) {
            root.pendingAction = ""
            confirmTimer.stop()
        }
    }

    // ── Overlay — click fuera cierra ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // ── Card centrada ─────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent

        // 4 botones × 90px + 3 gaps × 10px + márgenes 16px c/u
        width:  4 * 90 + 3 * 10 + 32
        height: 90 + 28 + 32   // botón + label + padding vertical

        radius: 18
        color: Qt.rgba(0.11, 0.11, 0.13, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        // Sombra
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: -10
            width: parent.width - 40
            height: 24
            radius: 10
            color: "#66000000"
            z: -1
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Fila de botones ───────────────────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: [
                    { id: "poweroff", icon: "⏻",  label: "Shutdown",  cmd: ["systemctl", "poweroff"],         critical: true  },
                    { id: "logout",   icon: "󰍃",  label: "Log Out",   cmd: ["hyprctl", "dispatch", "exit"],   critical: false },
                    { id: "reboot",   icon: "󰜉",  label: "Reboot",    cmd: ["systemctl", "reboot"],           critical: true  },
                    { id: "suspend",  icon: "󰒲",  label: "Sleep",     cmd: ["systemctl", "suspend"],          critical: false }
                ]

                // ── Botón individual ──────────────────────────────────────
                Column {
                    spacing: 8

                    property bool isConfirming: root.pendingAction === modelData.id

                    // Cuadrado redondeado con ícono
                    Rectangle {
                        width: 90; height: 90
                        radius: 16

                        color: isConfirming
                            ? Qt.rgba(1, 0.35, 0.35, 0.25)
                            : (btnHover.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.10)
                               : Qt.rgba(1, 1, 1, 0.06))

                        border.color: isConfirming
                            ? Qt.rgba(1, 0.4, 0.4, 0.6)
                            : (btnHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent")
                        border.width: 1

                        Behavior on color       { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Escala al hover
                        transform: Scale {
                            origin.x: 45; origin.y: 45
                            xScale: btnHover.containsMouse ? 1.06 : 1.0
                            yScale: btnHover.containsMouse ? 1.06 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: isConfirming ? "?" : modelData.icon
                            font.pixelSize: isConfirming ? 32 : 36
                            color: isConfirming
                                ? Qt.rgba(1, 0.5, 0.5, 1)
                                : Qt.rgba(1, 1, 1, btnHover.containsMouse ? 1.0 : 0.80)
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: btnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.critical) {
                                    if (root.pendingAction === modelData.id) {
                                        root.pendingAction = ""
                                        confirmTimer.stop()
                                        root.visible = false
                                        execProc.command = modelData.cmd
                                        execProc.running = true
                                    } else {
                                        root.pendingAction = modelData.id
                                        confirmTimer.restart()
                                    }
                                } else {
                                    root.visible = false
                                    execProc.command = modelData.cmd
                                    execProc.running = true
                                }
                            }
                        }
                    }

                    // Label debajo
                    Text {
                        width: 90
                        horizontalAlignment: Text.AlignHCenter
                        text: isConfirming ? "Confirm?" : modelData.label
                        font.pixelSize: 12
                        color: isConfirming
                            ? Qt.rgba(1, 0.6, 0.6, 1)
                            : Qt.rgba(1, 1, 1, 0.75)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
            }
        }
    }

    // Un solo proceso reutilizable (las acciones no solapan)
    Process {
        id: execProc
        running: false
        onExited: running = false
    }
}

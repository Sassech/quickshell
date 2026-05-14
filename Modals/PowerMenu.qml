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

    // ── Estado de confirmación ────────────────────────────────────────────
    property string pendingLabel: ""
    property var    pendingCmd:   []

    onVisibleChanged: {
        if (!visible) {
            confirmCard.visible = false
            root.pendingLabel   = ""
            root.pendingCmd     = []
        }
    }

    // ── Overlay — click fuera cierra ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // ── Card principal — 4 botones ────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent

        width:  4 * 90 + 3 * 10 + 32
        height: 90 + 28 + 32

        radius: 18
        color: Theme.cardBg3
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

        Row {
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: [
                    { id: "poweroff", icon: "⏻", label: "Shutdown", cmd: ["systemctl", "poweroff"], critical: true  },
                    { id: "logout",   icon: "󰍃", label: "Log Out",  cmd: ["hyprctl", "dispatch", "exit"], critical: false },
                    { id: "reboot",   icon: "󰜉", label: "Reboot",   cmd: ["systemctl", "reboot"],   critical: true  },
                    { id: "suspend",  icon: "󰒲", label: "Sleep",    cmd: ["systemctl", "suspend"],  critical: false }
                ]

                Column {
                    spacing: 8

                    Rectangle {
                        width: 90; height: 90
                        radius: 16

                        color: btnHover.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : Qt.rgba(1, 1, 1, 0.06)
                        border.color: btnHover.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                        border.width: 1

                        Behavior on color        { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        transform: Scale {
                            origin.x: 45; origin.y: 45
                            xScale: btnHover.containsMouse ? 1.06 : 1.0
                            yScale: btnHover.containsMouse ? 1.06 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 36
                            color: Qt.rgba(1, 1, 1, btnHover.containsMouse ? 1.0 : 0.80)
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: btnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.critical) {
                                    root.pendingLabel   = modelData.label
                                    root.pendingCmd     = modelData.cmd
                                    confirmCard.visible = true
                                } else {
                                    root.visible = false
                                    execProc.command = modelData.cmd
                                    execProc.running = true
                                }
                            }
                        }
                    }

                    Text {
                        width: 90
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.label
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.75)
                    }
                }
            }
        }
    }

    // ── Modal de confirmación ─────────────────────────────────────────────
    Rectangle {
        id: confirmCard
        anchors.centerIn: parent
        visible: false
        z: 10

        width:  260
        height: col.implicitHeight + 32

        radius: 16
        color: Theme.cardBg3
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // Sombra
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: -10
            width: parent.width - 32
            height: 24
            radius: 10
            color: "#66000000"
            z: -1
        }

        // Fade-in
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // Escala de entrada
        transform: Scale {
            origin.x: confirmCard.width  / 2
            origin.y: confirmCard.height / 2
            xScale: confirmCard.visible ? 1.0 : 0.88
            yScale: confirmCard.visible ? 1.0 : 0.88
            Behavior on xScale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            anchors.topMargin: 22
            spacing: 16

            // Título
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.pendingLabel
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Are you sure?"
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.50)
                }
            }

            // Botones No / Yes
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                // No
                Rectangle {
                    width: 100; height: 36
                    radius: 10
                    color: noHover.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, noHover.containsMouse ? 0.25 : 0.12)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "No"
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.80)
                    }
                    MouseArea {
                        id: noHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: confirmCard.visible = false
                    }
                }

                // Yes
                Rectangle {
                    width: 100; height: 36
                    radius: 10
                    color: yesHover.containsMouse
                        ? Qt.rgba(0.9, 0.2, 0.2, 0.45) : Qt.rgba(0.8, 0.15, 0.15, 0.25)
                    border.color: Qt.rgba(1, 0.35, 0.35, yesHover.containsMouse ? 0.7 : 0.40)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Yes"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1, 0.6, 0.6, 1)
                    }
                    MouseArea {
                        id: yesHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            confirmCard.visible = false
                            root.visible = false
                            execProc.command = root.pendingCmd
                            execProc.running = true
                        }
                    }
                }
            }
        }
    }

    Process {
        id: execProc
        running: false
        onExited: running = false
    }
}

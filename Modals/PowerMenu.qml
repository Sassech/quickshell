import QtQuick
import QtQuick.Layouts
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

    // ── Confirmación corta ───────────────────────────────────────────────
    property string pendingAction: ""

    Timer {
        id: confirmTimer
        interval: 2500
        onTriggered: root.pendingAction = ""
    }

    // Overlay oscuro — click fuera cierra
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    onVisibleChanged: {
        if (!visible) {
            root.pendingAction = ""
            confirmTimer.stop()
        }
    }

    // Card centrado
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 300
        height: col.implicitHeight + 28
        radius: 12
        color: Theme.base
        border.color: Theme.surface2
        border.width: 1

        // Header accent stripe
        Rectangle {
            width: parent.width; height: 3; radius: 2
            anchors.top: parent.top
            color: Theme.error
            Rectangle {
                width: parent.width / 2; height: parent.height
                anchors.right: parent.right
                color: Theme.warning
            }
        }

        // Absorbe clicks para no cerrar
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            id: col
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            anchors.topMargin: 18
            spacing: 8

            // Título
            RowLayout {
                spacing: 10
                Text { text: "⏻"; font.pixelSize: 20; color: Theme.error }
                Text {
                    text: "Sistema"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }

            Repeater {
                model: [
                    { id: "poweroff", icon: "⏻",  label: "Apagar",        sub: "systemctl poweroff",    color: Theme.error },
                    { id: "reboot",   icon: "󰜉",  label: "Reiniciar",      sub: "systemctl reboot",      color: Theme.warning },
                    { id: "suspend",  icon: "󰒲",  label: "Suspender",      sub: "systemctl suspend",     color: Theme.accent },
                    { id: "logout",   icon: "󰍃",  label: "Cerrar Sesión",  sub: "hyprctl dispatch exit", color: Theme.yellow }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 8
                    property bool isConfirming: root.pendingAction === modelData.id
                    color: isConfirming
                        ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.18)
                        : (itemMouse.containsMouse ? Qt.darker(modelData.color, 3.8) : Theme.surface2)
                    border.color: isConfirming ? modelData.color : (itemMouse.containsMouse ? modelData.color : "transparent")
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: modelData.icon
                            font.pixelSize: 18
                            color: modelData.color
                        }

                        Column {
                            spacing: 2
                            Text {
                                text: isConfirming ? "Confirmar" : modelData.label
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                color: Theme.text
                            }
                            Text {
                                text: isConfirming ? "Click de nuevo" : modelData.sub
                                font.pixelSize: 9
                                color: Theme.muted3
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var critical = modelData.id === "poweroff" || modelData.id === "reboot"
                            if (critical) {
                                if (root.pendingAction === modelData.id) {
                                    root.pendingAction = ""
                                    confirmTimer.stop()
                                } else {
                                    root.pendingAction = modelData.id
                                    confirmTimer.restart()
                                    return
                                }
                            }
                            root.visible = false
                            if      (modelData.id === "poweroff") poweroffProc.running = true
                            else if (modelData.id === "reboot")   rebootProc.running   = true
                            else if (modelData.id === "suspend")  suspendProc.running  = true
                            else if (modelData.id === "logout")   logoutProc.running   = true
                        }
                    }
                }
            }

            Item { height: 2 }
        }
    }

    Process { id: poweroffProc; running: false; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc;   running: false; command: ["systemctl", "reboot"]   }
    Process { id: suspendProc;  running: false; command: ["systemctl", "suspend"]  }
    Process { id: logoutProc;   running: false; command: ["hyprctl", "dispatch", "exit"] }
}

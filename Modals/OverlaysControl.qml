// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Components"

// ─────────────────────────────────────────────────────────────────────────────
// OverlaysControl — modal del sistema para activar/desactivar los overlays
// flotantes. No gestiona estado propio: enlaza los switches a las properties
// de OverlaysManager (que persiste en config/overlays-state.json).
// Futuros overlays solo agregan una fila aquí.
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    visible: false
    color:   "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }

    // ── API pública ───────────────────────────────────────────────────────
    function open()  { root.visible = true }
    function close() { root.visible = false }

    // ── Backdrop — cierra al hacer clic fuera ─────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── Tarjeta centrada ──────────────────────────────────────────────────
    Rectangle {
        id: ocCard
        focus: true
        anchors.centerIn: parent
        width:  360
        height: ocCol.implicitHeight + 32
        radius: 12
        color:  Theme.cardBg3

        Keys.onEscapePressed: root.close()

        // Borde sutil
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
            border.width: 1
        }

        // Intercepta clicks para que no caigan al backdrop
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: ocCol
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                margins: 16
            }
            spacing: 4

            // ── Título ──────────────────────────────────────────────────
            Text {
                text: "Overlays"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                text: "Activa o desactiva los widgets flotantes"
                font.pixelSize: 12
                color: Theme.muted2
            }

            // ── Separador ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 2
                implicitHeight: 1
                color: Theme.surface2
            }

            // ── Watermark (funcional) ────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 10
                color: wmArea.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 10

                    Text {
                        text: "󰇮"
                        font.pixelSize: 18
                        color: Theme.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Watermark"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            text: "Aviso estilo «Activar Windows»"
                            font.pixelSize: 10
                            color: Theme.muted2
                        }
                    }

                    ToggleSwitch {
                        Layout.alignment: Qt.AlignVCenter
                        checked: OverlaysManager.watermarkEnabled
                        onToggled: OverlaysManager.watermarkEnabled = value
                    }
                }

                MouseArea {
                    id: wmArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: OverlaysManager.watermarkEnabled = !OverlaysManager.watermarkEnabled
                }
            }

            // ── REC (próximamente — inactivo) ────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 10
                color: "transparent"
                opacity: 0.55

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 10

                    Text {
                        text: "󰑋"
                        font.pixelSize: 18
                        color: Theme.muted2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "REC"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.muted1
                            }

                            Rectangle {
                                implicitWidth: tagText.implicitWidth + 12
                                implicitHeight: 15
                                radius: 7
                                color: Theme.surface3

                                Text {
                                    id: tagText
                                    anchors.centerIn: parent
                                    text: "Próximamente"
                                    font.pixelSize: 8
                                    color: Theme.muted3
                                }
                            }
                        }

                        Text {
                            text: "Grabación en pantalla"
                            font.pixelSize: 10
                            color: Theme.muted3
                        }
                    }

                    ToggleSwitch {
                        Layout.alignment: Qt.AlignVCenter
                        enabled: false
                    }
                }
            }

            // ── Hint de cierre ──────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: "Se cierra con la misma tecla / ESC"
                font.pixelSize: 10
                color: Theme.muted3
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Componente interno: switch custom ─────────────────────────────────
    // Estilo hand-rolled del proyecto (Behavior + thumb animado), sin
    // QtQuick.Controls para no introducir dependencia nueva.
    component ToggleSwitch: Item {
        id: sw

        signal toggled(bool value)

        property bool checked: false

        width:  40
        height: 22
        opacity: sw.enabled ? 1.0 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.checked ? Theme.accent : Theme.surface3
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Rectangle {
            id: knob
            width:  18
            height: 18
            radius: 9
            color:  "white"
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 2 : 2
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled(!sw.checked)
        }
    }
}

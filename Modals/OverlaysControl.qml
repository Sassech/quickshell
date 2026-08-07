// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Components"

// ─────────────────────────────────────────────────────────────────────────────
// OverlaysControl — modal del sistema para gestionar los overlays flotantes.
//
// Data-driven: renderiza una fila por entrada de OverlaysManager.overlays
// (Repeater). Agregar un overlay nuevo NO requiere tocar este archivo — solo
// agregar la OverlayEntry en el manager.
// ─────────────────────────────────────────────────────────────────────────────
QmModalBase {
    id: root

    cardWidth: 360
    cardHeight: ocCol.implicitHeight + 32
    cardRadius: 12
    cardBorderColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
    focusCard: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── Contenido ────────────────────────────────────────────────────────────
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

        // ── Filas por overlay (data-driven) ─────────────────────────
        Repeater {
            model: OverlaysManager.overlays

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 78
                radius: 10
                color: rowArea.containsMouse || rowTopArea.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    anchors {
                        fill: parent
                        topMargin: 8
                        bottomMargin: 8
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 4

                    // Renglón 1: nombre + toggle principal
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        spacing: 10

                        MouseArea {
                            id: rowArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.enabled = !modelData.enabled

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 18
                                    color: Theme.accent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                    Text {
                                        text: modelData.description
                                        font.pixelSize: 10
                                        color: Theme.muted2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        ToggleSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            checked: modelData.enabled
                            onToggled: modelData.enabled = value
                        }
                    }

                    // Renglón 2: capa
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        spacing: 10

                        MouseArea {
                            id: rowTopArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.onTop = !modelData.onTop

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18 }

                                Text {
                                    text: "󰌨"   // nf-md-layers
                                    font.pixelSize: 11
                                    color: Theme.muted2
                                }
                                Text {
                                    text: "Sobre las ventanas"
                                    font.pixelSize: 10
                                    color: Theme.muted2
                                }
                            }
                        }

                        ToggleSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            checked: modelData.onTop
                            onToggled: modelData.onTop = value
                        }
                    }
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

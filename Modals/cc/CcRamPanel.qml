import QtQuick
import QtQuick.Layouts
import "../../Components"

// ── CcRamPanel ───────────────────────────────────────────────────────────────
// Panel de detalle de RAM: uso %, GB usados/total/disponibles + swap.
Rectangle {
    id: root
    implicitWidth: 300
    implicitHeight: ramDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2); border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property bool ramAvailable
    required property int  ramPercent
    required property real ramUsedGb
    required property real ramTotalGb
    required property real ramAvailGb
    required property int  swapPercent

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Color helper ─────────────────────────────────────────────────────
    property color _accentColor: {
        if (!root.ramAvailable) return Theme.muted2
        if (root.ramPercent >= 90) return Theme.error
        if (root.ramPercent >= 75) return Theme.warning
        if (root.ramPercent >= 60) return Theme.yellow
        return Theme.accent
    }

    Column {
        id: ramDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 6

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "RAM"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: ramCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: ramCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── Uso % bar ─────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(4, root.ramPercent / 100 * parent.width)
                radius: 3; color: root._accentColor
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        // ── Porcentaje + GB usados ─────────────────────────────────────────
        Row {
            spacing: 16
            Text {
                text: root.ramPercent + "%"
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                text: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
                font.pixelSize: 11; color: Theme.muted1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Mini cards ────────────────────────────────────────────────────
        Row {
            width: parent.width; spacing: 6

            Repeater {
                model: [
                    { value: root.ramUsedGb.toFixed(1) + " GB",   label: "Usada",      color: root._accentColor },
                    { value: root.ramAvailGb.toFixed(1) + " GB",  label: "Disponible", color: Theme.accent },
                    { value: root.swapPercent + "%",               label: "Swap",
                      color: root.swapPercent >= 80 ? Theme.error
                           : root.swapPercent >= 50 ? Theme.yellow
                           : Theme.muted1 }
                ]

                Rectangle {
                    required property var modelData
                    width: (ramDetailCol.width - 12) / 3
                    height: 48; radius: 8; color: Theme.surface3
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: modelData.color
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: 9; color: Theme.muted2
                        }
                    }
                }
            }
        }
    }
}

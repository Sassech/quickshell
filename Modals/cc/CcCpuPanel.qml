import QtQuick
import QtQuick.Layouts
import "../../Components"

// ── CcCpuPanel ───────────────────────────────────────────────────────────────
// Panel de detalle de CPU: uso %, temperatura y frecuencia por núcleo (si disponible).
Rectangle {
    id: root
    implicitWidth: 300
    implicitHeight: cpuDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2); border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property bool cpuAvailable
    required property int  cpuPercent
    required property int  cpuTemp

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Color helper ─────────────────────────────────────────────────────
    property color _accentColor: {
        if (!root.cpuAvailable) return Theme.muted2
        if (root.cpuTemp >= 85)  return Theme.error
        if (root.cpuTemp >= 70)  return Theme.warning
        if (root.cpuTemp >= 55)  return Theme.yellow
        return Theme.accent
    }

    Column {
        id: cpuDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 6

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "CPU"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: cpuCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: cpuCloseMA; anchors.fill: parent; hoverEnabled: true
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
                width: Math.max(4, root.cpuPercent / 100 * parent.width)
                radius: 3; color: root._accentColor
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        // ── Porcentaje + temperatura ───────────────────────────────────────
        Row {
            spacing: 16
            Text {
                text: root.cpuPercent + "%"
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                visible: root.cpuTemp > 0
                text: root.cpuTemp + " °C"
                font.pixelSize: 11; color: root._accentColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Mini cards ────────────────────────────────────────────────────
        Row {
            width: parent.width; spacing: 6

            Repeater {
                model: [
                    { value: root.cpuPercent + "%",    label: "Uso",      color: root._accentColor },
                    { value: root.cpuTemp > 0 ? root.cpuTemp + " °C" : "—", label: "Temp", color: root._accentColor },
                    { value: root.cpuAvailable ? "OK" : "—",               label: "Estado",  color: Theme.accent }
                ]

                Rectangle {
                    required property var modelData
                    width: (cpuDetailCol.width - 12) / 3
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

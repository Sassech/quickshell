import QtQuick
import "../../Components"

// CcBatteryPanel
// Panel de detalle de batería (datos UPower).
Rectangle {
    id: root
    implicitWidth: 300
    implicitHeight: batDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2); border.width: 1
    }

    // Inputs
    required property bool  batAvailable
    required property real  batPct
    required property bool  batCharging
    required property bool  batFull
    required property real  batHealth
    required property real  batCapWh
    required property real  batEnergy
    required property real  batChangeRate
    required property real  batTimeEmpty
    required property real  batTimeFull

    // Outputs
    signal closeRequested()

    Column {
        id: batDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 6

        // Header
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Battery"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: bCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: bCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Charge bar
        Item {
            width: parent.width; height: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(4, root.batPct / 100 * parent.width)
                radius: 3
                color: root.batCharging ? Theme.success
                     : root.batPct > 50 ? Theme.accent
                     : root.batPct > 20 ? Theme.yellow
                     : Theme.error
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        // Estado y potencia
        Row {
            spacing: 16
            Text {
                text: Math.round(root.batPct) + "%"
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                text: {
                    if (root.batFull)     return "Full"
                    if (root.batCharging) return "Charging"
                    return "Discharging"
                }
                font.pixelSize: 11; color: Theme.muted1
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: root.batChangeRate > 0
                text: root.batChangeRate.toFixed(1) + " W"
                font.pixelSize: 11; color: Theme.muted2
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Health / Capacity / Energy — mini cards
        Row {
            width: parent.width; spacing: 6
            visible: root.batAvailable

            Repeater {
                model: [
                    {
                        value: root.batHealth > 0
                            ? root.batHealth.toFixed(1) + "%"
                            : "—",
                        label: "Health",
                        color: root.batHealth >= 80 ? Theme.accent
                             : root.batHealth >= 60 ? Theme.yellow
                             : root.batHealth > 0   ? Theme.error
                             : Theme.muted2
                    },
                    {
                        value: root.batCapWh > 0
                            ? root.batCapWh.toFixed(1) + " Wh"
                            : "—",
                        label: "Capacity",
                        color: Theme.text
                    },
                    {
                        value: root.batEnergy > 0
                            ? root.batEnergy.toFixed(1) + " Wh"
                            : "—",
                        label: "Now",
                        color: Theme.muted1
                    }
                ]

                Rectangle {
                    id: batStatCard
                    required property var modelData
                    width: (parent.width - 12) / 3
                    height: 48; radius: 8; color: Theme.surface3
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: batStatCard.modelData.value
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: batStatCard.modelData.color
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: batStatCard.modelData.label
                            font.pixelSize: 9; color: Theme.muted2
                        }
                    }
                }
            }
        }

        // Tiempo restante
        Row {
            spacing: 8
            visible: !root.batFull && root.batAvailable

            Text {
                text: root.batCharging ? "Full in:" : "Empty in:"
                font.pixelSize: 10; color: Theme.muted2
            }
            Text {
                text: {
                    var t = root.batCharging ? root.batTimeFull : root.batTimeEmpty
                    return Formatters.fmtTime(t) || "—"
                }
                font.pixelSize: 10; color: Theme.text
            }
        }
    }
}

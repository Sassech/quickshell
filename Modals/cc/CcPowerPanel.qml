pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower
import "../../Components"

// ── CcPowerPanel ─────────────────────────────────────────────────────────────
// Panel de perfiles de energía (UPower) y control de ventiladores.
Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: powerDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2); border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property var    fanProfiles    // [{id, label, icon}] — no usado, mantenido por compatibilidad
    required property string fanProfile     // SysData.fanProfile — no usado

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()
    signal setPower(var profile)

    // ── Helpers ───────────────────────────────────────────────────────────
    function _powerLabel(profile) {
        if (profile === PowerProfile.Performance) return "Performance"
        if (profile === PowerProfile.PowerSaver)  return "Power saver"
        return "Balanced"
    }
    function _powerIcon(profile) {
        if (profile === PowerProfile.Performance) return "󰓅"
        if (profile === PowerProfile.PowerSaver)  return "󰁹"
        return "󱐌"
    }

    Column {
        id: powerDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Power & Fans"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: pCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: pCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── CPU power profiles — UPower PowerProfiles ─────────────────────
        Text {
            text: "CPU Power Profile"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: {
                    var profiles = [PowerProfile.PowerSaver, PowerProfile.Balanced]
                    if (PowerProfiles.hasPerformanceProfile)
                        profiles.push(PowerProfile.Performance)
                    return profiles
                }

                Rectangle {
                    id: pBtn
                    required property var modelData
                    required property int index
                    property bool active: PowerProfiles.profile === modelData

                    width: {
                        var n = PowerProfiles.hasPerformanceProfile ? 3 : 2
                        return (parent.width - 6 * (n - 1)) / n
                    }
                    height: 36; radius: 8
                    color: active
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                        : (pBtnHov.containsMouse ? Theme.surface3 : Theme.surface2)
                    border.color: active ? Theme.accent : "transparent"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root._powerIcon(pBtn.modelData)
                            font.pixelSize: 13
                            color: pBtn.active ? Theme.accent : Theme.muted1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root._powerLabel(pBtn.modelData)
                            font.pixelSize: 8
                            color: pBtn.active ? Theme.accent : Theme.muted2
                        }
                    }

                    MouseArea {
                        id: pBtnHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setPower(pBtn.modelData)
                    }
                }
            }
        }

        // ── Fans ───────────────────────────────────────────────────────────
        Rectangle { width: parent.width; height: 1; color: Theme.surface3; visible: SysData.fanAvailable }

        Text {
            visible: SysData.fanAvailable
            text: "Fans"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
        }

        // Fan RPM bars
        Column {
            visible: SysData.fanAvailable && SysData.fan1Rpm > 0
            width: parent.width; spacing: 4

            Repeater {
                model: [
                    { label: "F1", rpm: SysData.fan1Rpm, pct: SysData.fan1Percent, color: Theme.accent },
                    { label: "F2", rpm: SysData.fan2Rpm, pct: SysData.fan2Percent, color: Theme.accent2 }
                ]

                Row {
                    id: fanRow
                    required property var modelData
                    width: parent.width
                    spacing: 6
                    Text {
                        text: fanRow.modelData.label; font.pixelSize: 9; color: Theme.muted1
                        width: 16; anchors.verticalCenter: parent.verticalCenter
                    }
                    Item {
                        width: fanRow.width - 80 - 16 - 6 - 6; height: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: Math.max(4, fanRow.modelData.pct / 100 * parent.width)
                            radius: 3; color: fanRow.modelData.color
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    Text {
                        text: fanRow.modelData.rpm + " rpm"; font.pixelSize: 9; color: Theme.muted2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── Temps row ─────────────────────────────────────────────────────
        Row {
            visible: SysData.fanAvailable
            spacing: 8

            Repeater {
                model: [
                    { label: "CPU", temp: SysData.fanCpuTemp },
                    { label: "GPU", temp: SysData.fanGpuTemp }
                ]
                Row {
                    id: tempRow
                    required property var modelData
                    spacing: 4
                    Text { text: tempRow.modelData.label + ":"; font.pixelSize: 9; color: Theme.muted2 }
                    Text {
                        text: tempRow.modelData.temp + " °C"; font.pixelSize: 9
                        color: tempRow.modelData.temp >= 85 ? Theme.error
                             : tempRow.modelData.temp >= 70 ? Theme.warning
                             : Theme.muted1
                    }
                }
            }
        }
    }
}

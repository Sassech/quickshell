pragma ComponentBehavior: Bound

import QtQuick
import "../../Components"

// Power action buttons row + close button
Item {
    id: root
    implicitHeight: 44

    signal showConfirm(string label, var cmd)
    signal runCmd(var cmd)
    signal close()

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: [
                { icon: "⏻",  label: "Shut down",  cmd: ["systemctl", "poweroff"],        color: Theme.error,   critical: true  },
                { icon: "󰜉",  label: "Reboot",     cmd: ["systemctl", "reboot"],          color: Theme.warning, critical: true  },
                { icon: "󰌾",  label: "Lock",       cmd: ["hyprlock"],                     color: Theme.blue,    critical: false },
                { icon: "󰍃",  label: "Log out",    cmd: ["hyprctl", "dispatch", "exit"],  color: Theme.purple,  critical: false },
                { icon: "󰒲",  label: "Sleep",      cmd: ["systemctl", "suspend"],         color: Theme.success, critical: false }
            ]

            Rectangle {
                id: pwBtn
                required property var modelData
                width: 36; height: 36; radius: 9
                color: pwHov.containsMouse
                    ? Qt.rgba(Theme.surface3.r, Theme.surface3.g, Theme.surface3.b, 1)
                    : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: pwBtn.modelData.icon
                    font.pixelSize: 16
                    color: pwHov.containsMouse ? pwBtn.modelData.color : Theme.muted1
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: pwHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pwBtn.modelData.critical) {
                            root.showConfirm(pwBtn.modelData.label, pwBtn.modelData.cmd)
                        } else {
                            root.runCmd(pwBtn.modelData.cmd)
                        }
                    }
                }

                // Tooltip label on hover
                Rectangle {
                    visible: pwHov.containsMouse
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 4
                    width: tipText.implicitWidth + 10; height: 18
                    radius: 4; color: Theme.surface3

                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: pwBtn.modelData.label
                        font.pixelSize: 9; color: Theme.text
                    }
                }
            }
        }
    }

    // Close button — top right
    Rectangle {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 24; height: 24; radius: 6
        color: closeHov.containsMouse ? Theme.surface3 : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
        MouseArea {
            id: closeHov; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
        }
    }
}

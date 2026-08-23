import QtQuick
import "../Components"

Rectangle {
    id: root

    implicitWidth: 70
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    // Properties
    readonly property bool batteryAvailable: SysData.batAvailable
    readonly property int  batteryLevel:     SysData.batPercent
    readonly property bool isCharging:       SysData.batCharging

    property string stateIcon: {
        if (!batteryAvailable) return ""
        if (SysData.batStatus === "Charging")     return "󰂄"
        if (SysData.batStatus === "Discharging")  return "󰂃"
        if (SysData.batStatus === "Full")         return "󰁹"
        if (SysData.batStatus === "Not charging") return "󰂂"
        return "󰂑"
    }

    property color levelColor: {
        if (!batteryAvailable)  return Theme.muted2
        if (isCharging)         return Theme.success
        if (batteryLevel > 50)  return Theme.accent
        if (batteryLevel > 20)  return Theme.yellow
        return Theme.error
    }

    // Content
    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.stateIcon
            font.pixelSize: 13
            color: root.levelColor
            visible: root.batteryAvailable
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batteryLevel + "%"
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 32
            horizontalAlignment: Text.AlignRight
            visible: root.batteryAvailable
        }

        Item { width: 0; height: 1 }
    }

}

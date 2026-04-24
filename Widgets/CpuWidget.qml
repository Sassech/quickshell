import QtQuick
import QtQuick.Layouts
import "../Components"

Rectangle {
    id: root

    implicitWidth: 104
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    property color accentColor: {
        if (!SysData.cpuAvailable) return Theme.muted2
        if (SysData.cpuTemp >= 85) return Theme.error
        if (SysData.cpuTemp >= 70) return Theme.warning
        if (SysData.cpuTemp >= 55) return Theme.yellow
        return Theme.accent
    }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰻠"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.cpuAvailable ? (SysData.cpuPercent + "%") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: SysData.cpuAvailable ? Theme.text : Theme.muted3
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            visible: SysData.cpuAvailable && SysData.cpuTemp > 0
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.cpuTemp + "°"
            font.pixelSize: 10
            color: Theme.muted1
            width: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick
import "../Components"

Rectangle {
    id: root

    signal clicked()

    implicitWidth: 104
    implicitHeight: 24
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    property color accentColor: {
        if (!SysData.cpuAvailable) return Theme.muted2
        if (SysData.cpuTemp >= 85) return Theme.error
        if (SysData.cpuTemp >= 70) return Theme.warning
        if (SysData.cpuTemp >= 55) return Theme.yellow
        return Theme.accent
    }

    Behavior on color { ColorAnimation { duration: 100 } }

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
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

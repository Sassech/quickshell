import QtQuick
import "../Components"

Rectangle {
    id: root

    implicitWidth: 104
    implicitHeight: 24
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰈐"
            font.pixelSize: 13
            color: SysData.fanAvailable ? Theme.accent : Theme.muted2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.fanAvailable ? (SysData.fan1Rpm + "") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: SysData.fanAvailable ? Theme.text : Theme.muted3
            width: 34
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.fanAvailable ? (SysData.fanCpuTemp + "°") : ""
            font.pixelSize: 10
            font.family: "monospace"
            color: Theme.muted1
            width: 24
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

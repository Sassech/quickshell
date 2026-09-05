import QtQuick
import "../Components"

Rectangle {
    id: root

    signal clicked()

    implicitWidth: 96
    implicitHeight: 24
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    property bool hasData: SysData.gpuAvailable

    property color accentColor: {
        if (!hasData) return Theme.muted3
        if (SysData.gpuTemp >= 85) return Theme.error
        if (SysData.gpuTemp >= 70) return Theme.warning
        return Theme.accent2
    }

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍹"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasData ? SysData.gpuPercent + "%" : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: root.hasData ? Theme.text : Theme.muted3
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            visible: root.hasData && SysData.gpuTemp > 0
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.gpuTemp + "°"
            font.pixelSize: 10
            color: Theme.muted1
            width: 28
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

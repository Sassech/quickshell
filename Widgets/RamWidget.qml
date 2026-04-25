import QtQuick
import QtQuick.Layouts
import "../Components"

Rectangle {
    id: root

    implicitWidth: 104
    implicitHeight: 24
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    // ── Color thresholds ─────────────────────────────────────
    property color accentColor: {
        if (!SysData.ramAvailable) return Theme.muted2
        if (SysData.ramPercent >= 90) return Theme.error
        if (SysData.ramPercent >= 75) return Theme.warning
        if (SysData.ramPercent >= 60) return Theme.yellow
        return Theme.accent
    }

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰘚"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.ramAvailable ? (SysData.ramPercent + "%") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: SysData.ramAvailable ? Theme.text : Theme.muted3
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.ramAvailable ? (SysData.ramUsedGb.toFixed(1) + "GB") : ""
            font.pixelSize: 10
            color: Theme.muted1
            width: 34
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

import QtQuick
import QtQuick.Layouts
import "../Components"

Rectangle {
    id: root

    implicitWidth: 118
    implicitHeight: 24
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    // ── Color thresholds ─────────────────────────────────────
    property color accentColor: {
        if (!SysData.diskAvailable) return Theme.muted2
        if (SysData.diskPercent >= 90) return Theme.error
        if (SysData.diskPercent >= 75) return Theme.warning
        return Theme.success
    }

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰋊"
            font.pixelSize: 13
            color: root.accentColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.diskAvailable ? (SysData.diskPercent + "%") : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SysData.diskAvailable ? (SysData.diskAvailGb + "GB libre") : ""
            font.pixelSize: 10
            color: Theme.muted1
            width: 62
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

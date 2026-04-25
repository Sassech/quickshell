import QtQuick
import "../Components"

Rectangle {
    id: root

    implicitWidth: 70
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    // ── Properties ───────────────────────────────────────────
    property bool batteryAvailable: SysData.batAvailable
    property int batteryLevel: SysData.batPercent
    property string batteryStatus: SysData.batStatus
    property bool isCharging: SysData.batCharging

    property string stateIcon: {
        if (!root.batteryAvailable) return ""
        if (root.batteryStatus === "Charging") return "󰂄"
        if (root.batteryStatus === "Discharging") return "󰂃"
        if (root.batteryStatus === "Full") return "󰁹"
        if (root.batteryStatus === "Not charging") return "󰂂"
        return "󰂑"
    }

    property color levelColor: {
        if (!batteryAvailable) return Theme.muted2
        if (isCharging) return Theme.success
        if (batteryLevel > 50) return Theme.accent
        if (batteryLevel > 20) return Theme.yellow
        return Theme.error
    }

    // ── Hover ────────────────────────────────────────────────
    property bool _hovered: false

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    // ── Content ──────────────────────────────────────────────
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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root._hovered = true
        onExited: root._hovered = false
        onClicked: root.clicked()
    }
}

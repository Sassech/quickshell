import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    property int batteryLevel: 0
    property string batteryStatus: "Unknown"
    property bool isCharging: false

    property color levelColor: {
        if (isCharging) return Theme.success
        if (batteryLevel > 50) return Theme.accent
        if (batteryLevel > 20) return Theme.yellow
        return Theme.error
    }

    // Left accent border
    Rectangle {
        width: 3
        height: parent.height * 0.6
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        color: root.levelColor
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 5

        // Battery icon
        Item {
            width: 18
            height: 12
            anchors.verticalCenter: parent.verticalCenter

            // Battery body
            Rectangle {
                id: battBody
                x: 0
                y: 1
                width: 15
                height: 10
                radius: 2
                color: "transparent"
                border.color: root.levelColor
                border.width: 1.5

                // Fill
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.max(2, (parent.width - 4) * root.batteryLevel / 100)
                    radius: 1
                    color: root.levelColor
                }
            }
            // Battery terminal
            Rectangle {
                x: battBody.width + 1
                y: 3.5
                width: 2
                height: 5
                radius: 1
                color: root.levelColor
            }
            // Charging bolt
            Text {
                visible: root.isCharging
                anchors.centerIn: battBody
                text: "⚡"
                font.pixelSize: 7
                color: Theme.base
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batteryLevel + "%"
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
        }
    }

    // Polling timer
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            capacityProc.running = true
            statusProc.running = true
        }
    }

    // Read capacity
    property string _capBuf: ""
    Process {
        id: capacityProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._capBuf += data
        }
        onExited: {
            var v = parseInt(root._capBuf.trim())
            if (!isNaN(v)) root.batteryLevel = v
            root._capBuf = ""
        }
    }

    // Read status
    property string _statusBuf: ""
    Process {
        id: statusProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._statusBuf += data
        }
        onExited: {
            var s = root._statusBuf.trim()
            root.batteryStatus = s
            root.isCharging = (s === "Charging")
            root._statusBuf = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

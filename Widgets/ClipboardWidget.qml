import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth:  60
    implicitHeight: 24
    radius: 8
    color: Theme.surface2

    signal clicked()

    property int entryCount: 0
    property color accent: Theme.accent2

    // Left accent border
    Rectangle {
        width: 3; height: parent.height * 0.6
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: 4
        color: root.accent
    }

    Row {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󱉫"
            font.pixelSize: 13
            color: root.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.entryCount > 0 ? root.entryCount : ""
            font.pixelSize: 11
            font.weight: Font.Normal
            font.family: "monospace"
            color: Theme.text
            visible: root.entryCount > 0
        }
    }

    // Actualiza conteo al inicio y cada 30s
    Timer {
        interval: 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: countProc.running = true
    }

    property string _countBuf: ""
    Process {
        id: countProc
        command: ["bash", "-c", "cliphist list 2>/dev/null | wc -l"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._countBuf = data
        }
        onExited: {
            var n = parseInt(root._countBuf.trim())
            if (!isNaN(n)) root.entryCount = n
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()

        Rectangle {
            anchors.fill: parent; radius: parent.parent.radius
            color: parent.containsMouse ? "#ffffff" : "transparent"
            opacity: parent.containsMouse ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }
}

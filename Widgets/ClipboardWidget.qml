import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth:  50
    implicitHeight: 24
    radius: 8
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    property int entryCount: 0
    property color accent: Theme.accent2

    Behavior on color { ColorAnimation { duration: 100 } }

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

    // Carga el conteo una vez al inicio; se actualiza vía countUpdated(n) desde el modal
    Component.onCompleted: countProc.running = true

    function updateCount(n) {
        if (!isNaN(n) && n >= 0) root.entryCount = n
    }

    property string _countBuf: ""
    Process {
        id: countProc
        command: ["bash", "-c", "cliphist list 2>/dev/null | wc -l"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._countBuf = data
        }
        // qmllint disable signal-handler-parameters
        onExited: {
            const n = parseInt(root._countBuf.trim())
            if (!isNaN(n)) root.entryCount = n
            root._countBuf = ""
        }
        // qmllint enable signal-handler-parameters
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

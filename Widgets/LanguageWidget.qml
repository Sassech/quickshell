import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    implicitWidth:  labelRow.implicitWidth + 20
    implicitHeight: 24
    radius: 8
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()
    property string layout:  "—"
    property string locale:  "—"

    Behavior on color { ColorAnimation { duration: 100 } }

    // Poll keyboard layout every 3 s
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: devProc.running = true
    }

    Process {
        id: devProc
        command: ["sh", "-c",
            "hyprctl devices -j 2>/dev/null | "
            + "awk -F'\"' '/active_keymap/{print $4; exit}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var v = data.trim()
                if (v) root.layout = v.substring(0, 3).toUpperCase()
            }
        }
    }

    // Poll system locale once at startup
    Process {
        id: localeProc
        command: ["sh", "-c",
            "localectl status 2>/dev/null | awk '/System Locale/{print $3}' | cut -d= -f2 | cut -d_ -f1"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { var v = data.trim(); if (v) root.locale = v.toUpperCase() }
        }
        Component.onCompleted: running = true
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌌"
            font.pixelSize: 13
            color: Theme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.layout
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 12
            color: Theme.muted3
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.locale
            font.pixelSize: 11
            color: Theme.muted1
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

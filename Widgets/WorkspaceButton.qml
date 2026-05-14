import QtQuick
import Quickshell.Hyprland
import "../Components"

Rectangle {
    id: root
    required property var workspace

    width: 28
    height: 28
    radius: 6
    color: workspace.active ? Theme.accentDim : (mouseArea.containsMouse ? Theme.surface3 : Theme.surface4)

    Behavior on color { ColorAnimation { duration: 100 } }

    // Cuadro interno — solo visible en el workspace activo
    Rectangle {
        anchors.centerIn: parent
        width: 18
        height: 18
        radius: 4
        color: workspace.active ? Theme.accent : "transparent"

        Text {
            anchors.centerIn: parent
            text: workspace.id
            color: workspace.active ? Theme.cardBg3 : Theme.muted1
            font.pixelSize: 11
            font.bold: workspace.active
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Hyprland.dispatch("workspace " + workspace.id)
        }
    }
}

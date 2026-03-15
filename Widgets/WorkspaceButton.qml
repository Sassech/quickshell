import QtQuick
import Quickshell.Hyprland
import "../Components"

Rectangle {
    required property var workspace

    width: 28
    height: 28
    radius: 6
    color: workspace.active ? Theme.accentDim : Theme.surface3

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
            color: workspace.active ? Theme.base : Theme.muted1
            font.pixelSize: 11
            font.bold: workspace.active
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Hyprland.dispatch("workspace " + workspace.id)
        }
    }
}

import QtQuick
import "../Components"

// Botón engranaje — abre el Control Center
Rectangle {
    id: root
    signal clicked()

    width: 24; height: 24; radius: 5
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        font.pixelSize: 14
        color: ma.containsMouse ? Theme.accent : Theme.text
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

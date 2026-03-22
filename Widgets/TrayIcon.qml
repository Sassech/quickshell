import QtQuick
import "../Components"

Rectangle {
    id: root
    
    required property var trayItem
    property int size: 20
    
    width: size
    height: size
    radius: 4
    color: ma.containsMouse ? Theme.surface3 : "transparent"
    
    Behavior on color { ColorAnimation { duration: 100 } }
    
    scale: ma.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 50 } }
    
    Image {
        anchors.centerIn: parent
        width: root.size - 4
        height: root.size - 4
        source: root.trayItem.icon
        sourceSize: Qt.size(root.size - 4, root.size - 4)
    }
    
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}

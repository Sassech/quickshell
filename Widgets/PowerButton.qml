import QtQuick
import "../Components"

Rectangle {
    id: root
    
    signal clicked()
    
    width: 24
    height: 24
    radius: 5
    color: mouseArea.containsMouse ? Theme.surface3 : Theme.surface2
    border.color: mouseArea.containsMouse ? Theme.error : "transparent"
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }
    
    Text {
        anchors.centerIn: parent
        text: "⏻"
        color: mouseArea.containsMouse ? Theme.error : Theme.text
        font.pixelSize: 16
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

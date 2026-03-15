import QtQuick
import "../Components"

Rectangle {
    id: root
    
    signal clicked()
    
    width: 24
    height: 24
    radius: 5
    color: mouseArea.containsMouse ? Theme.error : Theme.surface2
    
    Text {
        anchors.centerIn: parent
        text: "⏻"
        color: Theme.text
        font.pixelSize: 16
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

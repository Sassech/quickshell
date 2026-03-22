import QtQuick
import QtQuick.Controls
import "../Components"

// Ícono individual del System Tray (protocolo SNI)
Rectangle {
    id: root
    
    required property var trayItem  // SystemTrayItem
    property int size: 20
    
    width: size
    height: size
    radius: 4
    color: mouseArea.containsMouse ? Theme.surface3 : "transparent"
    
    Behavior on color { ColorAnimation { duration: 100 } }
    
    Image {
        anchors.centerIn: parent
        width: root.size - 4
        height: root.size - 4
        source: root.trayItem.icon
        sourceSize: Qt.size(root.size - 4, root.size - 4)
        cache: true
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.trayItem.activate()
            } else if (mouse.button === Qt.RightButton && root.trayItem.hasMenu) {
                root.trayItem.display(root, mouse.x, mouse.y)
            }
        }
    }
    
    ToolTip {
        visible: mouseArea.containsMouse
        delay: 500
        
        contentItem: Text {
            text: root.trayItem.tooltipTitle || root.trayItem.id
            color: Theme.text
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 2
        }
        
        background: Rectangle {
            color: Theme.surface3
            border.color: Theme.overlay
            border.width: 1
            radius: 4
        }
    }
    
    scale: mouseArea.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 50 } }
}
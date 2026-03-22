import QtQuick
import "../Components"

Rectangle {
    id: root

    required property var trayItem
    property int size: 20

    width: size
    height: size
    radius: 4
    color: "transparent"

    Image {
        anchors.centerIn: parent
        width: root.size - 4
        height: root.size - 4
        source: root.trayItem.icon
        sourceSize: Qt.size(root.size - 4, root.size - 4)
    }
}

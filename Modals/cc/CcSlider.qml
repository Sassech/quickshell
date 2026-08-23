pragma ComponentBehavior: Bound

import QtQuick
import "../../Components"

// CcSlider — fila de slider parametrizada (volumen, micrófono, brillo)
// Encapsula el layout común de los sliders del Control Center: ícono (con
// hover opcional vía iconButton), track con fill/thumb animados y label con %.
// Normaliza value/minValue/maxValue a una fracción 0..1 para fill/thumb.
Item {
    id: root
    width: parent.width; height: 36

    // API pública
    required property real value
    property real minValue: 0
    property real maxValue: 100
    signal setValue(real v)

    property string icon: ""
    property color iconColor: Theme.accent
    property bool iconButton: false
    signal iconClicked()

    property string label: ""
    property color labelColor: Theme.muted1
    property bool muted: false

    // Fracción normalizada 0..1 (bindable, usada en fill y thumb)
    property real frac: (root.value - root.minValue) / (root.maxValue - root.minValue)

    // Ícono
    Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: 8
        Rectangle {
            width: 28; height: 28; radius: 8
            color: (root.iconButton && hov.containsMouse) ? Theme.surface3 : Theme.surface2
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: root.icon
                font.pixelSize: 14
                color: root.iconColor
            }
            MouseArea {
                id: hov; anchors.fill: parent
                hoverEnabled: root.iconButton; enabled: root.iconButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }
    }

    // Track
    Item {
        anchors {
            left: parent.left; leftMargin: 44
            right: parent.right; rightMargin: 44
            verticalCenter: parent.verticalCenter
        }
        height: 20
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 4; radius: 2; color: Theme.surface3
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(8, root.frac * track.width)
            height: 4; radius: 2
            color: root.muted ? Theme.muted2 : Theme.accent
            Behavior on width { NumberAnimation { duration: 80 } }
        }
        Rectangle {
            x: Math.min(root.frac * track.width - 6, track.width - 12)
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; radius: 6
            color: root.muted ? Theme.muted2 : Theme.accent
            Behavior on x { NumberAnimation { duration: 80 } }
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onPositionChanged: mouse => {
                if (mouse.buttons & Qt.LeftButton) {
                    var frac = Math.max(0, Math.min(1, mouse.x / track.width))
                    root.setValue(root.minValue + frac * (root.maxValue - root.minValue))
                }
            }
            onClicked: mouse => {
                var frac = Math.max(0, Math.min(1, mouse.x / track.width))
                root.setValue(root.minValue + frac * (root.maxValue - root.minValue))
            }
        }
    }

    // Label
    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.label
        font.pixelSize: 10
        color: root.muted ? Theme.muted2 : root.labelColor
        width: 36; horizontalAlignment: Text.AlignRight
    }
}

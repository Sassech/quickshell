pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../Components"

// ── Tarjeta de control rápido reutilizable (grid 2×3 en CcQuickToggles) ────────
// WiFi, Bluetooth, Power, Audio, Battery y Language comparten este esqueleto;
// cada instancia aporta solo sus bindings de datos (active, icon, title, subtitle).
Rectangle {
    id: root

    // ── API pública ───────────────────────────────────────────────────────────
    required property bool active
    required property var onClicked

    property string icon
    property color iconColor: Theme.accent
    property string title
    property string subtitle
    property color subtitleColor: Theme.muted1

    // ── Estado interno (hover) ────────────────────────────────────────────────
    property bool hov: false

    width: (parent.width - 6) / 2; height: 52; radius: 10
    color: hov ? Theme.surface3
         : (root.active
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                : Theme.surface2)
    Behavior on color { ColorAnimation { duration: 100 } }

    // ── Stripe de acento cuando la tarjeta está activa ────────────────────────
    Rectangle {
        visible: root.active
        width: 3; height: 24; radius: 2
        anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
        color: Theme.accent
    }

    // ── Contenido: icono + título/subtítulo ───────────────────────────────────
    RowLayout {
        anchors {
            fill: parent
            leftMargin: root.active ? 14 : 10
            rightMargin: 10
        }
        spacing: 8

        Text {
            text: root.icon
            font.pixelSize: 18
            color: root.iconColor
        }

        Column {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: root.title
                font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                width: parent.width
                text: root.subtitle
                font.pixelSize: 9
                color: root.subtitleColor
                elide: Text.ElideRight
            }
        }
    }

    // ── Interacción ───────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: root.hov = true
        onExited:  root.hov = false
        onClicked: root.onClicked()
    }
}

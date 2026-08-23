pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import "../Components"

// Widget de System Tray usando el protocolo StatusNotifierItem (SNI)
// Detecta automáticamente apps como Discord, Spotify, Telegram, etc.
// Los íconos Passive se ocultan por defecto y se revelan con el botón ">".
Item {
    id: root

    required property var panelWindow
    property int iconSize: 20
    property int spacing: 4

    // Expanded = mostrar también los íconos Passive
    property bool expanded: false

    implicitWidth: trayRow.implicitWidth + (expandBtn.visible ? expandBtn.width + root.spacing : 0)
    implicitHeight: 28

    // Acceder a SystemTray.items activa el tracking D-Bus automáticamente
    property var _trayItems: SystemTray.items

    // ── Hay al menos un ícono Passive? ───────────────────────────────────
    property bool _hasPassive: {
        // qmllint disable missing-property
        for (let i = 0; i < SystemTray.items.length; i++) {
            if (SystemTray.items[i].status === Status.Passive) return true
        }
        // qmllint enable missing-property
        return false
    }

    Row {
        id: trayRow
        anchors {
            verticalCenter: parent.verticalCenter
            right: expandBtn.visible ? expandBtn.left : parent.right
            rightMargin: expandBtn.visible ? root.spacing : 0
        }
        spacing: root.spacing

        Repeater {
            model: SystemTray.items

            delegate: TrayIcon {
                required property var modelData
                trayItem: modelData
                size: root.iconSize
                panelWindow: root.panelWindow

                // Ocultar Passive cuando no está expandido
                opacity: (root.expanded || modelData.status !== Status.Passive) ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }

    // ── Botón expandir/colapsar íconos Passive ───────────────────────────
    Text {
        id: expandBtn
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        visible: root._hasPassive
        text: root.expanded ? "" : ""
        font.pixelSize: 10
        color: expandHover.containsMouse ? Theme.text : Theme.muted2
        Behavior on color { ColorAnimation { duration: 100 } }

        MouseArea {
            id: expandHover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Placeholder cuando no hay íconos visibles ─────────────────────────
    Text {
        anchors.centerIn: parent
        text: "󰒲"
        font.pixelSize: 14
        color: Theme.muted2
        visible: !root._trayItems || root._trayItems.length === 0
        opacity: 0.5
    }
}

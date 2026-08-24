import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../Components"

Rectangle {
    id: root

    required property var trayItem
    required property var panelWindow
    property int size: 20

    width: size
    height: size
    radius: 4

    // Color de fondo según estado
    property bool _needsAttention: root.trayItem.status === Status.NeedsAttention

    color: ma.containsMouse ? Theme.surfaceHover : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    scale: ma.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: 50 } }

    // Glow pulsante cuando NeedsAttention
    Rectangle {
        id: attentionGlow
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 6
        radius: parent.radius + 3
        color: "transparent"
        border.color: Theme.warning
        border.width: 1.5
        opacity: 0
        visible: root._needsAttention

        SequentialAnimation on opacity {
            running: root._needsAttention
            loops: Animation.Infinite
            NumberAnimation { to: 0.85; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0;    duration: 700; easing.type: Easing.InOutSine }
        }
    }

    // Resolver icono con soporte para ?path= custom icons Algunas apps (ej. Spotify) envían iconos como "image://icon/spotify-
    // linux-32?path=/usr/share/spotify/icons" Quickshell no soporta custom icon paths, así que lo resolvemos manualmente.
    property string _resolvedIcon: {
        const raw = root.trayItem.icon ?? ""
        if (raw.includes("?path=")) {
            const parts = raw.split("?path=")
            // Strip "image://icon/" prefix si existe
            let name = parts[0].replace(/^image:\/\/icon\//, "")
            const basePath = parts[1]
            return "file://" + basePath + "/" + name + ".png"
        }
        return raw
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size - 4
        source: root._resolvedIcon
        asynchronous: true
    }

    // Tooltip
    ToolTip {
        id: tooltip
        visible: ma.containsMouse && (root.trayItem.tooltipTitle !== "" || root.trayItem.title !== "")
        delay: 600
        text: {
            const title = root.trayItem.tooltipTitle || root.trayItem.title || ""
            const desc  = root.trayItem.tooltipDescription ?? ""
            return desc !== "" ? title + "\n" + desc : title
        }
        contentItem: Text {
            text: tooltip.text
            color: Theme.text
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
        background: Rectangle {
            color: Theme.cardBg3
            border.color: Theme.borderSubtle
            border.width: 1
            radius: 4
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: mouse => {
            // Coordenadas relativas al PanelWindow (scene root)
            const pos = root.mapToItem(null, 0, 0)

            if (mouse.button === Qt.RightButton) {
                // Context menu nativo vía protocolo SNI
                if (root.trayItem.hasMenu) {
                    root.trayItem.display(root.panelWindow, pos.x, pos.y)
                }
            } else if (mouse.button === Qt.MiddleButton) {
                // Secondary activation (ej. Steam: pausa/resume descarga)
                root.trayItem.secondaryActivate()
            } else {
                // Left click: si el item solo tiene menú, mostrarlo; si no, activarlo
                if (root.trayItem.onlyMenu && root.trayItem.hasMenu) {
                    root.trayItem.display(root.panelWindow, pos.x, pos.y)
                } else {
                    root.trayItem.activate()
                }
            }
        }

        onWheel: wheel => {
            // Scroll: ej. volumen en mixer, brillo, etc.
            const horizontal = wheel.angleDelta.x !== 0
            const delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
            root.trayItem.scroll(delta, horizontal)
        }
    }
}

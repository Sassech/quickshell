import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    required property var trayItem
    required property var panelWindow
    property int size: 20

    width: size
    height: size
    radius: 4
    color: ma.containsMouse ? "#22ffffff" : "transparent"

    Behavior on color { ColorAnimation { duration: 100 } }

    scale: ma.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: 50 } }

    // ── Resolver icono con soporte para ?path= custom icons ─────────
    // Algunas apps (ej. Spotify) envían iconos como "image://icon/spotify-linux-32?path=/usr/share/spotify/icons"
    // Quickshell no soporta custom icon paths, así que lo resolvemos manualmente.
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

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // Context menu nativo vía protocolo SNI
                if (root.trayItem.hasMenu) {
                    root.trayItem.display(root.panelWindow, root.x, root.y)
                }
            } else {
                // Left click: si el item solo tiene menú, mostrarlo; si no, activarlo
                if (root.trayItem.onlyMenu && root.trayItem.hasMenu) {
                    root.trayItem.display(root.panelWindow, root.x, root.y)
                } else {
                    root.trayItem.activate(root.x, root.y)
                }
            }
        }
    }
}

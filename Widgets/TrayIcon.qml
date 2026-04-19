import QtQuick

Rectangle {
    id: root

    required property var trayItem
    property int size: 20

    width: size
    height: size
    radius: 4
    color: "transparent"

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

    Image {
        anchors.centerIn: parent
        width: root.size - 4
        height: root.size - 4
        source: root._resolvedIcon
        sourceSize: Qt.size(root.size - 4, root.size - 4)
    }
}

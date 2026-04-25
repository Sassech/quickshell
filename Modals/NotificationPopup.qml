import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    // Tamaño de la tarjeta
    implicitWidth:  400
    implicitHeight: 110

    // Anclar top-right, debajo de la barra
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top:   true
        right: true
    }
    // Margen desde la barra
    margins {
        top:   25
        right: 25
    }

    mask: Region { item: card }

    // ── API pública ───────────────────────────────────────────────────
    property string notifTitle:   ""
    property string notifBody:    ""
    property string notifIcon:    "☕"
    property bool   notifActive:  false
    property bool   notifIsMedia: false

    function show(title, body, icon, active, isMedia) {
        // Cancelar cualquier cierre en progreso
        hideAnim.stop()
        dismissTimer.stop()

        notifTitle   = title
        notifBody    = body
        notifIcon    = icon
        notifActive  = active
        notifIsMedia = isMedia ?? false
        root.visible = true
        card.x = 420
        slideAnim.restart()
        dismissTimer.restart()
    }

    // ── Dismiss automático ────────────────────────────────────────────
    Timer {
        id: dismissTimer
        interval: 4000
        onTriggered: hideAnim.start()
    }

    // ── Animaciones ───────────────────────────────────────────────
    NumberAnimation {
        id: slideAnim
        target:   card
        property: "x"
        from:     420
        to:       0
    duration: 200
    easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnim
        target:   card
        property: "x"
        from:     0
        to:       420
    duration: 200
    easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── Tarjeta ────────────────────────────────────────────────────
    Rectangle {
        id: card
        width:  400
        height: 100
        radius: 12
        color:  Theme.base
        border.color: root.notifIsMedia ? Theme.accent
                     : root.notifActive  ? Theme.warning
                     : Theme.muted3
        border.width: 1
        clip: true
        y: 0

        // Franja de acento izquierda
        Rectangle {
            width:  4
            height: parent.height
            radius: 2
            color:  root.notifIsMedia ? Theme.accent
                  : root.notifActive  ? Theme.warning
                  : Theme.muted3
        }

        // Gradiente sutil
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.12
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.notifIsMedia ? Theme.accent
                                                    : root.notifActive  ? Theme.warning
                                                    : Theme.muted3 }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Row {
            anchors {
                left:           parent.left
                leftMargin:     16
                verticalCenter: parent.verticalCenter
            }
            spacing: 14

            // Icono: imagen real si está disponible, emoji como fallback
            Item {
                width:  56
                height: 56
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: notifIconImg
                    anchors.fill: parent
                    source: {
                        const ic = root.notifIcon
                        if (!ic || ic.length === 0) return ""
                        // Ruta absoluta directa
                        if (ic.startsWith("/") || ic.startsWith("file://")
                                || ic.startsWith("http://") || ic.startsWith("https://")) return ic
                        // Icono themed con custom path (ej: "image://icon/spotify-linux-32?path=/usr/share/spotify/icons")
                        if (ic.includes("?path=")) {
                            const parts = ic.split("?path=")
                            const name = parts[0].replace(/^image:\/\/icon\//, "")
                            return "file://" + parts[1] + "/" + name + ".png"
                        }
                        // Icono themed estándar
                        if (ic.length > 4) return "image://theme/" + ic
                        return ""
                    }
                    fillMode:    Image.PreserveAspectFit
                    smooth:      true
                    mipmap:      true
                    visible:     status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text:           root.notifIcon.length > 0 ? root.notifIcon : "🔔"
                    font.pixelSize: 28
                    visible:        notifIconImg.status !== Image.Ready
                }
            }

            Column {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
// Tamaño de la letra de la notificación
                Text {
                    text:           root.notifTitle
                    color:          Theme.text
                    font.pixelSize: 20
                    font.bold:      true
                    visible:        root.notifTitle.length > 0
                }

                Text {
                    text:           root.notifBody
                    color:          Theme.muted1
                    font.pixelSize: 18
                    width:          280
                    wrapMode:       Text.WordWrap
                }
            }
        }

        // Botón cerrar
        MouseArea {
            anchors.top:     parent.top
            anchors.right:   parent.right
            anchors.margins: 8
            width:  16
            height: 16
            cursorShape: Qt.PointingHandCursor
            onClicked: hideAnim.start()

            Text {
                anchors.centerIn: parent
                text:  "✕"
                color: Theme.muted3
                font.pixelSize: 10
            }
        }

        // Click en body — feedback visual con opacidad
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hideAnim.start()

            // Overlay de hover sutil
            Rectangle {
                anchors.fill: parent
                radius: card.radius
                color: Theme.hover
                visible: parent.containsMouse
            }
        }
    }
}

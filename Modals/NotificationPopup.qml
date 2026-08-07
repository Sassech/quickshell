// qmllint disable uncreatable-type
import QtQuick
import Quickshell.Widgets
import "../Components"
import "./overlays"

// NotificationPopup — toast de notificación. Hereda OverlayWindow (window
// anclado a esquina + slide/fade + auto-hide + mask). El contenido custom
// (borde condicional, franja, gradiente, hover, botón cerrar) ancla a
// parent (contentArea, que llena la tarjeta completa).
OverlayWindow {
    id: root

    // ── Config (contrato con shell.qml) ──────────────────────────────────
    property int    dismissMs:   4000   // compat: autoHideMs
    property int    marginTop:   25     // compat: topOffset
    property int    marginRight: 25     // compat: rightOffset
    property int    popupWidth:  400    // compat: overlayWidth
    property string position:    "top-right"   // compat: corner

    // ── Mapeo al template ────────────────────────────────────────────────
    corner:         root.position
    overlayWidth:   root.popupWidth
    overlayHeight:  100
    autoHideMs:     root.dismissMs
    borderColor:    root.notifIsMedia ? Theme.accent
                  : root.notifActive  ? Theme.warning
                  : Theme.muted3
    showAccent:     false    // la franja del popup es de 4px condicional, no la del template
    restingOpacity: 1.0      // el popup no queda translúcido

    // ── Contenido de la notificación ──────────────────────────────────────
    property string notifTitle:   ""
    property string notifBody:    ""
    property string notifIcon:    "☕"
    property bool   notifActive:  false
    property bool   notifIsMedia: false

    function show(title, body, icon, active, isMedia) {
        notifTitle   = title
        notifBody    = body
        notifIcon    = icon
        notifActive  = active
        notifIsMedia = isMedia ?? false
        root._animateIn()
    }

    // ── Franja de acento izquierda (4px, condicional) ───────────────────
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 2
        color: root.notifIsMedia ? Theme.accent
             : root.notifActive  ? Theme.warning
             : Theme.muted3
    }

    // ── Gradiente sutil ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: root.card.radius
        opacity: 0.12
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.notifIsMedia ? Theme.accent
                                                                : root.notifActive  ? Theme.warning
                                                                : Theme.muted3 }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Click en body con hover ─────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.hide()

        Rectangle {
            anchors.fill: parent
            radius: root.card.radius
            color: Theme.hover
            visible: parent.containsMouse
        }
    }

    // ── Contenido principal (ícono + texto) ─────────────────────────────
    Row {
        anchors {
            left: parent.left
            leftMargin: 16
            verticalCenter: parent.verticalCenter
        }
        spacing: 14

        Item {
            width: 56
            height: 56
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                id: notifIconImg
                anchors.fill: parent
                implicitSize: 56
                mipmap: true
                source: {
                    const ic = root.notifIcon
                    if (!ic || ic.length === 0) return ""
                    if (ic.startsWith("/") || ic.startsWith("file://")
                            || ic.startsWith("http://") || ic.startsWith("https://")) return ic
                    if (ic.includes("?path=")) {
                        const parts = ic.split("?path=")
                        const name = parts[0].replace(/^image:\/\/icon\//, "")
                        return "file://" + parts[1] + "/" + name + ".png"
                    }
                    if (ic.startsWith("image://theme/")) return ic.replace("image://theme/", "")
                    if (ic.length > 4) return ic
                    return ""
                }
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: root.notifIcon.length > 0 ? root.notifIcon : "🔔"
                font.pixelSize: 28
                visible: notifIconImg.status !== Image.Ready
            }
        }

        Column {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            readonly property int _textWidth: root.popupWidth - 56 - 16 - 14 - 34

            Text {
                text: root.notifTitle
                color: Theme.text
                font.pixelSize: 20
                font.bold: true
                visible: root.notifTitle.length > 0
            }

            Text {
                text: root.notifBody
                color: Theme.muted1
                font.pixelSize: 18
                width: parent._textWidth
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Botón cerrar ─────────────────────────────────────────────────────
    MouseArea {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 16
        height: 16
        cursorShape: Qt.PointingHandCursor
        onClicked: root.hide()

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Theme.muted3
            font.pixelSize: 10
        }
    }
}

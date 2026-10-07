// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../Components"
import "./overlays"

// NotificationPopup — toast de notificación. Hereda OverlayWindow (window anclado a esquina + slide/fade + auto-hide + mask). El contenido
// custom (borde condicional, franja, gradiente, hover, botón cerrar) ancla a parent (contentArea, que llena la tarjeta completa).
OverlayWindow {
    id: root

    // Config (contrato con shell.qml)
    property int    dismissMs:   4000   // compat: autoHideMs
    property int    marginTop:   25     // compat: topOffset
    property int    marginRight: 25     // compat: rightOffset
    property int    popupWidth:  400    // compat: overlayWidth
    property string position:    "top-right"   // compat: corner

    // Mapeo al template
    corner:         root.position
    overlayWidth:   root.popupWidth
    // Altura dinámica acotada: contenido + padding, min 100 max 180 colapsado.
    // Expandido permite hasta 380 para mensaje completo sin tapar la pantalla.
    // Con acciones se suma la fila extra de botones.
    overlayHeight: Math.min(root.bodyExpanded ? 380 : 180, Math.max(100, contentRow.implicitHeight + 32 + (root.notifActions.length > 0 ? 42 : 0)))
    autoHideMs:     root.dismissMs
    borderColor:    root.notifIsMedia ? Theme.accent
                  : root.notifActive  ? Theme.warning
                  : Theme.muted3
    showAccent:     false    // la franja del popup es de 4px condicional, no la del template
    restingOpacity: 1.0      // el popup no queda translúcido

    // Contenido de la notificación
    property string notifTitle:   ""
    property string notifBody:    ""
    property string notifIcon:    "☕"
    property bool   notifActive:  false
    property bool   notifIsMedia: false
    property var    notifActions: []   // NotificationAction[] (id, text, invoke())
    property bool   bodyExpanded: false  // colapsado (2 líneas + ...) vs expandido (mensaje completo)

    function show(title, body, icon, active, isMedia, actions) {
        notifTitle   = title
        notifBody    = body
        notifIcon    = icon
        notifActive  = active
        notifIsMedia = isMedia ?? false
        notifActions = actions ?? []
        bodyExpanded = false
        // Crítica/urgente → no se autocierra, el usuario la cierra a mano.
        root.autoHideSuppressed = active
        root._animateIn()
    }

    // Acción "default" del spec freedesktop: click en el cuerpo la invoca en
    // vez de mostrarse como botón aparte.
    function _invokeDefaultAction() {
        const def = root.notifActions.find(a => a.identifier === "default")
        if (def) def.invoke()
    }

    // Franja izquierda removida por diseño

    // Gradiente sutil
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

    // Click en body con hover
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root._invokeDefaultAction()
            root.hide()
        }

        Rectangle {
            anchors.fill: parent
            radius: root.card.radius
            color: Theme.hover
            visible: parent.containsMouse
        }
    }

    // Contenido principal (ícono + texto) Con botones de acción el contenido se ancla arriba para dejar libre el fondo (evita que el texto y los
    // botones se superpongan); sin acciones queda centrado verticalmente como antes.
    Row {
        id: contentRow
        anchors {
            left: parent.left
            leftMargin: 16
            verticalCenter: root.notifActions.length > 0 ? undefined : parent.verticalCenter
            top: root.notifActions.length > 0 ? parent.top : undefined
            topMargin: 16
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
                width: parent._textWidth
                maximumLineCount: 1
                elide: Text.ElideRight
                visible: root.notifTitle.length > 0
            }

            Text {
                id: bodyText
                text: root.notifBody
                color: Theme.muted1
                font.pixelSize: 18
                width: parent._textWidth
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: root.bodyExpanded ? 10 : 2
                elide: root.bodyExpanded ? Text.ElideNone : Text.ElideRight
            }

            // Toggle ver más / ver menos: solo cuando el cuerpo está truncado o expandido.
            // MouseArea propio (hermano superior al fondo) para no disparar hide()/default-action.
            Text {
                text: root.bodyExpanded ? "ver menos" : "ver más…"
                color: Theme.accent
                font.pixelSize: 13
                font.underline: toggleHover.containsMouse
                visible: root.notifBody.length > 0 && (bodyText.truncated || root.bodyExpanded)

                MouseArea {
                    id: toggleHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.bodyExpanded = !root.bodyExpanded
                        // Expandido se queda fijo hasta cierre manual para dar tiempo a leer.
                        root.autoHideSuppressed = root.notifActive || root.bodyExpanded
                    }
                }
            }
        }
    }

    // Botones de acción (NotificationAction[], excluye "default")
    // Máximo 3 visibles, alineados a derecha, con ancho acotado y elide.
    Row {
        visible: notifActionsRepeater.count > 0
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: 10
            leftMargin: 14
            rightMargin: 14
        }
        layoutDirection: Qt.RightToLeft
        spacing: 8

        Repeater {
            id: notifActionsRepeater
            model: root.notifActions.filter(a => a.identifier !== "default").slice(0, 3)

            Rectangle {
                id: actionBtn
                required property var modelData
                radius: 6
                color: actionMouse.containsMouse ? Theme.hover : Theme.cardBg3
                border.color: Theme.muted3
                border.width: 1
                implicitWidth: actionLabel.width + 20
                implicitHeight: 26
                clip: true

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    width: Math.min(100, implicitWidth)
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    text: actionBtn.modelData.text
                    color: Theme.text
                    font.pixelSize: 13
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        actionBtn.modelData.invoke()
                        root.hide()
                    }
                }
            }
        }
    }

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

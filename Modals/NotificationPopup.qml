import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    // ── Config properties (set from shell.qml) ────────────────────────────
    property int    dismissMs:   4000
    property int    animInMs:    200
    property int    animOutMs:   200
    property int    marginTop:   25
    property int    marginRight: 25
    property int    popupWidth:  400
    property string position:    "top-right"

    // ── Computed layout ───────────────────────────────────────────────────
    readonly property int _cardHeight:   100
    readonly property int _slideOffset:  popupWidth + marginRight + 20

    implicitWidth:  popupWidth
    implicitHeight: _cardHeight + 10

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top:    position === "top-right"    || position === "top-left"
        bottom: position === "bottom-right" || position === "bottom-left"
        right:  position === "top-right"    || position === "bottom-right"
        left:   position === "top-left"     || position === "bottom-left"
    }
    margins {
        top:    position === "top-right"    || position === "top-left"    ? marginTop    : 0
        bottom: position === "bottom-right" || position === "bottom-left" ? marginTop    : 0
        right:  position === "top-right"    || position === "bottom-right" ? marginRight : 0
        left:   position === "top-left"     || position === "bottom-left"  ? marginRight : 0
    }

    mask: Region { item: card }

    // ── API pública ───────────────────────────────────────────────────────
    property string notifTitle:   ""
    property string notifBody:    ""
    property string notifIcon:    "☕"
    property bool   notifActive:  false
    property bool   notifIsMedia: false

    function show(title, body, icon, active, isMedia) {
        hideAnim.stop()
        dismissTimer.stop()

        notifTitle   = title
        notifBody    = body
        notifIcon    = icon
        notifActive  = active
        notifIsMedia = isMedia ?? false
        root.visible = true
        card.x = _slideOffset
        slideAnim.restart()
        dismissTimer.restart()
    }

    // ── Dismiss automático ────────────────────────────────────────────────
    Timer {
        id: dismissTimer
        interval: root.dismissMs
        onTriggered: hideAnim.start()
    }

    // ── Animaciones ───────────────────────────────────────────────────────
    NumberAnimation {
        id: slideAnim
        target:   card
        property: "x"
        from:     root._slideOffset
        to:       0
        duration: root.animInMs
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnim
        target:   card
        property: "x"
        from:     0
        to:       root._slideOffset
        duration: root.animOutMs
        easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── Tarjeta ────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        width:  root.popupWidth
        height: root._cardHeight
        radius: 12
        color:  Theme.cardBg3
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

            // Ícono
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
                        if (ic.startsWith("/") || ic.startsWith("file://")
                                || ic.startsWith("http://") || ic.startsWith("https://")) return ic
                        if (ic.includes("?path=")) {
                            const parts = ic.split("?path=")
                            const name = parts[0].replace(/^image:\/\/icon\//, "")
                            return "file://" + parts[1] + "/" + name + ".png"
                        }
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
                // Ancho disponible: card - iconWidth - leftMargin - spacing - rightPadding
                readonly property int _textWidth: root.popupWidth - 56 - 16 - 14 - 34

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
                    width:          parent._textWidth
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

        // Click en body
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hideAnim.start()

            Rectangle {
                anchors.fill: parent
                radius: card.radius
                color: Theme.hover
                visible: parent.containsMouse
            }
        }
    }
}

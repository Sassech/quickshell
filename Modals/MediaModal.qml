import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../Components"

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // ── Active player ─────────────────────────────────────────────────────────
    property MprisPlayer player: {
        var playingOther = null
        var playingMpd   = null
        var first        = null
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (!first) first = p
            var isMpd = (p.identity ?? "").toLowerCase().includes("music player daemon")
            if (p.playbackState === MprisPlaybackState.Playing) {
                if (isMpd) { if (!playingMpd) playingMpd = p }
                else       { if (!playingOther) playingOther = p }
            }
        }
        return playingOther ?? playingMpd ?? first ?? null
    }

    property bool hasPlayer: player !== null
    property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    // ── Position tracking ─────────────────────────────────────────────────────
    property real trackedPosition: 0
    property real trackLen: hasPlayer ? (player.trackLength ?? 0) : 0
    property int  _syncCounter: 0

    function syncPosition() {
        if (hasPlayer && player.position !== undefined)
            trackedPosition = player.position
    }

    onVisibleChanged:   { if (visible) { syncPosition(); card.opacity = 1 } }
    onIsPlayingChanged: {
        syncPosition()
        positionTimer.running = visible && isPlaying
    }

    Connections {
        target: root.hasPlayer ? root.player : null
        function onTrackTitleChanged() { root.syncPosition(); root._syncCounter = 0 }
    }

    Timer {
        id: positionTimer
        interval: 1000
        running: root.visible && root.isPlaying
        repeat: true
        onTriggered: {
            root.trackedPosition += 1000
            root._syncCounter++
            if (root._syncCounter >= 10) {
                root._syncCounter = 0
                root.syncPosition()
            }
        }
    }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var totalSec = Math.floor(ms / 1000)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" + sec : sec)
    }

    // ── Backdrop ──────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // ── Mini-player card — pegado a la topbar ─────────────────────────────────
    Rectangle {
        id: card

        // Centrado horizontal, justo debajo de la topbar (30px)
        anchors.top:              parent.top
        anchors.topMargin:        34   // topbar 30px + 4px gap
        anchors.horizontalCenter: parent.horizontalCenter

        width:  520
        height: 68
        radius: 12

        color:        Theme.cardBg
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        // Fade-in al abrir
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // Sombra sutil via rectángulo detrás
        Rectangle {
            anchors.fill:    parent
            anchors.margins: -1
            radius:          parent.radius + 1
            color:           "transparent"
            border.color:    Qt.rgba(0, 0, 0, 0.40)
            border.width:    1
            z:               -1
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        RowLayout {
            anchors {
                fill:           parent
                leftMargin:     14
                rightMargin:    12
                topMargin:      10
                bottomMargin:   10
            }
            spacing: 12

            // ── Artwork circular ──────────────────────────────────────────────
            Rectangle {
                width:  48
                height: 48
                radius: 24
                color:  Theme.surface2
                clip:   true
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text:            "♪"
                    font.pixelSize:  20
                    color:           Theme.muted2
                    visible:         !artImage.visible
                }

                Image {
                    id:       artImage
                    anchors.fill: parent
                    source:   root.hasPlayer && (root.player.trackArtUrl ?? "") !== ""
                                  ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible:  status === Image.Ready && source !== ""

                    Behavior on source {
                        SequentialAnimation {
                            NumberAnimation { target: artImage; property: "opacity"; to: 0.0; duration: 120 }
                            NumberAnimation { target: artImage; property: "opacity"; to: 1.0; duration: 120 }
                        }
                    }
                }
            }

            // ── Info + barra de progreso ──────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth:  true
                Layout.alignment:  Qt.AlignVCenter
                spacing: 4

                // Título y artista
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        id: titleText
                        Layout.fillWidth: true
                        text:             root.hasPlayer ? (root.player.trackTitle ?? "—") : "Sin reproducción"
                        color:            Theme.text
                        font.pixelSize:   12
                        font.weight:      Font.DemiBold
                        elide:            Text.ElideRight

                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: titleText; property: "opacity"; to: 0; duration: 80 }
                                NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: 100 }
                            }
                        }
                    }

                    Text {
                        text:           root.hasPlayer ? (root.player.trackArtist ?? "") : ""
                        color:          Theme.muted1
                        font.pixelSize: 11
                        elide:          Text.ElideRight
                        visible:        text !== ""
                        Layout.maximumWidth: 140
                    }
                }

                // Barra de progreso + tiempos
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.hasPlayer && root.trackLen > 0

                    Text {
                        text:           root.formatTime(root.trackedPosition)
                        color:          Theme.muted2
                        font.pixelSize: 10
                        font.family:    "monospace"
                    }

                    // Barra clickeable
                    Item {
                        Layout.fillWidth: true
                        height: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            enabled:      root.hasPlayer && root.trackLen > 0
                            onClicked: function(mouse) {
                                var ratio = mouse.x / width
                                root.player.position = ratio * root.trackLen
                                root.syncPosition()
                                root._syncCounter = 0
                            }
                        }

                        Item {
                            anchors {
                                left:            parent.left
                                right:           parent.right
                                verticalCenter:  parent.verticalCenter
                            }
                            height: 4

                            Rectangle {
                                anchors.fill: parent
                                radius:       2
                                color:        Theme.surface3
                            }

                            Rectangle {
                                id: progressFill
                                width: {
                                    if (root.trackLen <= 0) return 0
                                    return Math.min(root.trackedPosition / root.trackLen, 1.0) * parent.width
                                }
                                height: parent.height
                                radius: 2
                                color:  Theme.accent

                                Behavior on width {
                                    NumberAnimation { duration: 800; easing.type: Easing.Linear }
                                }
                            }
                        }
                    }

                    Text {
                        text:           root.formatTime(root.trackLen)
                        color:          Theme.muted2
                        font.pixelSize: 10
                        font.family:    "monospace"
                    }
                }
            }

            // ── Controles ─────────────────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                // Anterior
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color:   prevHover.hovered ? Theme.hover : "transparent"
                    opacity: root.hasPlayer && (root.player.canGoPrevious ?? false) ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: prevHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      root.hasPlayer && (root.player.canGoPrevious ?? false)
                        onClicked:    { root.player.previous(); root.syncPosition() }
                    }
                    Text {
                        anchors.centerIn: parent
                        text:             "⏮"
                        font.pixelSize:   14
                        color:            Theme.text
                    }
                }

                // Play / Pause
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color:   root.isPlaying ? Theme.accentSurface : Theme.surface3
                    opacity: root.hasPlayer ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: playHover }
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: playHover.hovered ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      root.hasPlayer
                        onClicked:    root.player.togglePlaying()
                    }
                    Text {
                        anchors.centerIn: parent
                        text:             root.isPlaying ? "⏸" : "▶"
                        font.pixelSize:   16
                        color:            root.isPlaying ? Theme.accent : Theme.text
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Siguiente
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color:   nextHover.hovered ? Theme.hover : "transparent"
                    opacity: root.hasPlayer && (root.player.canGoNext ?? false) ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: nextHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      root.hasPlayer && (root.player.canGoNext ?? false)
                        onClicked:    { root.player.next(); root.syncPosition() }
                    }
                    Text {
                        anchors.centerIn: parent
                        text:             "⏭"
                        font.pixelSize:   14
                        color:            Theme.text
                    }
                }
            }

            // ── Botón cerrar ──────────────────────────────────────────────────
            Rectangle {
                width: 22; height: 22; radius: 11
                color: closeHover.hovered ? Theme.hover2 : "transparent"
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 100 } }

                HoverHandler { id: closeHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.visible = false
                }
                Text {
                    anchors.centerIn: parent
                    text:             "✕"
                    font.pixelSize:   11
                    color:            Theme.muted1
                }
            }
        }
    }
}

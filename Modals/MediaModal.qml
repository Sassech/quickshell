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

    // ── Active player ────────────────────────────────────────────────────────
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

    // ── Position tracking optimizado ────────────────────────────────────────
    property real trackedPosition: 0
    property real trackLen: hasPlayer ? (player.trackLength ?? 0) : 0

    function syncPosition() {
        if (hasPlayer && player.position !== undefined) {
            trackedPosition = player.position
        }
    }

    onVisibleChanged:  { if (visible) syncPosition() }
    onIsPlayingChanged: {
        syncPosition()
        if (!isPlaying) positionTimer.running = false
        else positionTimer.running = true
    }

    // Reset posición al cambiar de canción
    Connections {
        target: root.hasPlayer ? root.player : null
        function onTrackTitleChanged() { 
            root.syncPosition()
            root._syncCounter = 0
        }
    }

    // Timer optimizado: solo corre cuando está visible y reproduciendo
    property int _syncCounter: 0

    Timer {
        id: positionTimer
        interval: 1000
        running: root.visible && root.isPlaying
        repeat: true
        onTriggered: {
            root.trackedPosition += 1000
            root._syncCounter++
            // Sincronizar cada 10s para evitar drift
            if (root._syncCounter >= 10) {
                root._syncCounter = 0
                root.syncPosition()
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var totalSec = Math.floor(ms / 1000)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" + sec : sec)
    }

    // ── Backdrop ────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // ── Card ────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
        implicitHeight: cardLayout.implicitHeight + 36
        height: implicitHeight
        radius: 14
        color: Theme.cardBg

        layer.enabled: true
        layer.effect: null

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            z: -1
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: cardLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 18
            }
            spacing: 14

            // ── Cabecera ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Now Playing"
                    color: Theme.muted2
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 1.0
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 22; height: 22
                    radius: 11
                    color: closeHover.hovered ? Theme.hover2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: closeHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.muted1
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // ── Portada + Info ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    width: 96
                    height: 96
                    radius: 10
                    color: Theme.surface2
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        font.pixelSize: 38
                        color: Theme.muted2
                        visible: !artImage.visible
                    }

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: root.hasPlayer && (root.player.trackArtUrl ?? "") !== "" 
                            ? root.player.trackArtUrl 
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready && source !== ""

                        Behavior on source {
                            SequentialAnimation {
                                NumberAnimation { target: artImage; property: "opacity"; to: 0.0; duration: 150 }
                                NumberAnimation { target: artImage; property: "opacity"; to: 1.0; duration: 150 }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        id: titleText
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.trackTitle ?? "—") : "No media"
                        color: Theme.text
                        font.pixelSize: 15
                        font.weight: Font.SemiBold
                        elide: Text.ElideRight

                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: titleText; property: "opacity"; to: 0.0; duration: 100 }
                                NumberAnimation { target: titleText; property: "opacity"; to: 1.0; duration: 150 }
                            }
                        }
                    }

                    Text {
                        id: artistText
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.trackArtist ?? "") : ""
                        color: Theme.muted1
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Text {
                        id: albumText
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.trackAlbum ?? "") : ""
                        color: Theme.muted2
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Item { height: 2 }

                    Rectangle {
                        width: playerBadgeText.implicitWidth + 10
                        height: 17
                        radius: 4
                        color: Theme.accentSurface
                        visible: root.hasPlayer && (root.player.identity ?? "") !== ""

                        Text {
                            id: playerBadgeText
                            anchors.centerIn: parent
                            text: root.hasPlayer ? (root.player.identity ?? "") : ""
                            color: Theme.accent
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // ── Barra de progreso ─────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                visible: root.hasPlayer && root.trackLen > 0

                Item {
                    Layout.fillWidth: true
                    height: 14

                    // Hit area amplia para facilitar click
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer && root.trackLen > 0
                        onClicked: function(mouse) {
                            var ratio = mouse.x / width
                            root.player.position = ratio * root.trackLen
                            root.syncPosition()
                            root._syncCounter = 0
                        }
                    }

                    // Barra visual (centrada en el hit area)
                    Item {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        height: 4

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: Theme.surface3
                        }

                        Rectangle {
                            id: progressFill
                            width: {
                                if (root.trackLen <= 0) return 0
                                var ratio = Math.min(root.trackedPosition / root.trackLen, 1.0)
                                return ratio * parent.width
                            }
                            height: parent.height
                            radius: 2
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation { duration: 800; easing.type: Easing.Linear }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatTime(root.trackedPosition)
                        color: Theme.muted2
                        font.pixelSize: 10
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.formatTime(root.trackLen)
                        color: Theme.muted2
                        font.pixelSize: 10
                    }
                }
            }

            // ── Controles de reproducción ─────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 8

                Item { Layout.fillWidth: true }

                // Botón anterior
                Rectangle {
                    width: 38; height: 38
                    radius: 19
                    color: prevHover.hovered ? Theme.hover : "transparent"
                    opacity: root.hasPlayer && (root.player.canGoPrevious ?? false) ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: prevHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer && (root.player.canGoPrevious ?? false)
                        onClicked: {
                            root.player.previous()
                            root.syncPosition()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⏮"
                        font.pixelSize: 17
                        color: Theme.text
                    }
                }

                // Botón play/pause
                Rectangle {
                    width: 52; height: 52
                    radius: 26
                    color: root.isPlaying ? Theme.accentSurface : Theme.surface3
                    opacity: root.hasPlayer ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: playHover }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: playHover.hovered ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer
                        onClicked: root.player.togglePlaying()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "⏸" : "▶"
                        font.pixelSize: 22
                        color: root.isPlaying ? Theme.accent : Theme.text
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Botón siguiente
                Rectangle {
                    width: 38; height: 38
                    radius: 19
                    color: nextHover.hovered ? Theme.hover : "transparent"
                    opacity: root.hasPlayer && (root.player.canGoNext ?? false) ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: nextHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer && (root.player.canGoNext ?? false)
                        onClicked: {
                            root.player.next()
                            root.syncPosition()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⏭"
                        font.pixelSize: 17
                        color: Theme.text
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}

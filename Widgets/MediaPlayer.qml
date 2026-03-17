import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../Components"

Row {
    id: root
    spacing: 8

    signal clicked()

    // ── Player state (updated via signal, not computed property) ─────────────
    property MprisPlayer _cachedPlayer: null
    
    // Track players to detect changes
    property var _lastPlayers: []

    // Explicit update function - call when players change
    function _updateCachedPlayer() {
        var currentPlayers = Mpris.players.values || []
        
        if (JSON.stringify(currentPlayers) === JSON.stringify(root._lastPlayers)) {
            return // No change
        }
        root._lastPlayers = currentPlayers
        
        var playingOther = null
        var playingMpd   = null
        var first        = null
        for (var i = 0; i < currentPlayers.length; i++) {
            var p = currentPlayers[i]
            if (!first) first = p
            var isMpd = (p.identity ?? "").toLowerCase().includes("music player daemon")
            if (p.playbackState === MprisPlaybackState.Playing) {
                if (isMpd) { if (!playingMpd) playingMpd = p }
                else       { if (!playingOther) playingOther = p }
            }
        }
        root._cachedPlayer = playingOther ?? playingMpd ?? first ?? null
    }

    // Manual bindings - no circular dependencies
    property MprisPlayer player: _cachedPlayer
    property bool hasPlayer:  _cachedPlayer !== null
    property bool isPlaying:  hasPlayer && _cachedPlayer.playbackState === MprisPlaybackState.Playing
    
    property string mediaInfo: {
        if (!hasPlayer) return "No media"
        var artist = _cachedPlayer.trackArtist ?? ""
        var title  = _cachedPlayer.trackTitle  ?? ""
        if (artist && title) return artist + " - " + title
        return title || artist || "No media"
    }

    // Listen to player changes via timer (avoids binding loop)
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root._updateCachedPlayer()
    }

    visible: true

    Item {
        width: 1
        height: 1
    }

    // ── Fade al cambiar de canción ─────────────────────────────────────────
    onMediaInfoChanged: songChangeAnim.restart()

    SequentialAnimation {
        id: songChangeAnim
        NumberAnimation {
            target: mediaText
            property: "opacity"
            to: 0.0
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: mediaText
            property: "opacity"
            to: 1.0
            duration: 350
            easing.type: Easing.InCubic
        }
    }

    CavaVisualizer {
        isPlaying: root.isPlaying
    }

    Item {
        width: 1
        height: 1
    }

    // ── Contenedor de texto con scroll ────────────────────────────────────
    Item {
        id: textContainer
        width: 120
        height: 20
        clip: true

        property bool shouldScroll: mediaText.implicitWidth > textContainer.width

        Text {
            id: mediaText
            color: root.hasPlayer ? Theme.text : Theme.muted2
            font.pixelSize: 12
            text: root.mediaInfo
            y: 4
            x: 0

            onTextChanged: {
                scrollAnimation.stop()
                x = 0
                if (textContainer.shouldScroll) scrollAnimation.start()
            }

            SequentialAnimation {
                id: scrollAnimation
                loops: Animation.Infinite

                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    target: mediaText
                    property: "x"
                    from: 0
                    to: -(mediaText.implicitWidth - textContainer.width + 10)
                    duration: Math.max(0, (mediaText.implicitWidth - textContainer.width) * 50)
                    easing.type: Easing.Linear
                }
                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    target: mediaText
                    property: "x"
                    to: 0
                    duration: Math.max(0, (mediaText.implicitWidth - textContainer.width) * 50)
                    easing.type: Easing.Linear
                }
            }
        }
    }

    // ── Botón anterior ────────────────────────────────────────────────────
    MouseArea {
        width: 20
        height: 20
        cursorShape: Qt.PointingHandCursor
        enabled: root.hasPlayer && (root._cachedPlayer?.canGoPrevious ?? false)
        opacity: enabled ? 1.0 : 0.35
        onClicked: root._cachedPlayer?.previous()

        Text {
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 14
            text: "⏮"
        }
    }

    // ── Botón play/pause ──────────────────────────────────────────────────
    MouseArea {
        width: 20
        height: 20
        cursorShape: Qt.PointingHandCursor
        enabled: root.hasPlayer
        opacity: enabled ? 1.0 : 0.35
        onClicked: root._cachedPlayer?.togglePlaying()

        Text {
            anchors.centerIn: parent
            color: root.isPlaying ? Theme.accent : Theme.text
            font.pixelSize: 14
            text: root.isPlaying ? "⏸" : "▶"
        }
    }

    // ── Botón siguiente ───────────────────────────────────────────────────
    MouseArea {
        width: 20
        height: 20
        cursorShape: Qt.PointingHandCursor
        enabled: root.hasPlayer && (root._cachedPlayer?.canGoNext ?? false)
        opacity: enabled ? 1.0 : 0.35
        onClicked: root._cachedPlayer?.next()

        Text {
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 14
            text: "⏭"
        }
    }
}

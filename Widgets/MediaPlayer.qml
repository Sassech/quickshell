import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../Components"

Row {
    id: root
    spacing: 8

    signal clicked()

    // ── Player state ──────────────────────────────────────────────────────────
    property MprisPlayer _cachedPlayer: null
    property var _lastPlayerIds: []

    function _updateCachedPlayer() {
        var players = Mpris.players.values || []
        
        // Extraer IDs para comparar (más eficiente que JSON.stringify)
        var currentIds = players.map(p => p.identity + ":" + p.playbackState)
        
        if (arraysEqual(currentIds, _lastPlayerIds)) {
            return
        }
        _lastPlayerIds = currentIds
        
        var playingOther = null
        var playingMpd   = null
        var first        = null
        
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (!first) first = p
            var isMpd = (p.identity ?? "").toLowerCase().includes("music player daemon")
            if (p.playbackState === MprisPlaybackState.Playing) {
                if (isMpd) { if (!playingMpd) playingMpd = p }
                else       { if (!playingOther) playingOther = p }
            }
        }
        _cachedPlayer = playingOther ?? playingMpd ?? first ?? null
    }

    function arraysEqual(a, b) {
        if (a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false
        }
        return true
    }

    // ── Bindings ─────────────────────────────────────────────────────────────
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

    // ── Timer: 1s polling (era 500ms) ─────────────────────────────────────
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._updateCachedPlayer()
    }

    visible: true

    Item { width: 1; height: 1 }

    // ── Fade al cambiar de canción ─────────────────────────────────────────
    onMediaInfoChanged: songChangeAnim.restart()

    SequentialAnimation {
        id: songChangeAnim
        NumberAnimation {
            target: mediaText
            property: "opacity"
            to: 0.0
            duration: 100
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: mediaText
            property: "opacity"
            to: 1.0
            duration: 150
            easing.type: Easing.InCubic
        }
    }

    CavaVisualizer {
        isPlaying: root.isPlaying
    }

    Item { width: 1; height: 1 }

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

    // ── Botón anterior ───────────────────────────────────────────────────
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

    // ── Botón play/pause ─────────────────────────────────────────────────
    MouseArea {
        width: 24
        height: 24
        cursorShape: Qt.PointingHandCursor
        enabled: root.hasPlayer
        opacity: enabled ? 1.0 : 0.35
        onClicked: root._cachedPlayer?.togglePlaying()

        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: width / 2
            color: Theme.accent
            opacity: root.isPlaying ? 0.18 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.centerIn: parent
            color: root.isPlaying ? Theme.accent : Theme.text
            font.pixelSize: 14
            text: root.isPlaying ? "⏸" : "▶"

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
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

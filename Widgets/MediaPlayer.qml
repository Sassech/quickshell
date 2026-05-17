import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../Components"

Row {
    id: root
    spacing: 8

    // ── Player state ──────────────────────────────────────────────────────────
    property MprisPlayer _cachedPlayer: null

    function _updateCachedPlayer() {
        const players = Mpris.players.values ?? []
        let playingOther = null
        let playingMpd   = null
        let first        = null

        for (let i = 0; i < players.length; i++) {
            const p = players[i]
            if (!first) first = p
            const isMpd = (p.identity ?? "").toLowerCase().includes("music player daemon")
            if (p.isPlaying) {
                if (isMpd) { if (!playingMpd) playingMpd = p }
                else       { if (!playingOther) playingOther = p }
            }
        }
        _cachedPlayer = playingOther ?? playingMpd ?? first ?? null
    }

    // ── Bindings ──────────────────────────────────────────────────────────────
    property bool hasPlayer: _cachedPlayer !== null
    property bool isPlaying: _cachedPlayer?.isPlaying ?? false

    property string mediaInfo: {
        if (!hasPlayer) return "No media"
        const artist = _cachedPlayer.trackArtist ?? ""
        const title  = _cachedPlayer.trackTitle  ?? ""
        if (artist && title) return artist + " - " + title
        return title || artist || "No media"
    }

    // ── Inicialización ────────────────────────────────────────────────────────
    Component.onCompleted: Qt.callLater(root._updateCachedPlayer)

    // ── Reacciona a cambios en la lista de players ────────────────────────────
    Connections {
        target: Mpris.players
        function onValuesChanged() { root._updateCachedPlayer() }
    }

    // ── Reacciona a cambios del player activo ─────────────────────────────────
    Connections {
        target: root._cachedPlayer ?? null
        function onIsPlayingChanged() { root._updateCachedPlayer() }
        function onTrackChanged()     { root._updateCachedPlayer() }
    }

    visible: true

    Item { width: 1; height: 1 }

    // ── Fade al cambiar de canción ────────────────────────────────────────────
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

    // ── Contenedor de texto con scroll ────────────────────────────────────────
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

    // ── Botón anterior ────────────────────────────────────────────────────────
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

    // ── Botón play/pause ──────────────────────────────────────────────────────
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

    // ── Botón siguiente ───────────────────────────────────────────────────────
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

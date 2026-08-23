pragma ComponentBehavior: Bound

// qmllint disable uncreatable-type
import QtQuick
import Quickshell.Services.Mpris

// MusicPlayerOverlay — mini reproductor MPRIS estilo "Aurora Glass".
// NO usa la paleta Theme (se regenera al cambiar el wallpaper): todos los
// colores se declaran acá. Sin blur real en LayerShell — el glassmorphism
// se simula con gradientes translúcidos.
OverlayWindow {
    id: root

    // Configuración concreta
    entryId:        "musicPlayer"   // OverlayWindow auto-gobierna visibilidad vía OverlaysManager
    corner:         "bottom-right"
    overlayWidth:   355
    overlayHeight:  91
    bgColor:        "transparent"           // la tarjeta de vidrio se dibuja acá (2 capas)
    showAccent:     false
    restingOpacity: 1.0                     // la transparencia ya vive en los colores
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0
    borderColor:    "transparent"
    // mouseThrough queda en false: el overlay tiene botones interactivos

    // Selección de player (MPRIS)
    // El wallpaper de video (mpvpaper → mpv) toma el bus canónico
    // org.mpris.MediaPlayer2.mpv; el mpv real del usuario, al abrirse después,
    // queda como org.mpris.MediaPlayer2.mpv.instance-XXXX. Se banea el canónico
    // SOLO cuando coexiste una instancia real: entonces el canónico es el
    // wallpaper (Playing en loop perpetuo) y el instance es el mpv del usuario.
    // La música real va por mpd/Spotify/Brave, que usan otro identity.
    property var mprisPlayer: null
    property real playerPos: 0

    // Progreso real (ms, solo si el player reporta longitud).
    readonly property real _progress: {
        const p = root.mprisPlayer
        if (!p || !p.lengthSupported || p.length <= 0) return 0
        return Math.max(0, Math.min(1, root.playerPos / p.length))
    }

    function _isBanned(p) {
        if ((p.busName ?? "") !== "org.mpris.MediaPlayer2.mpv") return false
        const players = Mpris.players.values ?? []
        return players.some(q => (q.busName ?? "").startsWith("org.mpris.MediaPlayer2.mpv.instance"))
    }

    function _pickPlayer() {
        const players = Mpris.players.values
        let playing = null
        let first = null
        for (let i = 0; i < players.length; i++) {
            const p = players[i]
            if (root._isBanned(p)) continue
            if (!first) first = p
            if (!playing && p.playbackState === MprisPlaybackState.Playing) playing = p
        }
        root.mprisPlayer = playing ?? first ?? null
    }

    function _syncPos() {
        const p = root.mprisPlayer
        if (p && p.positionSupported) root.playerPos = p.position
    }

    // Formateo de tiempo (ms → "m:ss")
    function fmtMs(ms) {
        if (!ms || ms <= 0) return "0:00"
        const s = Math.floor(ms / 1000)
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    // Carga inicial sin Component.onCompleted (OverlayWindow maneja el ciclo
    // de vida y la visibilidad): un timer de 0ms alcanza para el primer pick.
    Timer {
        interval: 0
        onTriggered: root._pickPlayer()
    }

    Connections {
        target: Mpris.players
        // Señales del ObjectModel: solo inserción/remoción de players. NO hay
        // señal de cambio de playbackState (valuesChanged no se dispara cuando
        // un player existente pasa a Playing), así que el Timer de 1s abajo
        // re-evalúa la prioridad en vivo.
        function onObjectInsertedPost() { root._pickPlayer() }
        function onObjectRemovedPost()  { root._pickPlayer() }
    }

    // Escucha señales individuales de cada player (playbackState, track).
    // Cubre el gap del ObjectModel: valuesChanged NO se dispara cuando un
    // player existente cambia su estado — por eso el Instantiator es necesario.
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPlaybackStateChanged() { root._pickPlayer() }
            function onTrackChanged()         { root._pickPlayer() }
        }
    }

    // Fallback periódico — cubre edge cases (ej: player que no emite señales).
    // Reducido de 1s a 10s porque el Instantiator cubre los casos normales.
    Timer {
        interval: 10000
        repeat: true
        running: Mpris.players.values.length > 0
        onTriggered: root._pickPlayer()
    }

    Connections {
        target: root.mprisPlayer ?? null
        function onTrackChanged() { root._syncPos() }
    }

    // Refresco de posición mientras reproduce.
    Timer {
        interval: 500
        repeat: true
        running: root.mprisPlayer?.isPlaying ?? false
        onTriggered: root._syncPos()
    }

    // Contenido (slot por defecto → contentArea)
    // Capa 1: borde luminoso en gradiente (azul → cian → púrpura → magenta).
    // border.color no acepta gradientes, así que el glow es una capa propia
    // detrás de la tarjeta (que deja 1px de margen en cada lado).
    Rectangle {
        id: borderGlow
        anchors.fill: parent
        radius: 13
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0;  color: Qt.rgba(0.30, 0.55, 1.00, 0.60) }
            GradientStop { position: 0.35; color: Qt.rgba(0.20, 0.85, 1.00, 0.60) }
            GradientStop { position: 0.70; color: Qt.rgba(0.55, 0.40, 1.00, 0.60) }
            GradientStop { position: 1.0;  color: Qt.rgba(1.00, 0.35, 0.85, 0.60) }
        }
    }

    // Capa 2: tarjeta de vidrio azul oscuro translúcido (1px de margen).
    Rectangle {
        id: glassCard
        x: 1; y: 1
        width:  root.overlayWidth - 2
        height: root.overlayHeight - 2
        radius: 12
        color:  Qt.rgba(0.08, 0.10, 0.22, 0.82)
        clip:   true

        // Glassmorphism simulado (sin blur real)
        // Brillo interior cian → púrpura → magenta a baja opacidad.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.45, 0.95, 1.00, 1.0) }
                GradientStop { position: 0.5; color: Qt.rgba(0.55, 0.40, 1.00, 1.0) }
                GradientStop { position: 1.0; color: Qt.rgba(1.00, 0.40, 0.85, 1.0) }
            }
            opacity: 0.20
        }
        // Segundo gradiente tenue en otra dirección (profundidad).
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "white" }
                GradientStop { position: 0.5; color: "transparent" }
            }
            opacity: 0.08
        }

        // Arte
        Rectangle {
            id: artBox
            x: 5; y: 5
            width: 82; height: 82
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.06)
            clip:  true
            Image {
                id: artImg
                anchors.fill: parent
                source: root.mprisPlayer?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !artImg.visible
                text: "󰝚"
                font.pixelSize: 26
                color: Qt.rgba(0.92, 0.94, 1.0, 0.5)
            }
        }

        // Info + barra + controles (a la derecha del arte)
        Item {
            anchors {
                left: artBox.right
                leftMargin: 12
                right: parent.right
                rightMargin: 12
                top: parent.top
                topMargin: 10
                bottom: parent.bottom
                bottomMargin: 8
            }

            Text {
                id: titleText
                anchors { left: parent.left; right: parent.right; top: parent.top }
                text: root.mprisPlayer?.trackTitle ?? "Sin reproductor"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Qt.rgba(0.92, 0.94, 1.0, 0.95)
                elide: Text.ElideRight
            }

            // Timeline: tiempo actual | barra de progreso | duración total
            Row {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: titleText.bottom
                    topMargin: 6
                }
                height: 12
                spacing: 4
                Text {
                    width: 30
                    text: root.fmtMs(root.playerPos)
                    font.pixelSize: 9
                    color: Qt.rgba(0.92, 0.94, 1.0, 0.6)
                }
                Item {
                    id: progressBar
                    width: parent.width - 30 - 30 - 8
                    height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.fill: parent; radius: 2; color: Qt.rgba(0, 0, 0, 0.35) }
                    Rectangle {
                        width: parent.width * root._progress
                        height: parent.height
                        radius: 2
                        color: Qt.rgba(0.95, 0.97, 1.0, 0.9)
                    }
                }
                Text {
                    width: 30
                    text: root.mprisPlayer?.lengthSupported ? root.fmtMs(root.mprisPlayer?.length ?? 0) : "0:00"
                    font.pixelSize: 9
                    color: Qt.rgba(0.92, 0.94, 1.0, 0.6)
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Controles: anterior | play/pausa | siguiente
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                spacing: 22
                Repeater {
                    model: [
                        { icon: "󰒮", action: "prev", big: false },
                        { icon: root.mprisPlayer?.isPlaying ? "󰏤" : "󰐊", action: "play", big: true },
                        { icon: "󰒭", action: "next", big: false }
                    ]
                    Rectangle {
                        id: ctrlBtn
                        required property var modelData
                        width: 26; height: 22; radius: 7
                        color: ctrlHov.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: ctrlBtn.modelData.icon
                            font.pixelSize: ctrlBtn.modelData.big ? 15 : 13
                            color: Qt.rgba(0.92, 0.94, 1.0, 0.9)
                        }
                        MouseArea {
                            id: ctrlHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const p = root.mprisPlayer
                                if (!p) return
                                if      (ctrlBtn.modelData.action === "prev") p.previous()
                                else if (ctrlBtn.modelData.action === "next") p.next()
                                else p.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }
}
import QtQuick
pragma ComponentBehavior: Bound
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../Components"

Rectangle {
    id: root

    width:  24
    height: 24
    radius: 5
    color:  mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    // Propiedad inyectada desde shell.qml — IdleInhibitor la necesita
    required property var barWindow

    property bool inhibiting: false
    property string idleTime: "--"
    property bool mediaPlaying: false
    property real _idleStartMs: 0

    Behavior on color { ColorAnimation { duration: 120 } }

    Component.onCompleted: {
        idleStateFile.reload()
    }

    // Estado persistente via FileView (reemplaza loadProc + saveProc)
    FileView {
        id: idleStateFile
        path: Paths.config + "/idle-state.json"
        onLoaded: {
            try {
                const d = JSON.parse(idleStateFile.text())
                if (d.inhibiting === true) root.inhibiting = true
            } catch(e) {}
        }
    }

    function saveState(data) {
        idleStateFile.setText(JSON.stringify(data))
    }

    // Idle inhibitor nativo Wayland (reemplaza systemd-inhibit)
    IdleInhibitor {
        id: idleInhibitorItem
        // TODO: asignar desde shell.qml
        window: root.barWindow
        enabled: root.inhibiting
    }

    // Monitor de idle nativo Wayland (reemplaza loginctl + idleProc)
    IdleMonitor {
        id: idleMonitorItem
        timeout: 60   // segundos (doc v0.3.0: timeout es real en segundos, no ms)
        onIsIdleChanged: root._updateIdleTime()
    }

    function _updateIdleTime() {
        if (idleMonitorItem.isIdle) {
            // isIdle se dispara tras ~timeout segundos sin input → anclar el
            // inicio al momento real de idle, no al del evento.
            root._idleStartMs = Date.now() - idleMonitorItem.timeout * 1000
        } else {
            root._idleStartMs = 0
            root.idleTime = "--"
        }
    }

    // Actualiza el tiempo transcurrido mientras el tooltip es visible
    Timer {
        interval: 5000
        running: mouseArea.containsMouse && idleMonitorItem.isIdle && root._idleStartMs > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const elapsed = Math.floor((Date.now() - root._idleStartMs) / 1000)
            root.idleTime = root.formatIdleTime(elapsed)
        }
    }

    function formatIdleTime(seconds) {
        if (seconds < 60) return `${seconds}s`;
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return `${h}h ${m}m`;
    }

    // Detección de reproducción via Mpris nativo (event-driven, sin forks)
    function _checkMediaPlaying() {
        var playing = false
        var players = (Mpris.players && Mpris.players.values) ? Mpris.players.values : []
        for (var i = 0; i < players.length; i++) {
            const player = players[i]
            if (!player) continue
            if (player.playbackState === MprisPlaybackState.Playing) {
                playing = true
                break
            }
        }
        root.mediaPlaying = playing
        if (root.mediaPlaying && !root.inhibiting) {
            root.inhibiting = true
            saveState({ inhibiting: true })
        }
    }

    // onValuesChanged cubre inserción/remoción de players.
    Connections {
        target: Mpris.players
        function onValuesChanged() { root._checkMediaPlaying() }
    }

    // Escucha cada player individualmente — detecta transiciones Paused→Playing
    // sin que la lista de players cambie (onValuesChanged no se dispara en ese caso).
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onPlaybackStateChanged() { root._checkMediaPlaying() }
            function onIsPlayingChanged()     { root._checkMediaPlaying() }
        }
    }

    Process {
        id: notifProc
        running: false
        stdout: SplitParser { splitMarker: "\n"; onRead: data => {} }
    }

    function sendNotif(urgency, title, msg) {
        const icon = (urgency === "critical") ? "dialog-warning" : "dialog-information";
        notifProc.command = [
            "notify-send",
            "-u", urgency,
            "-i", icon,
            title, msg
        ];
        notifProc.running = true;
    }

    Text {
        anchors.centerIn: parent
        text:           root.inhibiting ? "🔥" : "☕"
        font.pixelSize: 13
        color:          root.inhibiting ? Theme.warning : Theme.muted3

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Rectangle {
        visible:         root.inhibiting
        width:           5
        height:          5
        radius:          3
        color:           Theme.error
        anchors.top:     parent.top
        anchors.right:   parent.right
        anchors.margins: 2

        PropertyAnimation on opacity {
            from: 1; to: 0.4; duration: 800; loops: Animation.Infinite; running: root.inhibiting
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor

        onClicked: {
            root.inhibiting = !root.inhibiting

            if (root.inhibiting) {
                root.sendNotif("normal", "☕ Idle bloqueado", "La pantalla no se apagará automáticamente");
                root.saveState({ inhibiting: true });
            } else {
                root.sendNotif("normal", "Idle restaurado", "El sistema volverá al comportamiento normal");
                root.saveState({ inhibiting: false });
            }
        }
    }

    Rectangle {
        visible:         mouseArea.containsMouse
        width:           tipText.implicitWidth + 16
        height:          32
        radius:          4
        color:           Theme.cardBg3
        border.color:    Theme.surface2
        border.width:    1
        anchors.bottom:  parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 4
        z: 10

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: tipText
                text:           root.inhibiting ? "🔥 Bloqueado" : "☕ Activo"
                color:          Theme.text
                font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text:           "Idle: " + root.idleTime + (root.mediaPlaying ? " • 🎵" : "")
                color:          Theme.muted2
                font.pixelSize: 7
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}

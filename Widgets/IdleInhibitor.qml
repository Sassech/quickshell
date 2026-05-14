import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Components"

Rectangle {
    id: root

    width:  24
    height: 24
    radius: 5
    color:  mouseArea.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    property bool inhibiting: false
    property string idleTime: "--"
    property bool mediaPlaying: false
    property string _loadBuf: ""
    property string _idleBuf: ""
    property string _sessionId: ""

    Behavior on color { ColorAnimation { duration: 120 } }

    Component.onCompleted: {
        loadState();
        detectSession();
    }

    // ── Detect session ID once (avoid re-running loginctl list-sessions) ──
    Process {
        id: sessionDetectProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const v = data.trim()
                if (v) root._sessionId = v
            }
        }
    }

    function detectSession() {
        sessionDetectProc.command = ["bash", "-c",
            "loginctl --no-legend list-sessions 2>/dev/null | grep seat0 | awk '{print $1}' | head -1"]
        sessionDetectProc.running = true
    }

    Process {
        id: loadProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root._loadBuf += data;
                try {
                    const d = JSON.parse(root._loadBuf.trim());
                    if (d.inhibiting === true) {
                        root.inhibiting = true;
                        root.inhibitProc.running = true;
                    }
                    root._loadBuf = "";
                } catch (e) {}
            }
        }
    }

    function loadState() {
        _loadBuf = "";
        loadProc.command = ["bash", "-c", "cat \"" + Paths.config + "/idle-state.json\" 2>/dev/null || echo ''"];
        loadProc.running = true;
    }

    function saveState(data) {
        saveProc.command = ["bash", "-c", "echo '" + JSON.stringify(data) + "' > \"" + Paths.config + "/idle-state.json\""];
        saveProc.running = true;
    }

    Process {
        id: saveProc
        running: false
    }

    Process {
        id: idleProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root._idleBuf += data;
                const seconds = parseInt(root._idleBuf.trim()) || 0;
                root.idleTime = formatIdleTime(seconds);
                root._idleBuf = "";
            }
        }
    }

    Timer {
        id: idleTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root._sessionId) {
                idleProc.command = ["bash", "-c",
                    "loginctl show-session " + root._sessionId + " -p IdleSince --value 2>/dev/null | cut -d. -f1 || echo 0"]
            } else {
                idleProc.command = ["bash", "-c", "echo 0"]
            }
            idleProc.running = true;
        }
    }

    function formatIdleTime(seconds) {
        if (seconds < 60) return `${seconds}s`;
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return `${h}h ${m}m`;
    }

    // ── Detección de reproducción via Mpris nativo (event-driven, sin forks) ──
    function _checkMediaPlaying() {
        var playing = false
        var players = Mpris.players.values || []
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) {
                playing = true
                break
            }
        }
        root.mediaPlaying = playing
        if (root.mediaPlaying && !root.inhibiting) {
            root.inhibiting = true
            root.inhibitProc.running = true
            saveState({ inhibiting: true })
        }
    }

    Connections {
        target: Mpris
        function onPlayersChanged() { root._checkMediaPlaying() }
    }

    // Conecta al player activo para detectar pausa/stop
    Connections {
        target: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
        function onPlaybackStateChanged() { root._checkMediaPlaying() }
    }

    Process {
        id: inhibitProc
        command: [
            "systemd-inhibit",
            "--what=idle",
            "--who=Quickshell",
            "--why=Manual inhibit",
            "--mode=block",
            "sleep", "infinity"
        ]
        running: false
        stdout: SplitParser { splitMarker: "\n"; onRead: data => {} }

        onExited: function(code) {
            if (root.inhibiting && code !== 0) {
                root.inhibiting = false;
                sendNotif("error", "Error al bloquear idle", "systemd-inhibit falló");
                saveState({ inhibiting: false });
            }
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
                inhibitProc.running = true
                sendNotif("critical", "☕ Idle bloqueado", "La pantalla no se apagará automáticamente");
                saveState({ inhibiting: true });
            } else {
                inhibitProc.running = false
                sendNotif("normal", "Idle restaurado", "El sistema volverá al comportamiento normal");
                saveState({ inhibiting: false });
            }
        }
    }

    Rectangle {
        visible:         mouseArea.containsMouse
        width:           tipText.implicitWidth + 16
        height:          32
        radius:          4
        color:           Theme.base
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

import QtQuick
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root
    width: 30
    height: 20
    color: "transparent"
    radius: 4

    property bool isPlaying: false
    property string cavaSource: ""
    property var audioLevels: [0, 0, 0, 0, 0, 0, 0, 0]
    property bool sinkDetected: false
    property int restartAttempts: 0
    property int maxRestartAttempts: 3

    Component.onCompleted: sinkProcess.running = true

    Process {
        id: sinkProcess
        command: ["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.indexOf("node.name") === -1)
                    return

                var match = data.match(/node\.name\s*=\s*"([^"]+)"/)
                if (match && match.length > 1) {
                    root.cavaSource = match[1] + ".monitor"
                    root.sinkDetected = true
                    sinkProcess.running = false
                    cavaProcess.running = true
                }
            }
        }

        onExited: {
            if (!root.sinkDetected) {
                restartAttempts++
                if (restartAttempts < maxRestartAttempts) {
                    Qt.callLater(function() { sinkProcess.running = true })
                }
            }
        }
    }

    Process {
        id: cavaProcess
        command: [
            "sh", "-c",
            "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava-${UID:-1000}.conf\" && " +
            "mkdir -p \"${XDG_RUNTIME_DIR:-/tmp}\" && " +
            "cat > \"$cfg\" <<'CAVAEOF'\n" +
            "[general]\nbars = 8\nframerate = 60\n\n" +
            "[input]\nmethod = pulse\nsource = " + root.cavaSource + "\n\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\n" +
            "data_format = ascii\nascii_max_range = 16\nbar_delimiter = 32\nCAVAEOF\n" +
            "exec cava -p \"$cfg\""
        ]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!root.isPlaying || !data || !data.trim())
                    return

                var values = data.trim().split(/\s+/)
                var nextLevels = []
                for (var i = 0; i < 8; i++) {
                    nextLevels.push(i < values.length && values[i] !== "" 
                        ? Number(values[i]) || 0 
                        : 0)
                }
                root.audioLevels = nextLevels
            }
        }

        onExited: {
            if (root.isPlaying && root.sinkDetected) {
                restartAttempts++
                if (restartAttempts < maxRestartAttempts) {
                    Qt.callLater(function() { cavaProcess.running = true })
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: 8

            Item {
                width: 3
                height: 16

                property real baseHeight: 4
                property real targetHeight: root.isPlaying && index < root.audioLevels.length
                    ? Math.max(baseHeight, root.audioLevels[index])
                    : baseHeight

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.targetHeight
                    color: root.isPlaying ? Theme.accent : Theme.surface3
                    radius: 1.5

                    Behavior on height {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
            }
        }
    }
}

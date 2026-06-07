pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../Components"

Rectangle {
    id: root
    width: 30
    height: 20
    color: "transparent"
    radius: 4
    layer.enabled: true
    layer.smooth: true

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

        // qmllint disable signal-handler-parameters
        onExited: {
            if (!root.sinkDetected) {
                root.restartAttempts++
                if (root.restartAttempts < root.maxRestartAttempts) {
                    Qt.callLater(function() { sinkProcess.running = true })
                }
            }
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: cavaProcess
        command: [
            "sh", "-c",
            "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava-${UID:-1000}.conf\" && " +
            "mkdir -p \"${XDG_RUNTIME_DIR:-/tmp}\" && " +
            "cat > \"$cfg\" <<'CAVAEOF'\n" +
            "[general]\nbars = 8\nframerate = 15\n\n" +
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

        // qmllint disable signal-handler-parameters
        onExited: {
            if (root.isPlaying && root.sinkDetected) {
                root.restartAttempts++
                if (root.restartAttempts < root.maxRestartAttempts) {
                    Qt.callLater(function() { cavaProcess.running = true })
                }
            }
        }
        // qmllint enable signal-handler-parameters
    }

    Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: 8

            Item {
                id: barItem
                required property int index
                // Copias locales de propiedades del root para evitar acceso no calificado
                // en el scope del delegate (pragma ComponentBehavior: Bound en shell.qml)
                readonly property bool _playing: root.isPlaying
                readonly property var  _levels:  root.audioLevels
                width: 3
                height: 16

                // Escala normalizada 0.0–1.0 (baseScale mínima para no desaparecer)
                property real baseScale: 0.25
                property real targetScale: barItem._playing && barItem.index < barItem._levels.length
                    ? Math.max(barItem.baseScale, barItem._levels[barItem.index] / 16.0)
                    : barItem.baseScale

                Rectangle {
                    width: parent.width
                    height: parent.height
                    // Anclar al bottom via transform origin
                    transformOrigin: Item.Bottom
                    anchors.bottom: parent.bottom
                    color: barItem._playing ? Theme.accent : Theme.surface3
                    radius: 1.5

                    // GPU-accelerated: scale en Y no dispara re-layout
                    transform: Scale {
                        origin.x: 0
                        origin.y: barItem.height
                        yScale: barItem.targetScale

                        Behavior on yScale {
                            NumberAnimation {
                                duration: 66
                                easing.type: Easing.OutCubic
                            }
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

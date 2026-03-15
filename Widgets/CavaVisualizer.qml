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
    border.color: Theme.surface2
    border.width: 1

    property bool isPlaying: false
    property string cavaSource: ""
    property var audioLevels: [0, 0, 0, 0, 0, 0, 0, 0]

    Process {
        id: defaultSinkProcess
        command: ["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data ? data.trim() : ""
                if (!line || line.indexOf("node.name") === -1)
                    return

                var match = line.match(/node\.name\s*=\s*"([^"]+)"/)
                if (match && match.length > 1) {
                    root.cavaSource = match[1] + ".monitor"
                    if (!cavaProcess.running)
                        cavaProcess.running = true
                }
            }
        }
    }

    Process {
        id: cavaProcess
        command: [
            "sh",
            "-c",
            "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava-${UID:-1000}.conf\"; " +
            "cat > \"$cfg\" <<EOF\n" +
            "[general]\n" +
            "bars = 8\n" +
            "framerate = 60\n\n" +
            "[input]\n" +
            "method = pulse\n" +
            "source = " + root.cavaSource + "\n\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 16\n" +
            "bar_delimiter = 32\n" +
            "EOF\n" +
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
                    if (i < values.length && values[i] !== "") {
                        nextLevels.push(Number(values[i]) || 0)
                    } else {
                        nextLevels.push(0)
                    }
                }
                root.audioLevels = nextLevels
            }
        }

        onExited: () => {
            if (root.cavaSource) {
                cavaProcess.running = true
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

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    property string _scriptsPath: Qt.resolvedUrl("../scripts").toString().replace("file://", "")

    // Fan properties
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan1Percent: 0
    property int fan2Percent: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property string fanProfile: ""
    property bool fanAvailable: false

    property bool applying: false

    onVisibleChanged: {
        if (visible) {
            root.fanAvailable = false
            detectProc.running = true
        }
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: {
            refreshFanFiles()
        }
    }

    // Fan functions
    function modeLabel(m) {
        if (m === "cool") return "Frio"
        if (m === "quiet") return "Silencioso"
        if (m === "balanced") return "Balanceado"
        if (m === "performance") return "Alto"
        return m
    }

    function modeIcon(m) {
        if (m === "cool") return "❄️"
        if (m === "quiet") return "🤫"
        if (m === "balanced") return "⚖️"
        if (m === "performance") return "🔥"
        return m
    }

    function modeColor(m) {
        if (m === "cool") return Theme.success
        if (m === "performance") return Theme.error
        return Theme.accent
    }

    function refreshFanFiles() {
        fanRpmProc.running = true
        fanPercentProc.running = true
        fanTempProc.running = true
        fanProfileProc.running = true
    }

    // Detect fan availability
    property string _detectBuf: ""
    Process {
        id: detectProc
        command: ["sh", "-c",
            "if [ -r /sys/class/hwmon/hwmon5/fan1_input ]; then " +
            "echo \"available\"; else echo \"none\"; fi"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._detectBuf += data
        }
        onExited: {
            var v = root._detectBuf.trim()
            root._detectBuf = ""
            if (v === "available") {
                root.fanAvailable = true
                refreshFanFiles()
            } else {
                root.fanAvailable = false
            }
        }
    }

    // Fan processes
    property string _fanRpmBuf: ""
    Process {
        id: fanRpmProc
        command: [root._scriptsPath + "/fan-control.sh", "get_rpm"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._fanRpmBuf += data
        }
        onExited: {
            var parts = root._fanRpmBuf.trim().split(",")
            if (parts.length >= 2) {
                root.fan1Rpm = parseInt(parts[0]) || 0
                root.fan2Rpm = parseInt(parts[1]) || 0
                root.fanAvailable = root.fan1Rpm > 0 || root.fan2Rpm > 0
            }
            root._fanRpmBuf = ""
        }
    }

    property string _fanPercentBuf: ""
    Process {
        id: fanPercentProc
        command: [root._scriptsPath + "/fan-control.sh", "get_percent"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._fanPercentBuf += data
        }
        onExited: {
            var parts = root._fanPercentBuf.trim().split(",")
            if (parts.length >= 2) {
                root.fan1Percent = parseInt(parts[0]) || 0
                root.fan2Percent = parseInt(parts[1]) || 0
            }
            root._fanPercentBuf = ""
        }
    }

    property string _fanTempBuf: ""
    Process {
        id: fanTempProc
        command: [root._scriptsPath + "/fan-control.sh", "get_temp"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._fanTempBuf += data
        }
        onExited: {
            var parts = root._fanTempBuf.trim().split(",")
            if (parts.length >= 2) {
                root.cpuTemp = parseInt(parts[0]) || 0
                root.gpuTemp = parseInt(parts[1]) || 0
            }
            root._fanTempBuf = ""
        }
    }

    property string _fanProfileBuf: ""
    Process {
        id: fanProfileProc
        command: [root._scriptsPath + "/fan-control.sh", "get_profile"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._fanProfileBuf += data
        }
        onExited: {
            root.fanProfile = root._fanProfileBuf.trim()
            root._fanProfileBuf = ""
        }
    }

    Process {
        id: fanApplyProc
        onExited: {
            root.applying = false
            refreshFanFiles()
        }
    }

    function setFanProfile(profile) {
        if (root.applying) return
        root.applying = true
        fanApplyProc.command = ["sudo", root._scriptsPath + "/fan-control.sh", "set_profile", profile]
        fanApplyProc.running = true
    }

    // ── UI ───────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 44
        anchors.rightMargin: 8
        width: 300
        height: col.implicitHeight + 24
        radius: 12
        color: Theme.base
        border.color: Theme.surface2
        border.width: 1

        // Header accent stripe
        Rectangle {
            width: parent.width; height: 3; radius: 2
            anchors.top: parent.top
            color: Theme.accent
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // absorbe clicks, impide propagación
        }

        ColumnLayout {
            id: col
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            anchors.topMargin: 16
            spacing: 10

            // Title row
            RowLayout {
                spacing: 8
                Text {
                    text: "󰈐"
                    font.pixelSize: 17
                    color: Theme.accent
                }
                Text {
                    text: "Ventilador"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.applying ? "Aplicando..." : ""
                    font.pixelSize: 10
                    color: Theme.accent
                }
            }

            Text {
                visible: !root.fanAvailable
                text: "Ventilador no disponible"
                font.pixelSize: 11
                color: Theme.muted1
            }

            // Temperatures
            RowLayout {
                spacing: 6
                visible: root.fanAvailable

                Rectangle {
                    Layout.fillWidth: true
                    height: 45
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.cpuTemp + "°C"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "CPU"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 45
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.gpuTemp + "°C"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "GPU"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 45
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.fan1Rpm
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "RPM"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.surface2
                visible: root.fanAvailable
            }

            // Fan load bars
            Column {
                spacing: 5
                visible: root.fanAvailable
                Layout.fillWidth: true

                Row {
                    spacing: 4
                    Text {
                        text: "F1"
                        font.pixelSize: 9
                        color: Theme.muted1
                        width: 18
                    }
                    Rectangle {
                        width: 210
                        height: 8
                        radius: 4
                        color: Theme.surface2
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                            width: Math.max(2, (parent.width - 2) * Math.min(100, root.fan1Percent) / 100)
                            radius: 2
                            color: Theme.accent
                        }
                    }
                    Text {
                        text: root.fan1Percent + "%"
                        font.pixelSize: 9
                        color: Theme.muted1
                        width: 30
                    }
                }

                Row {
                    spacing: 4
                    Text {
                        text: "F2"
                        font.pixelSize: 9
                        color: Theme.muted1
                        width: 18
                    }
                    Rectangle {
                        width: 210
                        height: 8
                        radius: 4
                        color: Theme.surface2
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                            width: Math.max(2, (parent.width - 2) * Math.min(100, root.fan2Percent) / 100)
                            radius: 2
                            color: Theme.accent2
                        }
                    }
                    Text {
                        text: root.fan2Percent + "%"
                        font.pixelSize: 9
                        color: Theme.muted1
                        width: 30
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.surface2
                visible: root.fanAvailable
            }

            // Fan RPM
            RowLayout {
                spacing: 6
                visible: root.fanAvailable

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.fan1Rpm > 0 ? root.fan1Rpm : "—"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ventilador 1"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.fan2Rpm > 0 ? root.fan2Rpm : "—"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ventilador 2"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.surface2
                visible: root.fanAvailable
            }

            // Fan percent bars
            RowLayout {
                spacing: 6
                visible: root.fanAvailable

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.fan1Percent + "%"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ventilador 1"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.fan2Percent + "%"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ventilador 2"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.surface2
                visible: root.fanAvailable
            }

            // Thermal profile buttons
            Text {
                text: "Perfil Térmico"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.muted1
                leftPadding: 2
                visible: root.fanAvailable
            }

            RowLayout {
                spacing: 6
                visible: root.fanAvailable

                Repeater {
                    model: ["cool", "quiet", "balanced", "performance"]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: 8
                        color: root.fanProfile === modelData ? Qt.darker(root.modeColor(modelData), 3.5) : Theme.surface2
                        border.color: root.fanProfile === modelData ? root.modeColor(modelData) : "transparent"
                        border.width: 1.5

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.modeIcon(modelData)
                                font.pixelSize: 14
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.modeLabel(modelData)
                                font.pixelSize: 10
                                font.weight: root.fanProfile === modelData ? Font.DemiBold : Font.Normal
                                color: root.fanProfile === modelData ? root.modeColor(modelData) : Theme.muted1
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.applying && root.fanProfile !== modelData
                            onClicked: root.setFanProfile(modelData)
                        }
                    }
                }
            }

            Item { height: 0 } // bottom padding
        }
    }
}

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


    // ── Read fan data from SysData (backend) ────────────────────────────
    property int fan1Rpm: SysData.fan1Rpm
    property int fan2Rpm: SysData.fan2Rpm
    property int fan1Percent: SysData.fan1Percent
    property int fan2Percent: SysData.fan2Percent
    property int cpuTemp: SysData.fanCpuTemp
    property int gpuTemp: SysData.fanGpuTemp
    property string fanProfile: SysData.fanProfile
    property bool fanAvailable: SysData.fanAvailable

    property bool applying: false

    onVisibleChanged: {
        // Data comes from SysData (backend), no need to spawn processes
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

    // ── SET operations still use fan-control.sh ──────────────────────
    Process {
        id: fanApplyProc
        onExited: {
            root.applying = false
        }
    }

    function setFanProfile(profile) {
        if (root.applying) return
        root.applying = true
        fanApplyProc.command = ["sudo", Paths.scripts + "/fan-control.sh", "set_profile", profile]
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
            // ── Absorb clicks to prevent propagation ──────────
            onClicked: {}
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

            // ── Fan load bars (percent + RPM) ────────────────────────
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
                        width: 160
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
                        font.family: "monospace"
                        color: Theme.text
                        width: 28
                    }
                    Text {
                        text: root.fan1Rpm + " rpm"
                        font.pixelSize: 9
                        font.family: "monospace"
                        color: Theme.muted2
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
                        width: 160
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
                        font.family: "monospace"
                        color: Theme.text
                        width: 28
                    }
                    Text {
                        text: root.fan2Rpm + " rpm"
                        font.pixelSize: 9
                        font.family: "monospace"
                        color: Theme.muted2
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

            // ── Thermal profile buttons ────────────────────────────
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

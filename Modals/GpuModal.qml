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

    // ── Data ─────────────────────────────────────────────
    // Intel
    property string intelName: "Intel UHD"
    property int intelFreq: 0
    property int intelTemp: 0

    // NVIDIA
    property bool nvidiaActive: false
    property string nvidiaName: "RTX 3050 Mobile"
    property int nvidiaUtil: 0
    property int nvidiaTemp: 0
    property int nvidiaVramUsed: 0
    property int nvidiaVramTotal: 0
    property real nvidiaPower: 0
    property real nvidiaPowerLimit: 0
    property int nvidiaClock: 0
    property int nvidiaClockMem: 0
    property string nvidiaDriver: "—"

    onVisibleChanged: { if (visible) fetchData() }

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        onTriggered: fetchData()
    }

    function fetchData() { _buf = ""; gpuProc.running = true }

    property string _buf: ""
    Process {
        id: gpuProc
        command: ["bash", Paths.scripts + "/gpu-detail.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._buf += data + "\n"
        }
        onExited: {
            var kv = {}
            root._buf.trim().split("\n").forEach(line => {
                var idx = line.indexOf(":")
                if (idx > 0) kv[line.substring(0, idx)] = line.substring(idx + 1)
            })
            root._buf = ""
            if (kv["INTEL_NAME"])          root.intelName         = kv["INTEL_NAME"]
            if (kv["INTEL_FREQ"])          root.intelFreq         = parseInt(kv["INTEL_FREQ"])  || 0
            if (kv["INTEL_TEMP"])          root.intelTemp         = parseInt(kv["INTEL_TEMP"])  || 0
            if (kv["NVIDIA_STATUS"])       root.nvidiaActive      = (kv["NVIDIA_STATUS"] === "active")
            if (kv["NVIDIA_NAME"])         root.nvidiaName        = kv["NVIDIA_NAME"]
            if (kv["NVIDIA_UTIL"])         root.nvidiaUtil        = parseInt(kv["NVIDIA_UTIL"])      || 0
            if (kv["NVIDIA_TEMP"])         root.nvidiaTemp        = parseInt(kv["NVIDIA_TEMP"])      || 0
            if (kv["NVIDIA_VRAM_USED"])    root.nvidiaVramUsed    = parseInt(kv["NVIDIA_VRAM_USED"]) || 0
            if (kv["NVIDIA_VRAM_TOTAL"])   root.nvidiaVramTotal   = parseInt(kv["NVIDIA_VRAM_TOTAL"])|| 0
            if (kv["NVIDIA_POWER"])        root.nvidiaPower       = parseFloat(kv["NVIDIA_POWER"])   || 0
            if (kv["NVIDIA_POWER_LIMIT"])  root.nvidiaPowerLimit  = parseFloat(kv["NVIDIA_POWER_LIMIT"]) || 0
            if (kv["NVIDIA_CLOCK"])        root.nvidiaClock       = parseInt(kv["NVIDIA_CLOCK"])     || 0
            if (kv["NVIDIA_CLOCK_MEM"])    root.nvidiaClockMem    = parseInt(kv["NVIDIA_CLOCK_MEM"]) || 0
            if (kv["NVIDIA_DRIVER"])       root.nvidiaDriver      = kv["NVIDIA_DRIVER"] || "—"
        }
    }

    // ── UI ────────────────────────────────────────────────
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

        Rectangle {
            width: parent.width; height: 3; radius: 2
            anchors.top: parent.top
            color: Theme.accent2
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            id: col
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            anchors.topMargin: 16
            spacing: 10

            // ── Intel UHD ──────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: intelCol.implicitHeight + 16
                radius: 8
                color: Theme.surface1
                border.color: Theme.accent
                border.width: 1

                ColumnLayout {
                    id: intelCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10; anchors.topMargin: 10
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text { text: "󰍹"; font.pixelSize: 14; color: Theme.accent }
                        Column {
                            spacing: 1
                            Text { text: root.intelName; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                            Text { text: "Integrada  ·  siempre activa"; font.pixelSize: 9; color: Theme.muted3 }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 52; height: 18; radius: 9
                            color: Theme.successSurface
                            border.color: Theme.success; border.width: 1
                            Text { anchors.centerIn: parent; text: "Activa"; font.pixelSize: 9; color: Theme.success }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Rectangle {
                            Layout.fillWidth: true; height: 40; radius: 6; color: Theme.surface2
                            Column { anchors.centerIn: parent; spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.intelFreq > 0 ? root.intelFreq + " MHz" : "—"
                                    font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Freq GT"; font.pixelSize: 9; color: Theme.muted1 }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 40; radius: 6; color: Theme.surface2
                            Column { anchors.centerIn: parent; spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.intelTemp > 0 ? root.intelTemp + "°C" : "N/D"
                                    font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.sky
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Temp"; font.pixelSize: 9; color: Theme.muted1 }
                            }
                        }
                    }
                }
            }

            // ── NVIDIA ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: nvidiaCol.implicitHeight + 16
                radius: 8
                color: Theme.surface1
                border.color: root.nvidiaActive ? Theme.accent2 : Theme.surface3
                border.width: 1

                ColumnLayout {
                    id: nvidiaCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10; anchors.topMargin: 10
                    spacing: 8

                    // Header
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "󰍹"; font.pixelSize: 14
                            color: root.nvidiaActive ? Theme.accent2 : Theme.muted3
                        }
                        Column {
                            spacing: 1
                            Text {
                                text: root.nvidiaName
                                font.pixelSize: 11; font.weight: Font.DemiBold
                                color: root.nvidiaActive ? Theme.text : Theme.muted3
                            }
                            Text {
                                text: root.nvidiaActive ? "Driver: " + root.nvidiaDriver : "Driver inactivo (Optimus)"
                                font.pixelSize: 9; color: Theme.muted3
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 60; height: 18; radius: 9
                            color: root.nvidiaActive ? Theme.accentDim : Theme.surface2
                            border.color: root.nvidiaActive ? Theme.accent2 : Theme.surface3
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: root.nvidiaActive ? "Activa" : "Apagada"
                                font.pixelSize: 9
                                color: root.nvidiaActive ? Theme.accent2 : Theme.muted3
                            }
                        }
                    }

                    // Stats — only when active
                    ColumnLayout {
                        visible: root.nvidiaActive
                        Layout.fillWidth: true
                        spacing: 6

                        // Util + Temp + Power
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { label: "Uso GPU", val: root.nvidiaUtil + "%",   col: Theme.accent2 },
                                    { label: "Temp",    val: root.nvidiaTemp + "°C",  col: root.nvidiaTemp >= 80 ? Theme.error : Theme.sky },
                                    { label: "Potencia",val: root.nvidiaPower.toFixed(1) + " W", col: Theme.warning }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true; height: 40; radius: 6; color: Theme.surface2
                                    Column { anchors.centerIn: parent; spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.val
                                            font.pixelSize: 12; font.weight: Font.DemiBold; color: modelData.col
                                        }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.pixelSize: 9; color: Theme.muted1 }
                                    }
                                }
                            }
                        }

                        // VRAM bar
                        Column {
                            Layout.fillWidth: true; spacing: 3
                            RowLayout {
                                width: parent.width
                                Text { text: "VRAM"; font.pixelSize: 10; color: Theme.muted1 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.nvidiaVramUsed + " / " + root.nvidiaVramTotal + " MB"
                                    font.pixelSize: 10; color: Theme.text
                                }
                            }
                            Rectangle {
                                width: parent.width; height: 8; radius: 3; color: Theme.surface2
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: root.nvidiaVramTotal > 0 ? Math.max(4, parent.width * root.nvidiaVramUsed / root.nvidiaVramTotal) : 4
                                    color: Theme.accent2
                                    Behavior on width { NumberAnimation { duration: 150 } }
                                }
                            }
                        }

                        // Clocks
                        RowLayout {
                            spacing: 6
                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 6; color: Theme.surface2
                                Column { anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.nvidiaClock + " MHz"
                                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "GPU clock"; font.pixelSize: 9; color: Theme.muted1 }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 6; color: Theme.surface2
                                Column { anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.nvidiaClockMem + " MHz"
                                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Mem clock"; font.pixelSize: 9; color: Theme.muted1 }
                                }
                            }
                        }
                    }

                    // Inactive hint
                    Text {
                        visible: !root.nvidiaActive
                        Layout.fillWidth: true
                        text: "La GPU NVIDIA se activa automáticamente al ejecutar apps que la requieran (PRIME Offload)."
                        font.pixelSize: 10; color: Theme.muted3
                        wrapMode: Text.WordWrap
                        bottomPadding: 2
                    }
                }
            }

            Item { height: 0 }
        }
    }
}

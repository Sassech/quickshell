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
    property string cpuModel: "—"
    property int nCores: 0
    property var corePcts: []
    property var coreTemps: []
    property int pkgTemp: 0
    property int avgFreq: 0
    property int maxFreq: 0
    property string governor: "—"
    property string epp: "—"

    property color tempColor: {
        if (pkgTemp >= 85) return Theme.error
        if (pkgTemp >= 70) return Theme.warning
        if (pkgTemp >= 55) return Theme.yellow
        return Theme.accent
    }

    onVisibleChanged: { if (visible) fetchData() }

    Timer {
        interval: 500
        running: root.visible
        repeat: true
        onTriggered: fetchData()
    }

    function fetchData() {
        _buf = ""
        cpuProc.running = true
    }

    property string _buf: ""
    Process {
        id: cpuProc
        command: ["bash", Paths.scripts + "/cpu-detail.sh"]
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
            if (kv["MODEL"])      root.cpuModel  = kv["MODEL"]
            if (kv["NCORES"])     root.nCores    = parseInt(kv["NCORES"])    || 0
            if (kv["PKG_TEMP"])   root.pkgTemp   = parseInt(kv["PKG_TEMP"])  || 0
            if (kv["AVG_FREQ"])   root.avgFreq   = parseInt(kv["AVG_FREQ"])  || 0
            if (kv["MAX_FREQ"])   root.maxFreq   = parseInt(kv["MAX_FREQ"])  || 0
            if (kv["GOV"])        root.governor  = kv["GOV"]
            if (kv["EPP"])        root.epp       = kv["EPP"]
            if (kv["CORE_PCTS"])  root.corePcts  = kv["CORE_PCTS"].split(",").map(s => parseInt(s) || 0)
            if (kv["CORE_TEMPS"]) root.coreTemps = kv["CORE_TEMPS"].split(",").map(s => parseInt(s) || 0)
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

        // Header accent stripe
        Rectangle {
            width: parent.width; height: 3; radius: 2
            anchors.top: parent.top
            color: Theme.accent
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

            // Title
            RowLayout {
                spacing: 8
                Text { text: "󰻠"; font.pixelSize: 17; color: root.tempColor }
                Column {
                    spacing: 1
                    Text {
                        text: root.cpuModel
                        font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
                    }
                    Text {
                        text: root.nCores + " threads · " + root.maxFreq + " MHz boost"
                        font.pixelSize: 10; color: Theme.muted1
                    }
                }
                Item { Layout.fillWidth: true }
                Column {
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pkgTemp + "°C"
                        font.pixelSize: 16; font.weight: Font.Bold; color: root.tempColor
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Package"
                        font.pixelSize: 9; color: Theme.muted3
                    }
                }
            }

            // Core load bars — 2 columns of 8
            RowLayout {
                spacing: 6
                // Left column: threads 0-7
                Column {
                    spacing: 3
                    Layout.fillWidth: true
                    Repeater {
                        model: Math.min(8, root.corePcts.length)
                        Row {
                            spacing: 4
                            width: parent.width
                            property int pct:  root.corePcts[index] || 0
                            property int temp: root.coreTemps[Math.floor(index/2)] || 0
                            property color barColor: pct > 80 ? Theme.error : pct > 50 ? Theme.warning : Theme.accent
                            property color tCol: temp >= 80 ? Theme.error : temp >= 65 ? Theme.warning : Theme.muted3

                            Text {
                                text: "T" + index
                                font.pixelSize: 9; font.family: "monospace"
                                color: Theme.muted3
                                width: 16
                            }
                            Rectangle {
                                height: 10; radius: 3
                                color: Theme.surface2
                                width: 88
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: Math.max(4, parent.width * parent.parent.pct / 100)
                                    color: parent.parent.barColor
                                    Behavior on width { NumberAnimation { duration: 200 } }
                                }
                            }
                            Text {
                                text: (parent.pct < 10 ? " " : "") + parent.pct + "%"
                                font.pixelSize: 9; font.family: "monospace"
                                color: Theme.muted1
                                width: 26
                            }
                            Text {
                                text: parent.temp + "°"
                                font.pixelSize: 9; font.family: "monospace"
                                color: parent.tCol
                                width: 22
                                visible: index % 2 === 0
                                opacity: 1
                            }
                            Text {
                                text: parent.temp + "°"
                                font.pixelSize: 9; font.family: "monospace"
                                color: parent.tCol
                                width: 22
                                visible: index % 2 !== 0
                                opacity: 0.45
                            }
                        }
                    }
                }
                // Right column: threads 8-15
                Column {
                    spacing: 3
                    Layout.fillWidth: true
                    visible: root.corePcts.length > 8
                    Repeater {
                        model: Math.max(0, root.corePcts.length - 8)
                        Row {
                            spacing: 4
                            width: parent.width
                            property int pct:  root.corePcts[index + 8] || 0
                            property int temp: root.coreTemps[Math.floor(index/2) + 4] || 0
                            property color barColor: pct > 80 ? Theme.error : pct > 50 ? Theme.warning : Theme.accent
                            property color tCol: temp >= 80 ? Theme.error : temp >= 65 ? Theme.warning : Theme.muted3

                            Text {
                                text: "T" + (index + 8)
                                font.pixelSize: 9; font.family: "monospace"
                                color: Theme.muted3
                                width: 16
                            }
                            Rectangle {
                                height: 10; radius: 3
                                color: Theme.surface2
                                width: 72
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: Math.max(4, parent.width * parent.parent.pct / 100)
                                    color: parent.parent.barColor
                                    Behavior on width { NumberAnimation { duration: 200 } }
                                }
                            }
                            Text {
                                text: (parent.pct < 10 ? " " : "") + parent.pct + "%"
                                font.pixelSize: 9; font.family: "monospace"
                                color: Theme.muted1
                                width: 26
                            }
                            Text {
                                text: parent.temp + "°"
                                font.pixelSize: 9; font.family: "monospace"
                                color: parent.tCol
                                width: 22
                                visible: index % 2 === 0
                                opacity: 1
                            }
                            Text {
                                text: parent.temp + "°"
                                font.pixelSize: 9; font.family: "monospace"
                                color: parent.tCol
                                width: 22
                                visible: index % 2 !== 0
                                opacity: 0.45
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }

            // Stats
            RowLayout {
                spacing: 6
                // Freq
                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 8; color: Theme.surface2
                    Column { anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.avgFreq > 0 ? root.avgFreq + " MHz" : "—"
                            font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Freq actual"
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
                // Governor
                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 8; color: Theme.surface2
                    Column { anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.governor || "—"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.accent2
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Gobernador"
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
                // EPP
                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 8; color: Theme.surface2
                    Column { anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.epp ? root.epp.replace("balance_", "bal_") : "—"
                            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.sky
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "EPP"
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
            }

            Item { height: 0 }
        }
    }
}

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
    property string nvmeModel: "—"
    property string nvmeFw: "—"
    property int nvmeTemp: 0
    property int totalGb: 0
    property int usedGb: 0
    property int availGb: 0
    property int pct: 0
    property string readMbs: "0.0"
    property string writeMbs: "0.0"

    property color accentColor: {
        if (pct >= 90) return Theme.error
        if (pct >= 75) return Theme.warning
        return Theme.success
    }

    property color tempColor: {
        if (nvmeTemp >= 65) return Theme.error
        if (nvmeTemp >= 50) return Theme.warning
        return Theme.sky
    }

    onVisibleChanged: { if (visible) fetchData() }

    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        onTriggered: fetchData()
    }

    function fetchData() {
        _buf = ""
        diskProc.running = true
    }

    property string _buf: ""
    Process {
        id: diskProc
        command: ["bash", Paths.scripts + "/disk-detail.sh"]
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
            if (kv["MODEL"])     root.nvmeModel  = kv["MODEL"]
            if (kv["FW"])        root.nvmeFw     = kv["FW"]
            if (kv["TEMP"])      root.nvmeTemp   = parseInt(kv["TEMP"])   || 0
            if (kv["TOTAL"])     root.totalGb    = parseInt(kv["TOTAL"])  || 0
            if (kv["USED"])      root.usedGb     = parseInt(kv["USED"])   || 0
            if (kv["AVAIL"])     root.availGb    = parseInt(kv["AVAIL"])  || 0
            if (kv["PCT"])       root.pct        = parseInt(kv["PCT"])    || 0
            if (kv["READ_MBS"])  root.readMbs    = kv["READ_MBS"]
            if (kv["WRITE_MBS"]) root.writeMbs   = kv["WRITE_MBS"]
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
        width: 280
        height: col.implicitHeight + 24
        radius: 12
        color: Theme.base
        border.color: Theme.surface2
        border.width: 1

        Rectangle {
            width: parent.width; height: 3; radius: 2
            anchors.top: parent.top
            color: root.accentColor
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
                Text { text: "󰋊"; font.pixelSize: 17; color: root.accentColor }
                Column {
                    spacing: 1
                    Text {
                        text: root.nvmeModel
                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        elide: Text.ElideRight
                        width: 170
                    }
                    Text {
                        text: "FW: " + root.nvmeFw + "  ·  " + root.totalGb + " GB"
                        font.pixelSize: 10; color: Theme.muted1
                    }
                }
                Item { Layout.fillWidth: true }
                Column {
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.nvmeTemp + "°C"
                        font.pixelSize: 15; font.weight: Font.Bold; color: root.tempColor
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "NVMe"
                        font.pixelSize: 9; color: Theme.muted3
                    }
                }
            }

            // Usage bar
            Column {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    width: parent.width
                    Text {
                        text: "Espacio usado"
                        font.pixelSize: 10; color: Theme.muted1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.pct + "%  (" + root.usedGb + " / " + root.totalGb + " GB)"
                        font.pixelSize: 10; color: Theme.text
                    }
                }

                Rectangle {
                    width: parent.width; height: 12; radius: 4
                    color: Theme.surface2
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: Math.max(6, parent.width * root.pct / 100)
                        color: root.accentColor
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }

            // Stats row
            RowLayout {
                spacing: 6
                // Libre
                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 8; color: Theme.surface2
                    Column { anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.availGb + " GB"
                            font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.success
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Libre"
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
                // Lectura
                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 8; color: Theme.surface2
                    Column { anchors.centerIn: parent; spacing: 2
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Text {
                                text: "↓"
                                font.pixelSize: 10; color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.readMbs + " MB/s"
                                font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Lectura"
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
                // Escritura
                Rectangle {
                    Layout.fillWidth: true; height: 46; radius: 8; color: Theme.surface2
                    Column { anchors.centerIn: parent; spacing: 2
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Text {
                                text: "↑"
                                font.pixelSize: 10; color: Theme.accent2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.writeMbs + " MB/s"
                                font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Escritura"
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
            }

            Item { height: 0 }
        }
    }
}

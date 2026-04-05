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

    // ── Data ─────────────────────────────────────────────
    property int memTotal: 0
    property int memUsed: 0
    property int memFree: 0
    property int memAvail: 0
    property int memPercent: 0
    property int buffers: 0
    property int cached: 0
    property int swapCached: 0
    property int active: 0
    property int inactive: 0
    property int swapTotal: 0
    property int swapUsed: 0
    property int swapFree: 0
    property int swapPercent: 0
    property int anonPages: 0
    property int mapped: 0
    property int shmem: 0
    property int dirty: 0
    property int writeback: 0
    property int slab: 0
    property int sReclaimable: 0
    property int sUnreclaim: 0

    property color memColor: {
        if (memPercent >= 90) return Theme.error
        if (memPercent >= 75) return Theme.warning
        if (memPercent >= 60) return Theme.yellow
        return Theme.accent
    }

    property color swapColor: {
        if (swapPercent >= 75) return Theme.error
        if (swapPercent >= 50) return Theme.warning
        return Theme.accent
    }

    onVisibleChanged: { if (visible) fetchData() }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: fetchData()
    }

    function fetchData() {
        _buf = ""
        ramProc.running = true
    }

    property string _buf: ""
    Process {
        id: ramProc
        command: ["bash", root._scriptsPath + "/ram-detail.sh"]
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
            if (kv["MEM_TOTAL"])       root.memTotal      = parseInt(kv["MEM_TOTAL"])      || 0
            if (kv["MEM_USED"])        root.memUsed       = parseInt(kv["MEM_USED"])       || 0
            if (kv["MEM_FREE"])        root.memFree       = parseInt(kv["MEM_FREE"])       || 0
            if (kv["MEM_AVAIL"])       root.memAvail      = parseInt(kv["MEM_AVAIL"])      || 0
            if (kv["MEM_PERCENT"])     root.memPercent    = parseInt(kv["MEM_PERCENT"])    || 0
            if (kv["BUFFERS"])         root.buffers       = parseInt(kv["BUFFERS"])        || 0
            if (kv["CACHED"])          root.cached        = parseInt(kv["CACHED"])         || 0
            if (kv["SWAP_CACHED"])     root.swapCached    = parseInt(kv["SWAP_CACHED"])    || 0
            if (kv["ACTIVE"])          root.active        = parseInt(kv["ACTIVE"])         || 0
            if (kv["INACTIVE"])        root.inactive      = parseInt(kv["INACTIVE"])       || 0
            if (kv["SWAP_TOTAL"])      root.swapTotal     = parseInt(kv["SWAP_TOTAL"])     || 0
            if (kv["SWAP_USED"])       root.swapUsed      = parseInt(kv["SWAP_USED"])      || 0
            if (kv["SWAP_FREE"])       root.swapFree      = parseInt(kv["SWAP_FREE"])      || 0
            if (kv["SWAP_PERCENT"])    root.swapPercent   = parseInt(kv["SWAP_PERCENT"])   || 0
            if (kv["ANON_PAGES"])      root.anonPages     = parseInt(kv["ANON_PAGES"])     || 0
            if (kv["MAPPED"])          root.mapped        = parseInt(kv["MAPPED"])         || 0
            if (kv["SHMEM"])           root.shmem         = parseInt(kv["SHMEM"])          || 0
            if (kv["DIRTY"])           root.dirty         = parseInt(kv["DIRTY"])          || 0
            if (kv["WRITEBACK"])       root.writeback     = parseInt(kv["WRITEBACK"])      || 0
            if (kv["SLAB"])            root.slab          = parseInt(kv["SLAB"])           || 0
            if (kv["SRECLAIMABLE"])    root.sReclaimable  = parseInt(kv["SRECLAIMABLE"])   || 0
            if (kv["SUNRECLAIM"])      root.sUnreclaim    = parseInt(kv["SUNRECLAIM"])     || 0
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
        width: 340
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
                Text { text: ""; font.pixelSize: 17; color: root.memColor }
                Column {
                    spacing: 1
                    Text {
                        text: "Memoria RAM"
                        font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
                    }
                    Text {
                        text: (root.memTotal / 1024).toFixed(1) + " GB total · " + 
                              (root.memAvail / 1024).toFixed(1) + " GB disponible"
                        font.pixelSize: 10; color: Theme.muted1
                    }
                }
                Item { Layout.fillWidth: true }
                Column {
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.memPercent + "%"
                        font.pixelSize: 16; font.weight: Font.Bold; color: root.memColor
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "En uso"
                        font.pixelSize: 9; color: Theme.muted3
                    }
                }
            }

            // Memory usage bar
            Column {
                spacing: 4
                Layout.fillWidth: true
                
                Rectangle {
                    width: parent.width; height: 22; radius: 6
                    color: Theme.surface2
                    
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: Math.max(4, parent.width * root.memPercent / 100)
                        color: root.memColor
                        Behavior on width { NumberAnimation { duration: 400 } }
                        
                        Text {
                            anchors.centerIn: parent
                            text: (root.memUsed / 1024).toFixed(1) + " GB / " + 
                                  (root.memTotal / 1024).toFixed(1) + " GB"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.memPercent > 40 ? Theme.base : Theme.text
                        }
                    }
                }
            }

            // Swap usage bar (if swap exists)
            Column {
                spacing: 4
                Layout.fillWidth: true
                visible: root.swapTotal > 0
                
                Text {
                    text: "Swap"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.muted1
                }
                
                Rectangle {
                    width: parent.width; height: 18; radius: 6
                    color: Theme.surface2
                    
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: root.swapPercent > 0 ? Math.max(4, parent.width * root.swapPercent / 100) : 0
                        color: root.swapColor
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: (root.swapUsed / 1024).toFixed(1) + " GB / " + 
                              (root.swapTotal / 1024).toFixed(1) + " GB"
                        font.pixelSize: 9
                        color: root.swapPercent > 40 ? Theme.base : Theme.muted1
                    }
                }
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }

            // Memory breakdown
            Text {
                text: "Desglose de memoria"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.text
            }

            GridLayout {
                columns: 2
                rowSpacing: 6
                columnSpacing: 8
                Layout.fillWidth: true

                // Active
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.active / 1024).toFixed(2) + " GB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Activa"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }
                
                // Inactive
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.inactive / 1024).toFixed(2) + " GB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Inactiva"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }

                // Buffers
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.buffers + " MB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.accent2
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Buffers"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }

                // Cached
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.cached / 1024).toFixed(2) + " GB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.sky
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Caché"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }

                // Anonymous Pages
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.anonPages / 1024).toFixed(2) + " GB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Anónimas"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }

                // Mapped
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.mapped + " MB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Mapeadas"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }

                // Shared Memory
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.shmem + " MB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Compartida"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }

                // Slab
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 8; color: Theme.surface2
                    Column { 
                        anchors.centerIn: parent; spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.slab + " MB"
                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Slab (kernel)"
                            font.pixelSize: 9; color: Theme.muted1
                        }
                    }
                }
            }

            Item { height: 0 }
        }
    }
}

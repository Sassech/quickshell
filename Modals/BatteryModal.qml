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

    // ── Data read when opened ────────────────────────────────────────────
    property real health: 0          // %
    property real capacityWh: 0      // Wh
    property int cycleCount: 0
    property string currentEpp: ""   // raw EPP string
    property string currentMode: ""  // "powersaver" | "balanced" | "performance"

    property bool applying: false

    onVisibleChanged: {
        if (visible) {
            root.health = 0
            root.capacityWh = 0
            root.currentEpp = ""
            root.currentMode = ""
            chargeFull.running = true
            chargeDesign.running = true
            voltageNow.running = true
            cycles.running = true
            eppRead.running = true
        }
    }

    Timer {
        interval: 10000
        running: root.visible
        repeat: true
        onTriggered: {
            chargeFull.running = true
            chargeDesign.running = true
            voltageNow.running = true
            cycles.running = true
            eppRead.running = true
        }
    }

    // EPP → mode label
    function eppToMode(epp) {
        if (epp === "power" || epp === "balance_power") return "powersaver"
        if (epp === "performance") return "performance"
        return "balanced"
    }

    function modeLabel(m) {
        if (m === "powersaver") return "Ahorro"
        if (m === "performance") return "Rendimiento"
        return "Balanceado"
    }

    function modeIcon(m) {
        if (m === "powersaver") return "🌿"
        if (m === "performance") return "⚡"
        return "⚖️"
    }

    function modeColor(m) {
        if (m === "powersaver") return Theme.success
        if (m === "performance") return Theme.error
        return Theme.accent
    }

    // ── Sysfs readers ───────────────────────────────────────────────────
    property string _cfBuf: ""; property string _cdBuf: ""; property string _vnBuf: ""; property string _ccBuf: ""; property string _eppBuf: ""
    property real _chargeFull: 0; property real _chargeDesign: 0; property real _voltNow: 0

    Process {
        id: chargeFull
        command: ["cat", "/sys/class/power_supply/BAT0/charge_full"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._cfBuf += data }
        onExited: {
            root._chargeFull = parseFloat(root._cfBuf.trim()) || 0
            root._cfBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: chargeDesign
        command: ["cat", "/sys/class/power_supply/BAT0/charge_full_design"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._cdBuf += data }
        onExited: {
            root._chargeDesign = parseFloat(root._cdBuf.trim()) || 0
            root._cdBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: voltageNow
        command: ["cat", "/sys/class/power_supply/BAT0/voltage_now"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._vnBuf += data }
        onExited: {
            root._voltNow = parseFloat(root._vnBuf.trim()) || 0
            root._vnBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: cycles
        command: ["cat", "/sys/class/power_supply/BAT0/cycle_count"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._ccBuf += data }
        onExited: {
            root.cycleCount = parseInt(root._ccBuf.trim()) || 0
            root._ccBuf = ""
        }
    }
    Process {
        id: eppRead
        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._eppBuf += data }
        onExited: {
            root.currentEpp = root._eppBuf.trim()
            root.currentMode = root.eppToMode(root.currentEpp)
            root._eppBuf = ""
        }
    }

    function _calcStats() {
        if (root._chargeFull > 0 && root._chargeDesign > 0) {
            root.health = Math.round(root._chargeFull / root._chargeDesign * 100 * 10) / 10
        }
        if (root._chargeFull > 0 && root._voltNow > 0) {
            root.capacityWh = Math.round(root._chargeFull * root._voltNow / 1e12 * 10) / 10
        }
    }

    Process {
        id: applyProc
        property string _pendingMode: ""
        onExited: {
            root.applying = false
            root.currentMode = _pendingMode
        }
    }

    function applyMode(mode) {
        if (root.applying) return
        root.applying = true
        applyProc._pendingMode = mode
        applyProc.command = ["sudo", "/home/sassech/.config/quickshell/scripts/set-power-mode.sh", mode]
        applyProc.running = true
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
        width: 280
        height: col.implicitHeight + 24
        radius: 12
        color: Theme.base
        border.color: Theme.surface2
        border.width: 1

        // Header accent
        Rectangle {
            width: parent.width
            height: 3
            radius: 2
            anchors.top: parent.top
            color: Theme.accent
            Rectangle { width: parent.width / 2; height: parent.height; anchors.right: parent.right; color: Theme.accent2 }
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
            spacing: 12

            // Title row
            RowLayout {
                spacing: 8
                Text {
                    text: "🔋"
                    font.pixelSize: 18
                }
                Text {
                    text: "Batería"
                    font.pixelSize: 14
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

            // Stats row
            RowLayout {
                spacing: 6

                // Salud
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.health > 0 ? root.health + "%" : "—"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Salud"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }

                // Capacidad
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.capacityWh > 0 ? root.capacityWh + " Wh" : "—"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Capacidad"
                            font.pixelSize: 10
                            color: Theme.muted1
                        }
                    }
                }

                // Ciclos
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 8
                    color: Theme.surface2
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.cycleCount > 0 ? String(root.cycleCount) : "N/A"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ciclos"
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
            }

            // Power mode section
            Text {
                text: "Modo de Energía"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.muted1
                leftPadding: 2
            }

            RowLayout {
                spacing: 6

                Repeater {
                    model: ["powersaver", "balanced", "performance"]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: 8
                        color: root.currentMode === modelData ? Qt.darker(root.modeColor(modelData), 3.5) : Theme.surface2
                        border.color: root.currentMode === modelData ? root.modeColor(modelData) : "transparent"
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
                                font.weight: root.currentMode === modelData ? Font.DemiBold : Font.Normal
                                color: root.currentMode === modelData ? root.modeColor(modelData) : Theme.muted1
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.applying && root.currentMode !== modelData
                            onClicked: root.applyMode(modelData)
                        }
                    }
                }
            }

            Item { height: 0 } // bottom padding
        }
    }
}

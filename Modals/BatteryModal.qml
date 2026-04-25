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

    // ── Data read when opened ────────────────────────────────────────────
    property bool batteryAvailable: false
    property string batteryPath: ""
    property string energyMode: "" // "energy" | "charge" | ""
    property bool eppAvailable: true

    property real health: 0          // %
    property real capacityWh: 0      // Wh
    property int cycleCount: 0
    property string currentEpp: ""   // raw EPP string
    property string currentMode: ""  // "powersaver" | "balanced" | "performance"

    property bool applying: false

    onVisibleChanged: {
        if (visible) {
            root.batteryAvailable = false
            root.batteryPath = ""
            root.energyMode = ""
            root.eppAvailable = true
            root.health = 0
            root.capacityWh = 0
            root.currentEpp = ""
            root.currentMode = ""
            detectProc.running = true
        }
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: {
            if (!root.batteryPath) {
                detectProc.running = true
            } else {
                refreshBatteryFiles()
            }
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
    property string _efBuf: ""; property string _edBuf: ""
    property real _chargeFull: 0; property real _chargeDesign: 0; property real _voltNow: 0
    property real _energyFull: 0; property real _energyDesign: 0

    function refreshBatteryFiles() {
        if (!root.batteryAvailable) return
        if (root.energyMode === "energy") {
            energyFull.running = true
            energyDesign.running = true
        } else if (root.energyMode === "charge") {
            chargeFull.running = true
            chargeDesign.running = true
            voltageNow.running = true
        }
        cycles.running = true
        eppRead.running = true
    }

    // ── Detect battery and energy/charge mode ─────────────────
    property string _detectBuf: ""
    Process {
        id: detectProc
        command: ["sh", "-c",
            "BAT=$(ls -1 /sys/class/power_supply 2>/dev/null | grep '^BAT' | head -1); " +
            "if [ -z \"$BAT\" ]; then exit 0; fi; " +
            "BASE=/sys/class/power_supply/$BAT; " +
            "if [ -r \"$BASE/energy_full\" ]; then MODE=energy; " +
            "elif [ -r \"$BASE/charge_full\" ]; then MODE=charge; else MODE=none; fi; " +
            "echo \"$BASE|$MODE\""
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._detectBuf += data
        }
        onExited: {
            const v = root._detectBuf.trim()
            root._detectBuf = ""
            if (v && v.indexOf("|") > 0) {
                var parts = v.split("|")
                root.batteryPath = parts[0]
                root.energyMode = parts[1]
                root.batteryAvailable = parts[1] !== "none"
            } else {
                root.batteryPath = ""
                root.energyMode = ""
                root.batteryAvailable = false
            }
            refreshBatteryFiles()
        }
    }

    Process {
        id: chargeFull
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/charge_full\" 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._cfBuf += data }
        onExited: {
            root._chargeFull = parseFloat(root._cfBuf.trim()) || 0
            root._cfBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: chargeDesign
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/charge_full_design\" 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._cdBuf += data }
        onExited: {
            root._chargeDesign = parseFloat(root._cdBuf.trim()) || 0
            root._cdBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: voltageNow
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/voltage_now\" 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._vnBuf += data }
        onExited: {
            root._voltNow = parseFloat(root._vnBuf.trim()) || 0
            root._vnBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: cycles
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/cycle_count\" 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._ccBuf += data }
        onExited: {
            root.cycleCount = parseInt(root._ccBuf.trim()) || 0
            root._ccBuf = ""
        }
    }
    Process {
        id: energyFull
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/energy_full\" 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._efBuf += data }
        onExited: {
            root._energyFull = parseFloat(root._efBuf.trim()) || 0
            root._efBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: energyDesign
        command: ["sh", "-c", "cat \"" + root.batteryPath + "/energy_full_design\" 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._edBuf += data }
        onExited: {
            root._energyDesign = parseFloat(root._edBuf.trim()) || 0
            root._edBuf = ""
            root._calcStats()
        }
    }
    Process {
        id: eppRead
        command: ["sh", "-c",
            "if [ -r /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then " +
            "cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference; fi"]
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root._eppBuf += data }
        onExited: {
            root.currentEpp = root._eppBuf.trim()
            root.currentMode = root.eppToMode(root.currentEpp)
            root.eppAvailable = root.currentEpp !== ""
            root._eppBuf = ""
        }
    }

    function _calcStats() {
        if (root.energyMode === "energy") {
            if (root._energyFull > 0 && root._energyDesign > 0) {
                root.health = Math.round(root._energyFull / root._energyDesign * 100 * 10) / 10
            }
            if (root._energyFull > 0) {
                root.capacityWh = Math.round(root._energyFull / 1e6 * 10) / 10
            }
        } else if (root.energyMode === "charge") {
            if (root._chargeFull > 0 && root._chargeDesign > 0) {
                root.health = Math.round(root._chargeFull / root._chargeDesign * 100 * 10) / 10
            }
            if (root._chargeFull > 0 && root._voltNow > 0) {
                root.capacityWh = Math.round(root._chargeFull * root._voltNow / 1e12 * 10) / 10
            }
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
        applyProc.command = ["sudo", root._scriptsPath + "/set-power-mode.sh", mode]
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
             // ── Absorb clicks to prevent propagation ──────
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
                    text: "󰁹"
                    font.pixelSize: 17
                    color: Theme.accent
                }
                Text {
                    text: "Batería"
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
                visible: !root.batteryAvailable
                text: "Sin batería detectada"
                font.pixelSize: 11
                color: Theme.muted1
            }

            Text {
                visible: root.batteryAvailable && !root.eppAvailable
                text: "EPP no disponible"
                font.pixelSize: 10
                color: Theme.muted2
            }

            // Stats row
            RowLayout {
                spacing: 6
                visible: root.batteryAvailable

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
                visible: root.batteryAvailable
            }

            // Power mode section
            Text {
                text: "Modo de Energía"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.muted1
                leftPadding: 2
                visible: root.batteryAvailable
            }

            RowLayout {
                spacing: 6
                visible: root.batteryAvailable

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
                            enabled: root.eppAvailable && !root.applying && root.currentMode !== modelData
                            onClicked: root.applyMode(modelData)
                        }
                    }
                }
            }

            Item { height: 0 } // bottom padding
        }
    }
}

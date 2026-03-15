import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true

    // ── State ─────────────────────────────────────────────────────────────
    property bool   available:    false
    property bool   powered:      false
    property bool   scanning:     false
    property bool   working:      false
    property string statusMsg:    ""

    // devices: [{mac, name, paired, connected, trusted}]
    property var pairedDevices:  []
    property var nearbyDevices:  []

    // codec info map: { "AA:BB:CC:DD:EE:FF" → {codec, active, rate, profiles:[{id,label}]} }
    property var    codecData:        ({})
    property var    _codecQueue:      []
    property string _currentCodecMac: ""
    property string _codecBuf:        ""

    function _runNextCodecQuery() {
        if (_codecQueue.length === 0 || codecProc.running) return
        _currentCodecMac = _codecQueue[0]
        _codecQueue      = _codecQueue.slice(1)
        _codecBuf        = ""
        codecProc.command = ["bash", "-c",
            "/home/sassech/.config/quickshell/scripts/bt-codec.sh info " + _currentCodecMac]
        codecProc.running = true
    }

    function setCodec(mac, profile) {
        root.statusMsg = ""
        _currentCodecMac = mac
        setCodecProc.command = ["bash", "-c",
            "/home/sassech/.config/quickshell/scripts/bt-codec.sh set " + mac + " " + profile]
        setCodecProc.running = true
    }

    // ── Auto-stop scan after 13 s (fallback, por si el proceso no termina) ─
    Timer {
        id: scanTimer
        interval: 13000
        onTriggered: {
            if (root.scanning) {
                if (scanOnProc.running) scanOnProc.running = false
                scanOffProc.running = true
                root.scanning = false
            }
        }
    }
    // ── Refresh nearby devices every 3 s while scanning ───────────────
    Timer {
        id: scanRefreshTimer
        interval: 3000
        repeat: true
        running: root.scanning
        onTriggered: {
            if (!nearbyProc.running)
                nearbyProc.running = true
        }
    }
    // ── Refresh codec info every 4 s mientras el modal está abierto ───
    Timer {
        id: codecRefreshTimer
        interval: 4000
        repeat: true
        running: root.visible
        onTriggered: {
            if (codecProc.running || setCodecProc.running) return
            var q = []
            root.pairedDevices.forEach(d => { if (d.connected) q.push(d.mac) })
            if (q.length > 0) {
                root._codecQueue = q
                root._runNextCodecQuery()
            }
        }
    }
    // Stop scan when modal closes
    onVisibleChanged: {
        if (visible) {
            statusMsg = ""
            loadDevices()
        } else {
            if (scanning) { if (scanOnProc.running) scanOnProc.running = false; scanOffProc.running = true; scanning = false }
            scanTimer.stop()
        }
    }

    // ── Data loading ──────────────────────────────────────────────────────
    property string _adapterBuf: ""
    property string _pairedBuf:  ""
    property string _nearbyBuf:  ""

    function loadDevices() {
        root.working = true
        adapterProc.running = true
        pairedProc.running  = true
        nearbyProc.running  = true
    }

    Process {
        id: adapterProc
        command: ["bash", "-c",
            "printf 'show\\n' | bluetoothctl 2>/dev/null | grep 'Powered:' | awk '{print $2}'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._adapterBuf += d }
        onExited: {
            var v = root._adapterBuf.trim().toLowerCase()
            root._adapterBuf = ""
            root.available = v !== ""
            root.powered   = v === "yes"
        }
    }

    // Known devices: one per line "Device <mac> <name>"
    Process {
        id: pairedProc
        command: ["bash", "-c",
            "printf 'devices Paired\\n' | bluetoothctl 2>/dev/null | grep '^Device'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._pairedBuf += d + "\n" }
        onExited: {
            var lines = root._pairedBuf.trim().split("\n")
            root._pairedBuf = ""
            var result = []
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                // "Device AA:BB:CC:DD:EE:FF Device Name"
                var m = l.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
                if (!m) continue
                result.push({ mac: m[1], name: m[2], paired: true, connected: false })
            }
            root.pairedDevices = result
            root.working = false
            // Check which are connected
            connectedProc.running = true
        }
    }

    property string _connBuf: ""
    Process {
        id: connectedProc
        command: ["bash", "-c", "printf 'devices Connected\\n' | bluetoothctl 2>/dev/null | grep '^Device'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._connBuf += d + "\n" }
        onExited: {
            var lines = root._connBuf.trim().split("\n")
            root._connBuf = ""
            var connMacs = {}
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].trim().match(/^Device\s+([0-9A-Fa-f:]{17})/)
                if (m) connMacs[m[1].toUpperCase()] = true
            }
            var updated = root.pairedDevices.map(d => ({
                mac:       d.mac,
                name:      d.name,
                paired:    d.paired,
                connected: !!connMacs[d.mac.toUpperCase()]
            }))
            root.pairedDevices = updated
            // Queue codec queries for all connected devices
            var q = []
            updated.forEach(d => { if (d.connected) q.push(d.mac) })
            root._codecQueue = q
            Qt.callLater(() => root._runNextCodecQuery())
        }
    }

    // Nearby discovered (non-paired) - only useful while scanning
    Process {
        id: nearbyProc
        command: ["bash", "-c", "printf 'devices\\n' | bluetoothctl 2>/dev/null | grep '^Device'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._nearbyBuf += d + "\n" }
        onExited: {
            var lines = root._nearbyBuf.trim().split("\n")
            root._nearbyBuf = ""
            var paired = {}
            root.pairedDevices.forEach(d => paired[d.mac.toUpperCase()] = true)
            var result = []
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                var m = l.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
                if (!m) continue
                if (paired[m[1].toUpperCase()]) continue
                if (m[2].match(/^[0-9A-Fa-f:]{17}$/)) continue  // unnamed
                result.push({ mac: m[1], name: m[2] })
            }
            root.nearbyDevices = result
        }
    }

    // ── BT Actions ────────────────────────────────────────────────────────
    Process { id: powerProc;     command: ["bash", "-c", ""]
        onExited: Qt.callLater(() => { root.working = false; root.loadDevices() }) }
    function togglePower() {
        root.working = true
        powerProc.command = ["bash", "-c",
            "bluetoothctl power " + (root.powered ? "off" : "on") + " 2>/dev/null"]
        powerProc.running = true
    }

    // scan on: --timeout mantiene el proceso vivo (y el discovery activo) durante 12 s
    Process {
        id: scanOnProc
        command: ["bash", "-c", "bluetoothctl --timeout 12 scan on 2>/dev/null"]
        onExited: {
            // El proceso termina a los 12 s (o si se mató con scan off)
            root.scanning = false
            scanTimer.stop()
            Qt.callLater(() => root.loadDevices())
        }
    }
    Process { id: scanOffProc; command: ["bash", "-c", "bluetoothctl scan off 2>/dev/null"]
        onExited: Qt.callLater(() => root.loadDevices()) }
    function toggleScan() {
        if (root.scanning) {
            root.scanning = false
            scanTimer.stop()
            if (scanOnProc.running) scanOnProc.running = false
            scanOffProc.running = true
        } else {
            root.scanning = true
            scanTimer.restart()
            scanOnProc.running = true
        }
    }

    // ── Codec processes ───────────────────────────────────────────────────
    Process {
        id: codecProc
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._codecBuf += d }
        onExited: {
            try {
                var info = JSON.parse(root._codecBuf.trim())
                var d = root.codecData
                d[root._currentCodecMac.toUpperCase()] = info
                root.codecData = d
            } catch(e) {}
            Qt.callLater(() => root._runNextCodecQuery())
        }
    }

    Process {
        id: setCodecProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            root.statusMsg = ec === 0 ? "✓ Codec aplicado" : "✗ Error al cambiar codec"
            // Re-query codec info para ver el cambio reflejado
            root._codecQueue = [root._currentCodecMac]
            Qt.callLater(() => root._runNextCodecQuery())
        }
    }

    Process { id: btActionProc; command: ["bash", "-c", ""]
        onExited: (ec) => {
            root.working  = false
            root.statusMsg = ec === 0 ? "✓ Listo" : "✗ Error al ejecutar acción"
            Qt.callLater(() => root.loadDevices())
        }
    }
    function connectDevice(mac) {
        root.working = true; root.statusMsg = ""
        btActionProc.command = ["bash", "-c", "bluetoothctl connect " + mac + " 2>/dev/null"]
        btActionProc.running = true
    }
    function disconnectDevice(mac) {
        root.working = true; root.statusMsg = ""
        btActionProc.command = ["bash", "-c", "bluetoothctl disconnect " + mac + " 2>/dev/null"]
        btActionProc.running = true
    }
    function pairDevice(mac) {
        root.working = true; root.statusMsg = "Emparejando..."
        // Usa bt-pair.sh que envía los comandos con delays para que el
        // handshake de bonding complete antes del trust.
        btActionProc.command = ["/home/sassech/.config/quickshell/scripts/bt-pair.sh", mac]
        btActionProc.running = true
    }

    Process { id: forgetProc; command: ["bash", "-c", ""]
        onExited: (ec) => {
            root.working   = false
            root.statusMsg = ec === 0 ? "✓ Dispositivo olvidado" : "✗ Error al olvidar dispositivo"
            Qt.callLater(() => root.loadDevices())
        }
    }
    function forgetDevice(mac) {
        root.working = true; root.statusMsg = ""
        forgetProc.command = ["bash", "-c", "bluetoothctl remove " + mac + " 2>/dev/null"]
        forgetProc.running = true
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    // ── Card ──────────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:            400
        height:           Math.min(620, cardCol.implicitHeight + 32)
        radius:           14
        color:            Theme.base
        clip:             true

        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: "transparent"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
            border.width: 1
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: cardCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            spacing: 0

            // ── Header ────────────────────────────────────────────────────
            Item {
                width: parent.width; height: 50

                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 10

                    Text {
                        text: "󰂯"; font.pixelSize: 20
                        color: root.powered ? Theme.accent : Theme.muted2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: "Bluetooth"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text }
                        Text {
                            text: !root.available ? "Sin adaptador"
                                : !root.powered    ? "Apagado"
                                : root.scanning    ? "Buscando dispositivos..."
                                : "Encendido"
                            font.pixelSize: 11; color: Theme.muted1
                        }
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    // Scan button
                    Rectangle {
                        visible: root.available && root.powered
                        width: 28; height: 28; radius: 8
                        color: scanMA.containsMouse ? Theme.surface3 : (root.scanning ? Theme.accentSurface : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 14
                            color: root.scanning ? Theme.accent : Theme.muted1
                            RotationAnimation on rotation {
                                running: root.scanning; loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }
                        MouseArea { id: scanMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.toggleScan() }
                    }

                    // Power toggle
                    Rectangle {
                        visible: root.available
                        width: 44; height: 24; radius: 12
                        color: root.powered ? Theme.accent : Theme.surface3
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.powered ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePower() }
                    }

                    // Close
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: btCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 13; color: Theme.muted1 }
                        MouseArea { id: btCloseMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.visible = false }
                    }
                }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // Status / working
            Text {
                visible: root.statusMsg !== ""; topPadding: 8; bottomPadding: 2
                text: root.statusMsg; font.pixelSize: 11
                color: root.statusMsg.startsWith("✓") ? Theme.success : Theme.error
            }
            Text {
                visible: root.working; topPadding: 8; bottomPadding: 2
                text: "Procesando..."; font.pixelSize: 11; color: Theme.muted1
            }

            // No adapter
            Item {
                visible: !root.available
                width: parent.width; height: 80
                Text { anchors.centerIn: parent; text: "No se encontró adaptador Bluetooth"
                    font.pixelSize: 13; color: Theme.muted1 }
            }

            // Off + no devices
            Item {
                visible: root.available && !root.powered
                width: parent.width; height: 60
                Text { anchors.centerIn: parent; text: "Enciende el Bluetooth para ver dispositivos"
                    font.pixelSize: 12; color: Theme.muted1 }
            }

            // ── Paired devices ────────────────────────────────────────────
            Column {
                visible: root.available && root.powered
                width: parent.width; spacing: 4; topPadding: 10

                Text {
                    text: "Dispositivos emparejados"
                    font.pixelSize: 11; font.weight: Font.Normal; color: Theme.muted1
                    bottomPadding: 4
                    visible: root.pairedDevices.length > 0
                }

                Repeater {
                    model: root.pairedDevices

                    delegate: Item {
                        id: deviceItem
                        required property var modelData
                        property string devMac:        modelData.mac.toUpperCase()
                        property var    cInfo:         root.codecData[devMac] ?? null
                        property bool   hasCodec:      modelData.connected
                                                       && cInfo !== null
                                                       && (cInfo.profiles?.length ?? 0) > 0
                        property bool   pendingForget: false

                        width:  parent.width
                        height: deviceRow.height + (hasCodec ? 4 + codecRow.height : 0)

                        Timer {
                            id: forgetCancelTimer
                            interval: 3000
                            onTriggered: deviceItem.pendingForget = false
                        }

                        // ── Device row ───────────────────────────────────
                        Rectangle {
                            id: deviceRow
                            width: parent.width; height: 40; radius: 8
                            color: deviceItem.modelData.connected
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                : Theme.surface2

                            Rectangle {
                                visible: deviceItem.modelData.connected
                                width: 3; height: 20; radius: 2
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                color: Theme.accent
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                                spacing: 8

                                Text { text: "󰂱"; font.pixelSize: 15
                                    color: deviceItem.modelData.connected ? Theme.accent : Theme.muted2 }

                                Column {
                                    Layout.fillWidth: true; spacing: 1
                                    Text { text: deviceItem.modelData.name; font.pixelSize: 12; color: Theme.text
                                        elide: Text.ElideRight; width: parent.width }
                                    Text { text: deviceItem.modelData.mac; font.pixelSize: 9; color: Theme.muted2 }
                                }

                                Rectangle {
                                    width: 84; height: 26; radius: 6
                                    color: deviceItem.modelData.connected ? Theme.error : Theme.accent
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent
                                        text: deviceItem.modelData.connected ? "Desconectar" : "Conectar"
                                        font.pixelSize: 10; color: "white" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (deviceItem.modelData.connected)
                                                root.disconnectDevice(deviceItem.modelData.mac)
                                            else
                                                root.connectDevice(deviceItem.modelData.mac)
                                        }
                                    }
                                }

                                // ── Forget button ────────────────────────────────
                                Rectangle {
                                    id: forgetBtn
                                    width:  deviceItem.pendingForget
                                            ? forgetConfirmLabel.implicitWidth + 16
                                            : 26
                                    height: 26; radius: 6
                                    Behavior on width  { NumberAnimation  { duration: 120 } }
                                    Behavior on color  { ColorAnimation   { duration: 120 } }
                                    color: deviceItem.pendingForget
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                        : (forgetMA.containsMouse
                                            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14)
                                            : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !deviceItem.pendingForget
                                        text: "󰩹"
                                        font.pixelSize: 13
                                        color: forgetMA.containsMouse ? Theme.error : Theme.muted2
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                    Text {
                                        id: forgetConfirmLabel
                                        anchors.centerIn: parent
                                        visible: deviceItem.pendingForget
                                        text: "¿Borrar?"
                                        font.pixelSize: 10
                                        color: Theme.error
                                    }

                                    ToolTip.visible: forgetMA.containsMouse && !deviceItem.pendingForget
                                    ToolTip.text:    "Olvidar dispositivo"
                                    ToolTip.delay:   500

                                    MouseArea {
                                        id: forgetMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked: {
                                            if (!deviceItem.pendingForget) {
                                                deviceItem.pendingForget = true
                                                forgetCancelTimer.restart()
                                            } else {
                                                forgetCancelTimer.stop()
                                                deviceItem.pendingForget = false
                                                root.forgetDevice(deviceItem.modelData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Codec panel (solo si conectado y hay perfiles) ─
                        Rectangle {
                            id: codecRow
                            visible:  deviceItem.hasCodec
                            anchors.top: deviceRow.bottom
                            anchors.topMargin: 4
                            width:  parent.width
                            height: 38
                            radius: 7
                            color:  Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)

                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                spacing: 6

                                Column {
                                    spacing: 1
                                    Text {
                                        text: "Codec: " + (deviceItem.cInfo?.codec ?? "")
                                        font.pixelSize: 10; font.weight: Font.DemiBold
                                        color: Theme.accent
                                    }
                                    Text {
                                        text: deviceItem.cInfo?.bitrate ?? ""
                                        font.pixelSize: 9; color: Theme.muted1
                                        visible: (deviceItem.cInfo?.bitrate ?? "") !== ""
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Repeater {
                                    model: deviceItem.cInfo?.profiles ?? []
                                    delegate: Rectangle {
                                        id: profileBtn
                                        required property var modelData
                                        required property int index
                                        property bool isActive: (deviceItem.cInfo?.active ?? "") === modelData.id

                                        width:  btnLabel.implicitWidth + 12
                                        height: 22; radius: 5
                                        color: isActive
                                            ? Theme.accent
                                            : (btnMA.containsMouse ? Theme.surface3 : Theme.surface2)
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            id: btnLabel
                                            anchors.centerIn: parent
                                            text: profileBtn.modelData.label
                                            font.pixelSize: 9
                                            color: profileBtn.isActive ? "white" : Theme.muted1
                                        }
                                        ToolTip.visible: btnMA.containsMouse && (profileBtn.modelData.bitrate ?? "") !== ""
                                        ToolTip.text:   profileBtn.modelData.bitrate ?? ""
                                        ToolTip.delay:  400

                                        MouseArea {
                                            id: btnMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setCodec(
                                                deviceItem.modelData.mac,
                                                profileBtn.modelData.id
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.pairedDevices.length === 0 && !root.working
                    text: "No hay dispositivos emparejados"
                    font.pixelSize: 12; color: Theme.muted1; topPadding: 8
                }

                // ── Nearby (discovered during scan) ───────────────────────
                Item { width: parent.width; height: 12
                    visible: root.scanning && root.nearbyDevices.length > 0 }

                Text {
                    visible: root.scanning && root.nearbyDevices.length > 0
                    text: "Dispositivos cercanos"
                    font.pixelSize: 11; font.weight: Font.Normal; color: Theme.muted1; bottomPadding: 4
                }

                Repeater {
                    model: root.scanning ? root.nearbyDevices : []

                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 40; radius: 8; color: Theme.surface2

                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                            spacing: 8

                            Text { text: "󰂯"; font.pixelSize: 15; color: Theme.muted2 }

                            Column {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: modelData.name; font.pixelSize: 12; color: Theme.text
                                    elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.mac; font.pixelSize: 9; color: Theme.muted2 }
                            }

                            Rectangle {
                                width: 60; height: 26; radius: 6; color: Theme.surface3
                                Text { anchors.centerIn: parent; text: "Emparejar"
                                    font.pixelSize: 10; color: Theme.text }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pairDevice(modelData.mac) }
                            }
                        }
                    }
                }

                Item { height: 8; width: parent.width }
            }
        }
    }
}

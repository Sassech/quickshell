import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true


    // ── Estado ─────────────────────────────────────────────────────────────
    property var    adapter:   Bluetooth.defaultAdapter
    property bool   available: adapter !== null
    property bool   powered:   adapter ? adapter.enabled : false
    property bool   scanning:  false
    property bool   working:   false
    property string statusMsg: ""

    property int devicesRevision: 0
    property var devices: {
        devicesRevision
        return root.adapter ? root.adapter.devices.values : []
    }

    property int pairedCount: {
        devicesRevision
        var list = devices
        var c = 0
        for (var i = 0; i < list.length; i++) if (list[i].paired) c++
        return c
    }

    property int nearbyCount: {
        devicesRevision
        var list = devices
        var c = 0
        for (var i = 0; i < list.length; i++) if (!list[i].paired) c++
        return c
    }

    property int connectedCount: {
        devicesRevision
        var list = devices
        var c = 0
        for (var i = 0; i < list.length; i++) if (list[i].connected) c++
        return c
    }

    property var pairedList: {
        devicesRevision
        var list = devices
        var out = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].paired) out.push(list[i])
        }
        return out
    }

    property var nearbyList: {
        devicesRevision
        var list = devices
        var out = []
        for (var i = 0; i < list.length; i++) {
            if (!list[i].paired) out.push(list[i])
        }
        return out
    }

    property var    actionDevice: null
    property string actionType: ""
    property bool   _sawConnecting: false
    property int    _connectRetries: 0
    property bool   autoConnectRunning: false
    property var    autoConnectQueue: []
    property var    autoConnectDevice: null

    // codec info map: { "AA:BB:CC:DD:EE:FF" → {codec, active, rate, profiles:[{id,label}]} }
    property var    codecData:        ({})
    property var    _codecQueue:      []
    property string _currentCodecMac: ""
    property string _codecBuf:        ""

    function sanitizeMac(mac) {
        return mac.replace(/[^0-9A-Fa-f:]/g, "")
    }

    function _runNextCodecQuery() {
        if (_codecQueue.length === 0 || codecProc.running) return
        _currentCodecMac = _codecQueue[0]
        _codecQueue      = _codecQueue.slice(1)
        _codecBuf        = ""
        var safeMac = sanitizeMac(_currentCodecMac)
        codecProc.command = ["bash", "-c",
            "\"" + Paths.scripts + "/bt-codec.sh\" info " + safeMac]
        codecProc.running = true
    }

    function setCodec(mac, profile) {
        root.statusMsg = ""
        _currentCodecMac = mac
        var safeMac = sanitizeMac(mac)
        var safeProfile = profile.replace(/[^a-zA-Z0-9_-]/g, "")
        setCodecProc.command = ["bash", "-c",
            "\"" + Paths.scripts + "/bt-codec.sh\" set " + safeMac + " " + safeProfile]
        setCodecProc.running = true
    }

    function resetAction(msg) {
        root.working = false
        root.actionDevice = null
        root.actionType = ""
        root._sawConnecting = false
        root._connectRetries = 0
        if (msg !== undefined) root.statusMsg = msg
        actionTimeout.stop()
        connectRetryTimer.stop()
    }

    function autoConnectTrusted() {
        if (!root.available || !root.powered) return
        if (root.autoConnectRunning) return
        var q = []
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            if (d.paired && d.trusted && d.state !== BluetoothDeviceState.Connecting && !d.connected) q.push(d)
        }
        if (q.length === 0) return
        root.autoConnectQueue = q
        root.autoConnectRunning = true
        root.autoConnectDevice = null
        autoConnectNext()
    }

    function autoConnectNext() {
        if (!root.autoConnectRunning) return
        autoConnectTimer.stop()
        root.autoConnectDevice = null
        if (root.autoConnectQueue.length === 0) {
            root.autoConnectRunning = false
            return
        }
        root.autoConnectDevice = root.autoConnectQueue.shift()
        root.autoConnectQueue = root.autoConnectQueue
        if (root.autoConnectDevice) {
            root.autoConnectDevice.connect()
            autoConnectTimer.restart()
        } else {
            autoConnectNext()
        }
    }

    function togglePower() {
        if (!root.adapter) return
        root.adapter.enabled = !root.adapter.enabled
    }

    function toggleScan() {
        if (!root.powered) return
        if (root.scanning) {
            root.scanning = false
            if (root.adapter) root.adapter.discovering = false
            scanTimer.stop()
        } else {
            root.scanning = true
            if (root.adapter) root.adapter.discovering = true
            scanTimer.restart()
        }
    }

    function connectDevice(device) {
        if (!device) return
        if (!root.powered) {
            root.statusMsg = "✗ Enciende el Bluetooth primero"
            return
        }
        if (device.state === BluetoothDeviceState.Connecting || device.connected) {
            return
        }
        root.actionDevice = device
        root.actionType = "connect"
        root.working = true
        root.statusMsg = "Conectando..."
        device.connect()
        actionTimeout.restart()
    }

    function disconnectDevice(device) {
        if (!device) return
        if (!device.connected) {
            return
        }
        root.actionDevice = device
        root.actionType = "disconnect"
        root.working = true
        root.statusMsg = "Desconectando..."
        device.disconnect()
        actionTimeout.restart()
    }

    function pairDevice(device) {
        if (!device) return
        if (!root.powered) {
            root.statusMsg = "✗ Enciende el Bluetooth primero"
            return
        }
        if (device.pairing || device.paired) {
            return
        }
        root.actionDevice = device
        root.actionType = "pair"
        root.working = true
        root.statusMsg = "Emparejando..."
        device.pair()
        actionTimeout.restart()
    }

    function forgetDevice(device) {
        if (!device) return
        root.actionDevice = device
        root.actionType = "forget"
        root.working = true
        root.statusMsg = "Olvidando..."
        device.forget()
        actionTimeout.restart()
    }

    // ── Auto-stop scan after 13 s ─────────────────────────────────────────
    Timer {
        id: scanTimer
        interval: 13000
        onTriggered: {
            if (root.adapter) root.adapter.discovering = false
            root.scanning = false
        }
    }

    // ── Timer de acciones ─────────────────────────────────────────────────
    Timer {
        id: actionTimeout
        interval: 10000
        onTriggered: {
            if (root.working) resetAction("✗ Tiempo de espera")
        }
    }

    // ── Auto-connect timer ────────────────────────────────────────────────
    Timer {
        id: autoConnectTimer
        interval: 1500
        onTriggered: autoConnectNext()
    }

    // ── Retry connect after failure ──────────────────────────────────────
    Timer {
        id: connectRetryTimer
        interval: 1500
        onTriggered: {
            if (!root.actionDevice || root.actionType !== "connect") return
            root._connectRetries++
            root.statusMsg = "Reintentando (" + root._connectRetries + "/2)..."
            root._sawConnecting = false
            root.actionDevice.connect()
            actionTimeout.restart()
        }
    }

    // ── Refresh codec info every 12 s mientras el modal está abierto ──
    Timer {
        id: codecRefreshTimer
        interval: 12000
        repeat: true
        running: root.visible
        onTriggered: {
            if (codecProc.running || setCodecProc.running) return
            var q = []
            var list = root.adapter ? root.adapter.devices.values : []
            for (var i = 0; i < list.length; i++) {
                if (list[i].connected) q.push(list[i].address)
            }
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
            if (powered) {
                if (root.adapter) {
                    root.adapter.discoverable = true
                    root.adapter.pairable = true
                }
                autoConnectTrusted()
            }
        } else {
            if (root.adapter) {
                root.adapter.discovering = false
                root.adapter.discoverable = false
                root.adapter.pairable = false
            }
            root.scanning = false
            scanTimer.stop()
            actionTimeout.stop()
            autoConnectTimer.stop()
            connectRetryTimer.stop()
            codecRefreshTimer.stop()
        }
    }

    Component.onDestruction: {
        scanTimer.stop()
        actionTimeout.stop()
        autoConnectTimer.stop()
        connectRetryTimer.stop()
        codecRefreshTimer.stop()
        codecProc.running = false
        setCodecProc.running = false
    }

    onPoweredChanged: {
        if (!powered) {
            root.codecData = ({})
            root._codecQueue = []
            root.autoConnectQueue = []
            root.autoConnectRunning = false
            root.autoConnectDevice = null
            resetAction("")
        } else {
            autoConnectTrusted()
        }
    }

    onAdapterChanged: {
        root.devicesRevision++
    }

    // Observa cambios en dispositivos
    Connections {
        target: root.adapter ? root.adapter.devices : null
        function onObjectInsertedPost(object, index) { root.devicesRevision++ }
        function onObjectRemovedPost(object, index) {
            root.devicesRevision++
            if (root.actionType === "forget" && root.actionDevice === object) {
                resetAction("✓ Dispositivo olvidado")
            }
        }
    }

    Instantiator {
        model: root.adapter ? root.adapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() { root.devicesRevision++ }
            function onConnectedChanged() { root.devicesRevision++ }
            function onTrustedChanged() { root.devicesRevision++ }
            function onNameChanged() { root.devicesRevision++ }
            function onDeviceNameChanged() { root.devicesRevision++ }
            function onStateChanged() { root.devicesRevision++ }
        }
    }

    Connections {
        target: root.actionDevice
        function onConnectedChanged() {
            if (!root.actionDevice) return
            if (root.actionType === "connect" && root.actionDevice.connected) {
                root._connectRetries = 0
                resetAction("✓ Conectado")
            } else if (root.actionType === "disconnect" && !root.actionDevice.connected) {
                resetAction("✓ Desconectado")
            }
        }
        function onStateChanged() {
            if (!root.actionDevice) return
            if (root.actionType !== "connect") return
            var s = root.actionDevice.state
            if (s === BluetoothDeviceState.Connecting) {
                root._sawConnecting = true
            } else if (s === BluetoothDeviceState.Disconnected && root._sawConnecting) {
                root._sawConnecting = false
                if (root._connectRetries < 2) {
                    connectRetryTimer.start()
                } else {
                    root._connectRetries = 0
                    resetAction("✗ No se pudo conectar")
                }
            }
        }
        function onPairedChanged() {
            if (!root.actionDevice) return
            if (root.actionType === "pair" && root.actionDevice.paired) {
                root.actionDevice.trusted = true
                resetAction("✓ Emparejado")
            }
        }
        function onPairingChanged() {
            if (!root.actionDevice) return
            if (root.actionType === "pair" && !root.actionDevice.pairing && !root.actionDevice.paired) {
                resetAction("✗ No se pudo emparejar")
            }
        }
    }

    Connections {
        target: root.autoConnectDevice
        function onConnectedChanged() {
            if (root.autoConnectDevice && root.autoConnectDevice.connected) {
                autoConnectTimer.stop()
                autoConnectNext()
            }
        }
        function onStateChanged() {
            if (root.autoConnectDevice
                && root.autoConnectDevice.state === BluetoothDeviceState.Disconnected) {
                // Connection attempt failed, move to next device
                autoConnectTimer.stop()
                autoConnectNext()
            }
        }
    }

    // ── Codec processes ───────────────────────────────────────────────────
    Process {
        id: codecProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => codecProc._buf += d + "\n" }
        onExited: {
            var output = codecProc._buf.trim()
            codecProc._buf = ""
            try {
                var data = JSON.parse(output)
                var mac = root._currentCodecMac.toUpperCase()
                var newData = ({})
                Object.assign(newData, root.codecData)
                newData[mac] = data
                root.codecData = newData
            } catch(e) {}
            root._runNextCodecQuery()
        }
    }

    Process {
        id: setCodecProc
        command: ["bash", "-c", ""]
        onExited: function(ec) {
            root.statusMsg = ec === 0 ? "✓ Codec cambiado" : "✗ Error al cambiar codec"
            Qt.callLater(() => root._runNextCodecQuery())
        }
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    // ── Card ──────────────────────────────────────────────────────────────
    Rectangle {
        id: btCard
        focus: true
        anchors.centerIn: parent
        width:            400
        height:           Math.min(620, cardCol.implicitHeight + 32)
        radius:           14
        color:            Theme.base
        clip:             true

        Keys.onEscapePressed: root.visible = false

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
                    visible: root.pairedList.length > 0
                }

                Repeater {
                    model: root.pairedList

                    delegate: Item {
                        id: deviceItem
                        required property var modelData
                        property string devMac:        modelData.address.toUpperCase()
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
                                    Text { text: deviceItem.modelData.name || deviceItem.modelData.deviceName; font.pixelSize: 12; color: Theme.text
                                        elide: Text.ElideRight; width: parent.width }
                                    Text { text: deviceItem.modelData.address; font.pixelSize: 9; color: Theme.muted2 }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 84; Layout.preferredHeight: 26; radius: 6
                                    color: deviceItem.modelData.connected ? Theme.error : Theme.accent
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent
                                        text: deviceItem.modelData.connected ? "Desconectar" : "Conectar"
                                        font.pixelSize: 10; color: "white" }
                                    MouseArea { anchors.fill: parent
                                        enabled: !root.working
                                        cursorShape: root.working ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (deviceItem.modelData.connected)
                                                root.disconnectDevice(deviceItem.modelData)
                                            else
                                                root.connectDevice(deviceItem.modelData)
                                        }
                                    }
                                }

                                // ── Forget button ────────────────────────────────
                                Rectangle {
                                    id: forgetBtn
                                    Layout.preferredWidth:  deviceItem.pendingForget
                                            ? forgetConfirmLabel.implicitWidth + 16
                                            : 26
                                    Layout.preferredHeight: 26; radius: 6
                                    Behavior on Layout.preferredWidth  { NumberAnimation  { duration: 120 } }
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
                                                root.forgetDevice(deviceItem.modelData)
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
                                                deviceItem.modelData.address,
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
                    visible: root.pairedList.length === 0 && !root.working
                    text: "No hay dispositivos emparejados"
                    font.pixelSize: 12; color: Theme.muted1; topPadding: 8
                }

                // ── Nearby (discovered) ──────────────────────────────────
                Item { width: parent.width; height: 12
                    visible: root.nearbyList.length > 0 }

                Text {
                    visible: root.nearbyList.length > 0
                    text: "Dispositivos cercanos"
                    font.pixelSize: 11; font.weight: Font.Normal; color: Theme.muted1; bottomPadding: 4
                }

                Repeater {
                    model: root.nearbyList

                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 40; radius: 8; color: Theme.surface2

                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                            spacing: 8

                            Text { text: "󰂯"; font.pixelSize: 15; color: Theme.muted2 }

                            Column {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: modelData.name || modelData.deviceName; font.pixelSize: 12; color: Theme.text
                                    elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.address; font.pixelSize: 9; color: Theme.muted2 }
                            }

                            Rectangle {
                                Layout.preferredWidth: 60; Layout.preferredHeight: 26; radius: 6; color: Theme.surface3
                                Text { anchors.centerIn: parent; text: "Emparejar"
                                    font.pixelSize: 10; color: Theme.text }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pairDevice(modelData) }
                            }
                        }
                    }
                }

                Item { height: 8; width: parent.width }
            }
        }
    }
}

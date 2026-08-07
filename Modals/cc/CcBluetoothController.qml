// Controlador Bluetooth — estado, funciones, timers, Connections, Instantiators, procesos
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "../../Components"

QtObject {
    id: root

    // ── Estado del adaptador ──────────────────────────────────────────────
    property var    _btAdapter:   Bluetooth.defaultAdapter
    property bool   _btAvailable: _btAdapter !== null
    property bool   _btPwrd:      _btAdapter ? _btAdapter.enabled : false
    property bool   _btScanning:  false
    property bool   _btWorking:   false
    property string _btStatusMsg: ""

    property var    _btPairedList:   []
    property var    _btNearbyList:   []
    property int    _btPairedCount:  0
    property int    _btNearbyCount:  0

    property var    _btActionDevice:    null
    property string _btActionType:      ""
    property bool   _btSawConnecting:   false
    property int    _btConnectRetries:  0
    property bool   _btAutoConnRunning: false
    property var    _btAutoConnQueue:   []
    property var    _btAutoConnDevice:  null

    // Codec info map: { "AA:BB:CC:DD:EE:FF" → {codec, active, rate, profiles:[{id,label}]} }
    property var    _btCodecData:        ({})
    property var    _btCodecQueue:       []
    property string _btCurrentCodecMac:  ""

    // ── Propiedades de resumen para CcQuickToggles / CcPanelOverlay ──────
    property var  btAdapter: Bluetooth.defaultAdapter
    property bool btPowered: btAdapter ? btAdapter.enabled : false

    // Bluetooth.devices expone SOLO los dispositivos actualmente conectados
    property int btConnectedCount: Bluetooth.devices.values.length

    readonly property string btFirstConnectedName: {
        const devs = Bluetooth.devices.values
        if (devs.length === 0) return ""
        const d = devs[0]
        return d.name || d.deviceName || d.address || ""
    }

    // ── Mensajes de estado ────────────────────────────────────────────────
    readonly property string _btMsgConnected:    "✓ Conectado"
    readonly property string _btMsgDisconnected: "✓ Desconectado"
    readonly property string _btMsgPaired:       "✓ Emparejado"
    readonly property string _btMsgForgotten:    "✓ Dispositivo olvidado"
    readonly property string _btMsgCodecOk:      "✓ Codec cambiado"
    readonly property string _btMsgNoAdapter:    "✗ Sin adaptador"
    readonly property string _btMsgNoPower:      "✗ Enciende el Bluetooth primero"
    readonly property string _btMsgTimeout:      "✗ Tiempo de espera"
    readonly property string _btMsgConnFailed:   "✗ No se pudo conectar"
    readonly property string _btMsgPairFailed:   "✗ No se pudo emparejar"
    readonly property string _btMsgCodecErr:     "✗ Error al cambiar codec"

    // ── Funciones BT ──────────────────────────────────────────────────────
    function btSanitizeMac(mac) {
        return mac.replace(/[^0-9A-Fa-f:]/g, "")
    }

    function btRunNextCodecQuery() {
        if (root._btCodecQueue.length === 0 || btCodecProc.running) return
        root._btCurrentCodecMac = root._btCodecQueue[0]
        root._btCodecQueue      = root._btCodecQueue.slice(1)
        var safeMac = root.btSanitizeMac(root._btCurrentCodecMac)
        btCodecProc.command = [Paths.scripts + "/bt-codec.sh", "info", safeMac]
        btCodecProc.running = true
    }

    function btSetCodec(mac, profile) {
        root._btStatusMsg = ""
        root._btCurrentCodecMac = mac
        var safeMac     = root.btSanitizeMac(mac)
        var safeProfile = profile.replace(/[^a-zA-Z0-9_-]/g, "")
        btSetCodecProc.command = [Paths.scripts + "/bt-codec.sh", "set", safeMac, safeProfile]
        btSetCodecProc.running = true
    }

    function btResetAction(msg) {
        root._btWorking         = false
        root._btActionDevice    = null
        root._btActionType      = ""
        root._btSawConnecting   = false
        root._btConnectRetries  = 0
        if (msg !== undefined) root._btStatusMsg = msg
        btActionTimeout.stop()
        btConnectRetryTimer.stop()
    }

    function btRefreshDeviceLists() {
        var source  = root._btAdapter ? root._btAdapter.devices.values : []
        var paired  = []
        var nearby  = []
        for (var i = 0; i < source.length; i++) {
            var d = source[i]
            var isPaired = d.bonded || d.paired || d.trusted
            if (isPaired) paired.push(d)
            else nearby.push(d)
        }
        root._btPairedList  = paired
        root._btNearbyList  = nearby
        root._btPairedCount = paired.length
        root._btNearbyCount = nearby.length
    }

    function btAutoConnectTrusted() {
        if (!root._btAvailable || !root._btPwrd) return
        if (root._btAutoConnRunning) return
        btRefreshDeviceLists()
        var source = root._btAdapter ? root._btAdapter.devices.values : []
        var q = []
        for (var i = 0; i < source.length; i++) {
            var d = source[i]
            if (d.paired && d.trusted && d.state !== BluetoothDeviceState.Connecting && !d.connected)
                q.push(d)
        }
        if (q.length === 0) return
        root._btAutoConnQueue   = q
        root._btAutoConnRunning = true
        root._btAutoConnDevice  = null
        btAutoConnNext()
    }

    function btAutoConnNext() {
        if (!root._btAutoConnRunning) return
        btAutoConnTimer.stop()
        root._btAutoConnDevice = null
        if (root._btAutoConnQueue.length === 0) {
            root._btAutoConnRunning = false
            return
        }
        root._btAutoConnDevice = root._btAutoConnQueue.shift()
        if (root._btAutoConnDevice) {
            root._btAutoConnDevice.connect()
            btAutoConnTimer.restart()
        } else {
            btAutoConnNext()
        }
    }

    function btTogglePower() {
        if (!root._btAdapter) return
        root._btAdapter.enabled = !root._btAdapter.enabled
    }

    function btToggleScan() {
        if (!root._btPwrd) return
        if (root._btScanning) {
            root._btScanning = false
            if (root._btAdapter) root._btAdapter.discovering = false
            btScanTimer.stop()
        } else {
            root._btScanning = true
            if (root._btAdapter) root._btAdapter.discovering = true
            btScanTimer.restart()
        }
    }

    function btConnectDevice(device) {
        if (!device) return
        if (!root._btPwrd) { root._btStatusMsg = root._btMsgNoPower; return }
        if (device.state === BluetoothDeviceState.Connecting || device.connected) return
        root._btActionDevice   = device
        root._btActionType     = "connect"
        root._btWorking        = true
        root._btStatusMsg      = ""
        device.connect()
        btActionTimeout.restart()
    }

    function btDisconnectDevice(device) {
        if (!device || !device.connected) return
        root._btActionDevice = device
        root._btActionType   = "disconnect"
        root._btWorking      = true
        root._btStatusMsg    = ""
        device.disconnect()
        btActionTimeout.restart()
    }

    function btPairDevice(device) {
        if (!device) return
        if (!root._btPwrd) { root._btStatusMsg = root._btMsgNoPower; return }
        if (device.pairing || device.paired) return
        root._btActionDevice = device
        root._btActionType   = "pair"
        root._btWorking      = true
        root._btStatusMsg    = ""
        device.pair()
        btActionTimeout.restart()
    }

    function btForgetDevice(device) {
        if (!device) return
        root._btActionDevice = device
        root._btActionType   = "forget"
        root._btWorking      = true
        root._btStatusMsg    = ""
        device.forget()
    }

    // ── Timers BT ─────────────────────────────────────────────────────────
    property var _btScanTimer: Timer {
        id: btScanTimer
        interval: 13000
        onTriggered: {
            if (root._btAdapter) root._btAdapter.discovering = false
            root._btScanning = false
        }
    }

    property var _btActionTimeout: Timer {
        id: btActionTimeout
        interval: 10000
        onTriggered: { if (root._btWorking) root.btResetAction(root._btMsgTimeout) }
    }

    property var _btAutoConnTimer: Timer {
        id: btAutoConnTimer
        interval: 1500
        onTriggered: root.btAutoConnNext()
    }

    property var _btConnectRetryTimer: Timer {
        id: btConnectRetryTimer
        interval: 1500
        onTriggered: {
            if (!root._btActionDevice || root._btActionType !== "connect") return
            root._btConnectRetries++
            root._btSawConnecting = false
            root._btWorking = true
            root._btActionDevice.connect()
            btActionTimeout.restart()
        }
    }

    property var _btRefreshDebounce: Timer {
        id: btRefreshDebounce
        interval: 60
        onTriggered: root.btRefreshDeviceLists()
    }

    property var _btCodecRefreshTimer: Timer {
        id: btCodecRefreshTimer
        interval: 30000; repeat: true
        running: {
            // Se bindea desde ControlCenter — la prop requerida no puede ir en un QtObject
            // así que chequeamos directamente. El timer solo corre cuando hay acceso.
            // La condición real se bindea via ControlCenter.
            false
        }
        onTriggered: {
            if (btCodecProc.running || btSetCodecProc.running) return
            var q = []
            var list = root._btAdapter ? root._btAdapter.devices.values : []
            for (var i = 0; i < list.length; i++) {
                if (list[i].connected) q.push(list[i].address)
            }
            if (q.length > 0) {
                root._btCodecQueue = q
                root.btRunNextCodecQuery()
            }
        }
    }

    // ── Connections: cambios en adaptador ─────────────────────────────────
    property var _btAdapterDevicesConn: Connections {
        target: root._btAdapter ? root._btAdapter.devices : null
        function onObjectInsertedPost(object, index) {
            btRefreshDebounce.restart()
        }
        function onObjectRemovedPost(object, index) {
            btRefreshDebounce.restart()
            if (root._btActionType === "forget" && root._btActionDevice === object)
                root.btResetAction(root._btMsgForgotten)
        }
    }

    // ── Instantiator: observar cambios en cada dispositivo ────────────────
    property var _btDeviceInstantiator: Instantiator {
        model: root._btAdapter ? root._btAdapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged()     { root.btRefreshDeviceLists() }
            function onConnectedChanged()  { root.btRefreshDeviceLists() }
            function onTrustedChanged()    { root.btRefreshDeviceLists() }
            function onNameChanged()       { root.btRefreshDeviceLists() }
            function onDeviceNameChanged() { root.btRefreshDeviceLists() }
            function onStateChanged()      { root.btRefreshDeviceLists() }
        }
    }

    // ── Connections: dispositivo de acción activa ─────────────────────────
    property var _btActionDeviceConn: Connections {
        target: root._btActionDevice
        function onConnectedChanged() {
            if (!root._btActionDevice) return
            if (root._btActionType === "connect" && root._btActionDevice.connected) {
                root._btConnectRetries = 0
                root.btResetAction(root._btMsgConnected)
            } else if (root._btActionType === "disconnect" && !root._btActionDevice.connected) {
                root.btResetAction(root._btMsgDisconnected)
            }
        }
        function onStateChanged() {
            if (!root._btActionDevice || root._btActionType !== "connect") return
            var s = root._btActionDevice.state
            if (s === BluetoothDeviceState.Connecting) {
                root._btSawConnecting = true
            } else if (s === BluetoothDeviceState.Disconnected && root._btSawConnecting) {
                root._btSawConnecting = false
                if (root._btConnectRetries < 2) {
                    btConnectRetryTimer.start()
                } else {
                    root._btConnectRetries = 0
                    root.btResetAction(root._btMsgConnFailed)
                }
            }
        }
        function onPairedChanged() {
            if (!root._btActionDevice) return
            if (root._btActionType === "pair" && root._btActionDevice.paired) {
                root._btActionDevice.trusted = true
                root.btResetAction(root._btMsgPaired)
            }
        }
        function onPairingChanged() {
            if (!root._btActionDevice) return
            if (root._btActionType === "pair" && !root._btActionDevice.pairing && !root._btActionDevice.paired)
                root.btResetAction(root._btMsgPairFailed)
        }
    }

    // ── Connections: dispositivo de auto-connect ──────────────────────────
    property var _btAutoConnDeviceConn: Connections {
        target: root._btAutoConnDevice
        function onConnectedChanged() {
            if (root._btAutoConnDevice && root._btAutoConnDevice.connected) {
                btAutoConnTimer.stop()
                root.btAutoConnNext()
            }
        }
        function onStateChanged() {
            if (root._btAutoConnDevice
                    && root._btAutoConnDevice.state === BluetoothDeviceState.Disconnected) {
                btAutoConnTimer.stop()
                root.btAutoConnNext()
            }
        }
    }

    // ── Handler: cambio de poder ──────────────────────────────────────────
    on_BtPwrdChanged: {
        if (!root._btPwrd) {
            root._btCodecData       = ({})
            root._btCodecQueue      = []
            root._btAutoConnQueue   = []
            root._btAutoConnRunning = false
            root._btAutoConnDevice  = null
            root.btResetAction("")
        } else {
            root.btAutoConnectTrusted()
        }
        root.btRefreshDeviceLists()
    }

    on_BtAdapterChanged: { root.btRefreshDeviceLists() }

    // ── Procesos Bluetooth: codec ─────────────────────────────────────────
    property var _btCodecProc: JsonProcess {
        id: btCodecProc
        command: ["bash", "-c", ""]
        onParsed: data => {
            var mac  = root._btCurrentCodecMac.toUpperCase()
            root._btCodecData[mac] = data
            root._btCodecDataChanged()
        }
        onFinished: root.btRunNextCodecQuery()
    }

    property var _btSetCodecProc: Process {
        id: btSetCodecProc
        command: ["bash", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: function(ec) {
            root._btStatusMsg = ec === 0 ? root._btMsgCodecOk : root._btMsgCodecErr
            Qt.callLater(() => root.btRunNextCodecQuery())
        }
        // qmllint enable signal-handler-parameters
    }
}

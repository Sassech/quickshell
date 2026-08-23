// Controlador WiFi — estado, funciones, procesos, Connections, Instantiator
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Networking
import "../../Components"

QtObject {
    id: root

    // ── Estado del dispositivo WiFi ───────────────────────────────────────
    property var    _nmWifiDev: null

    function _findWifiDev() {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }

    Component.onCompleted: root._nmWifiDev = root._findWifiDev()

    property var _nmDevConnections: Connections {
        target: Networking.devices
        function onValuesChanged() { root._nmWifiDev = root._findWifiDev() }
    }

    property bool   _wifiRadioOn:    Networking.wifiEnabled
    property bool   _wifiScanning:   _nmWifiDev ? _nmWifiDev.scannerEnabled : false
    property bool   _wifiWorking:    false
    property string _wifiStatusMsg:  ""
    property int    _wifiSelectedIdx: -1
    property var    _wifiPasswordByIndex: ({})
    property var    _wifiTargetNet:  null

    // ── Red conectada (reactiva) ──────────────────────────────────────────
    property var    _wifiConnectedNet: {
        var dev = root._nmWifiDev
        if (!dev) return null
        var nets = dev.networks.values
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i]
        }
        return null
    }
    property string _wifiConnectedSsid: _wifiConnectedNet ? _wifiConnectedNet.name : ""

    // ── IP/Gateway/DNS (vía nmcli) ────────────────────────────────────────
    property string _wifiIp:      ""
    property string _wifiGateway: ""
    property string _wifiDns:     ""

    // ── Estado Ethernet (vía nmcli) ───────────────────────────────────────
    property bool   _ethConnected: false
    property string _ethIp:        ""
    property string _ethSpeed:     ""

    // ── Password fetch shared state ───────────────────────────────────────
    property string _wifiPwFetchResult:    ""
    property int    wifiPwFetchResultIdx: -2
    property int    _wifiPwFetchIdx:       -1

    // ── Señal para notificar password fetched al panel overlay ───────────
    signal wifiPasswordFetched(int idx, string pw)

    // ── Funciones WiFi ────────────────────────────────────────────────────
    function _wifiIsNormalDisconnectReason(reason) {
        // qmllint disable unqualified
        return reason === NMConnectionStateReason.None
            || reason === NMConnectionStateReason.UserDisconnected
            || reason === NMConnectionStateReason.DeviceDisconnected
        // qmllint enable unqualified
    }

    function wifiSignalIcon(strength) {
        if (strength >= 0.80) return "󰤨"
        if (strength >= 0.60) return "󰤥"
        if (strength >= 0.40) return "󰤢"
        return "󰤟"
    }

    function wifiSecurityLabel(sec) {
        if (sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe) return "Open"
        if (sec === WifiSecurityType.Wpa3SuiteB192 || sec === WifiSecurityType.Sae) return "WPA3"
        if (sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.Wpa2Eap) return "WPA2"
        if (sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.WpaEap) return "WPA"
        if (sec === WifiSecurityType.StaticWep || sec === WifiSecurityType.DynamicWep) return "WEP"
        return ""
    }

    function wifiIsOpen(sec) {
        return sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe
    }

    function wifiToggleRadio() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function wifiRescan() {
        var dev = root._nmWifiDev
        if (!dev) return
        dev.scannerEnabled = true
        wScanStopTimer.restart()
    }

    function wifiConnectKnown(net) {
        root._wifiWorking   = true
        root._wifiTargetNet = net
        root._wifiStatusMsg = ""
        net.connect()
    }

    function wifiConnectNew(ssid, password) {
        root._wifiWorking   = true
        root._wifiStatusMsg = ""
        wConnectProc.command = [
            "bash", "-c",
            "SSID=$1; PASS=$2; IFACE=$(nmcli dev | grep wifi | grep -v p2p | awk '{print $1}' | head -1); " +
            "nmcli con delete \"$SSID\" 2>/dev/null || true; " +
            "nmcli con add type wifi con-name \"$SSID\" ssid \"$SSID\" " +
            "wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$PASS\" 2>&1 && " +
            "nmcli con up \"$SSID\" ifname \"$IFACE\" 2>&1",
            "--", ssid, password
        ]
        wConnectProc.running = true
    }

    function wifiDisconnect(net) {
        if (!net) return
        root._wifiWorking   = true
        root._wifiStatusMsg = ""
        net.disconnect()
    }

    function wifiForget(net) {
        if (!net) return
        net.forget()
        root._wifiStatusMsg = "✓ Red olvidada"
    }

    function wifiFetchPasswordFor(ssid, idx) {
        root._wifiPwFetchIdx       = idx
        root._wifiPwFetchResult    = ""
        root.wifiPwFetchResultIdx = -2
        wSharedPwFetchProc._buf    = ""
        wSharedPwFetchProc.command = [
            "bash", "-c",
            "nmcli -s -t -f 802-11-wireless-security.psk con show "
            + JSON.stringify(ssid) + " 2>/dev/null | cut -d: -f2-"
        ]
        wSharedPwFetchProc.running = true
    }

    function wifiCopyPassword(ssid) {
        wMenuCopyFetchProc.command = ["bash", "-c",
            "SSID=" + JSON.stringify(ssid) + "; " +
            "PASS=$(nmcli -s -g 802-11-wireless-security.psk connection show \"$SSID\" 2>/dev/null); " +
            "if [ -z \"$PASS\" ]; then " +
            "  CONN_FILE=$(find /etc/NetworkManager/system-connections -name '*' -type f 2>/dev/null | xargs grep -l \"ssid=$SSID\" 2>/dev/null | head -1); " +
            "  if [ -n \"$CONN_FILE\" ]; then " +
            "    PASS=$(grep '^psk=' \"$CONN_FILE\" 2>/dev/null | head -1 | cut -d= -f2-); " +
            "  fi; " +
            "fi; " +
            "if [ -n \"$PASS\" ]; then echo \"PASS:$PASS\"; else echo \"ERROR:No se encontró la contraseña\"; fi"
        ]
        wMenuCopyFetchProc.running = true
    }

    function openPanel() {
        root._wifiStatusMsg       = ""
        root._wifiSelectedIdx     = -1
        root._wifiPasswordByIndex = ({})
        wEthProc.running          = true
        wWifiInfoProc.running     = root._wifiConnectedNet !== null
        if (root._nmWifiDev && root._wifiRadioOn)
            root._nmWifiDev.scannerEnabled = true
    }

    // ── Connections: cambios en Networking ───────────────────────────────
    property var _networkingConn: Connections {
        target: Networking
        function onWifiEnabledChanged() {
            root._wifiWorking = false
            if (Networking.wifiEnabled && root._nmWifiDev)
                root._nmWifiDev.scannerEnabled = true
        }
    }

    // ── Instantiator: observar cambios en cada red WiFi ───────────────────
    property var _wifiNetworkInstantiator: Instantiator {
        model: root._nmWifiDev ? root._nmWifiDev.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (modelData.connected) {
                    root._wifiWorking         = false
                    root._wifiTargetNet       = null
                    root._wifiStatusMsg       = "✓ Conectado"
                    root._wifiSelectedIdx     = -1
                    root._wifiPasswordByIndex = ({})
                    wWifiInfoProc.running     = true
                } else if (root._wifiWorking && root._wifiTargetNet === null) {
                    root._wifiWorking   = false
                    root._wifiStatusMsg = "✓ Desconectado"
                }
            }
            function onStateChanged() {
                if (!modelData.connected
                        && !modelData.stateChanging
                        && modelData === root._wifiTargetNet
                        && !root._wifiIsNormalDisconnectReason(modelData.nmReason)
                        && root._wifiWorking) {
                    root._wifiWorking   = false
                    root._wifiTargetNet = null
                    root._wifiStatusMsg = "✗ Error al conectar"
                }
            }
        }
    }

    // ── Timer: auto-stop scanner después de 15 s ──────────────────────────
    property var _wScanStopTimer: Timer {
        id: wScanStopTimer
        interval: 15000
        onTriggered: {
            if (root._nmWifiDev) root._nmWifiDev.scannerEnabled = false
        }
    }

    // ── Proceso: info Ethernet (nmcli) ────────────────────────────────────
    property var _wEthProc: LineProcess {
        id: wEthProc
        command: ["bash", "-c",
            "ETH_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':ethernet:connected' | cut -d: -f1); "
            + "if [ -n \"$ETH_IFACE\" ]; then "
            + "echo \"connected\"; "
            + "LANG=C nmcli -t -f IP4.ADDRESS dev show \"$ETH_IFACE\" 2>/dev/null | cut -d: -f2 | cut -d/ -f1; "
            + "ethtool \"$ETH_IFACE\" 2>/dev/null | grep \"Speed:\" | awk '{print $2}'; "
            + "else echo \"disconnected\"; fi"]
        onLines: lines => {
            root._ethConnected = String(lines[0] || "").trim() === "connected"
            root._ethIp    = String(lines[1] || "").trim()
            root._ethSpeed = String(lines[2] || "").trim()
        }
    }

    // ── Proceso: conectar red nueva con password (nmcli) ──────────────────
    property var _wConnectProc: Process {
        id: wConnectProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wConnectProc._buf += d + "\n" }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            var output = wConnectProc._buf.trim()
            wConnectProc._buf = ""
            root._wifiWorking = false
            if (exitCode === 0) {
                root._wifiStatusMsg       = "✓ Conectado"
                root._wifiSelectedIdx     = -1
                root._wifiPasswordByIndex = ({})
                wWifiInfoProc.running     = true
            } else {
                var errLines = output.split("\n")
                var errMsg   = errLines.filter(l => l && !l.startsWith("DEBUG:"))[0] || "Error de conexión"
                root._wifiStatusMsg = "✗ " + errMsg.substring(0, 40)
            }
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Proceso: IP/Gateway/DNS para WiFi conectado (nmcli) ──────────────
    property var _wWifiInfoProc: LineProcess {
        id: wWifiInfoProc
        command: ["bash", "-c",
            "IFACE=$(nmcli dev | grep wifi | grep -v p2p | awk '{print $1}' | head -1); "
            + "if [ -n \"$IFACE\" ]; then "
            + "nmcli -g IP4.ADDRESS dev show \"$IFACE\" 2>/dev/null; "
            + "nmcli -g IP4.GATEWAY dev show \"$IFACE\" 2>/dev/null; "
            + "nmcli -g IP4.DNS dev show \"$IFACE\" 2>/dev/null; "
            + "fi"]
        onLines: lines => {
            root._wifiIp      = String(lines[0] || "").split("/")[0].trim()
            root._wifiGateway = String(lines[1] || "").trim()
            root._wifiDns     = String(lines[2] || "").trim()
        }
    }

    // ── Proceso: revelar PSK guardada (nmcli -s) ──────────────────────────
    property var _wSharedPwFetchProc: Process {
        id: wSharedPwFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wSharedPwFetchProc._buf += d }
        // qmllint disable signal-handler-parameters
        onExited: {
            var pw = wSharedPwFetchProc._buf.trim()
            wSharedPwFetchProc._buf = ""
            root.wifiPasswordFetched(root._wifiPwFetchIdx, pw)
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Proceso: copiar password al portapapeles ──────────────────────────
    property var _wMenuCopyFetchProc: Process {
        id: wMenuCopyFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wMenuCopyFetchProc._buf += d }
        // qmllint disable signal-handler-parameters
        onExited: {
            var output = wMenuCopyFetchProc._buf.trim()
            wMenuCopyFetchProc._buf = ""
            var pw = "", errorMsg = ""
            output.split("\n").forEach(function(line) {
                if (line.startsWith("PASS:"))        pw       = line.substring(5)
                else if (line.startsWith("ERROR:"))  errorMsg = line.substring(6)
            })
            if (pw !== "") {
                wMenuCopyExecProc.command = ["bash", "-c", 'printf "%s" "$1" | wl-copy', "--", pw]
                wMenuCopyExecProc.running = true
            } else {
                root._wifiStatusMsg = "✗ " + (errorMsg || "No se encontró la contraseña")
            }
        }
        // qmllint enable signal-handler-parameters
    }

    property var _wMenuCopyExecProc: Process {
        id: wMenuCopyExecProc
        command: ["bash", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: (ec) => {
            root._wifiStatusMsg = ec === 0 ? "✓ Contraseña copiada" : "✗ wl-copy error " + ec
        }
        // qmllint enable signal-handler-parameters
    }
}

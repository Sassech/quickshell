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
    property bool   radioOn:       true
    property bool   scanning:      false
    property string connectedSsid: ""
    property string wifiIface:     ""
    property int    selectedIdx:   -1
    property bool   showPassword:  false
    property string statusMsg:     ""
    property var    passwordByIndex: ({})  // { index: password }
    property bool   working:       false

    // Log status changes
    onStatusMsgChanged: {
        if (statusMsg !== "") {
            console.log("[WifiModal] STATUS:", statusMsg)
        }
    }

    // Ethernet state
    property bool   ethernetConnected: false
    property string ethernetIp:       ""
    property string ethernetMac:      ""
    property string ethernetSpeed:    ""

    // WiFi connection info
    property string wifiIp:      ""
    property string wifiGateway: ""
    property string wifiDns:     ""

    // Parsed network list: [{ssid, signal, security, active}]
    property var networks: []

    // Set of saved connection names (ssid → true)
    property var savedSsids: ({})

    // ── Password fetch — Process único compartido por todas las filas ─────────
    property string _pwFetchSsid: ""
    property int    _pwFetchIdx:  -1

    Process {
        id: sharedPwFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => sharedPwFetchProc._buf += d
        }
        onExited: {
            var pw = sharedPwFetchProc._buf.trim()
            sharedPwFetchProc._buf = ""
            // Señalizar el resultado al delegate activo via propiedades del modal
            root._pwFetchResult = pw
            root._pwFetchResultIdx = root._pwFetchIdx
        }
    }

    // El delegate observa estas dos propiedades para saber si le toca a él
    property string _pwFetchResult:    ""
    property int    _pwFetchResultIdx: -2

    function fetchPasswordFor(ssid, idx) {
        _pwFetchSsid = ssid
        _pwFetchIdx  = idx
        _pwFetchResult = ""
        _pwFetchResultIdx = -2
        sharedPwFetchProc._buf = ""
        sharedPwFetchProc.command = [
            "bash", "-c",
            "nmcli -s -t -f 802-11-wireless-security.psk con show "
            + JSON.stringify(ssid) + " 2>/dev/null | cut -d: -f2-"
        ]
        sharedPwFetchProc.running = true
    }

    // Shared floating dropdown state
    property int    menuOpenIdx:  -1
    property real   menuDropX:    0
    property real   menuDropY:    0
    property string menuOpenSsid: ""

    // Network info panel
    property int infoOpenIdx: -1
    property var infoData:    ({})   // {ssid, signal, security, active, isSaved, ip}

    onSelectedIdxChanged: infoOpenIdx = -1

    onVisibleChanged: {
        if (visible) {
            selectedIdx  = -1
            showPassword = false
            passwordByIndex = ({})
            statusMsg    = ""
            loadNetworks()
            Qt.callLater(function() { wifiCard.forceActiveFocus() })
        } else {
            scanning = false
            root.menuOpenIdx  = -1
            root.infoOpenIdx  = -1
        }
    }

    Component.onDestruction: {
        ifaceProc.running = false
        radioProc.running = false
        netListProc.running = false
        savedProc.running = false
        ethernetProc.running = false
        wifiInfoProc.running = false
        toggleRadioProc.running = false
        rescanProc.running = false
        connectProc.running = false
        disconnectProc.running = false
        savedPwProc.running = false
        menuCopyFetchProc.running = false
        menuCopyExecProc.running = false
        menuForgetProc.running = false
        menuInfoProc.running = false
    }
 
    // ── Data loading ──────────────────────────────────────────────────────
    function loadNetworks() {
        root.working = true
        ifaceProc.running   = true
        radioProc.running   = true
        netListProc.running = true
        savedProc.running   = true
        ethernetProc.running = true
    }

    // ── Auto-refresh every 15 seconds when visible ──────────────────────────
    Timer {
        interval: 15000
        running: root.visible && !root.working
        repeat: true
        onTriggered: root.loadNetworks()
    }

    property string _ifaceBuf: ""
    property string _radioBuf: ""
    property string _netBuf: ""
    property string _savedBuf: ""
    property string _ethBuf: ""

    // Load saved wifi connection names
    Process {
        id: savedProc
        command: ["bash", "-c",
            "LANG=C nmcli -t -f name,type con show 2>/dev/null "
            + "| awk -F: '$2==\"802-11-wireless\"{print $1}'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._savedBuf += d + "\n" }
        onExited: {
            var lines = root._savedBuf.trim().split("\n")
            root._savedBuf = ""
            var map = {}
            for (var i = 0; i < lines.length; i++) {
                var s = lines[i].trim()
                if (s) map[s] = true
            }
            root.savedSsids = map
        }
    }

    Process {
        id: ifaceProc
        command: ["bash", "-c",
            // Line 1: iface, Line 2: connected ssid
            "LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null "
            + "| grep ':wifi:connected' | cut -d: -f1 | head -1; "
            + "LANG=C nmcli -t -f active,ssid dev wifi 2>/dev/null "
            + "| grep '^yes:' | cut -d: -f2- | head -1"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._ifaceBuf += d + "\n" }
        onExited: {
            var parts = root._ifaceBuf.trim().split("\n")
            root._ifaceBuf = ""
            root.wifiIface     = (parts[0] || "").trim()
            root.connectedSsid = (parts[1] || "").trim()
        }
    }

    Process {
        id: radioProc
        command: ["bash", "-c", "LANG=C nmcli radio wifi 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._radioBuf += d }
        onExited: {
            root.radioOn = root._radioBuf.trim() === "enabled"
            root._radioBuf = ""
        }
    }

    // Load ethernet info
    Process {
        id: ethernetProc
        command: ["bash", "-c",
            "ETH_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':ethernet:connected' | cut -d: -f1); "
            + "if [ -n \"$ETH_IFACE\" ]; then "
            + "echo \"connected\"; "
            + "LANG=C nmcli -t -f IP4.ADDRESS dev show \"$ETH_IFACE\" 2>/dev/null | cut -d: -f2 | cut -d/ -f1; "
            + "LANG=C nmcli -t -f DEVICE,HWADDR dev show 2>/dev/null | grep \"^$ETH_IFACE:\" | cut -d: -f2; "
            + "ethtool \"$ETH_IFACE\" 2>/dev/null | grep \"Speed:\" | awk '{print $2}'; "
            + "else echo \"disconnected\"; fi"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._ethBuf += d + "\n" }
        onExited: {
            var lines = root._ethBuf.trim().split("\n")
            root._ethBuf = ""
            var state = (lines[0] || "").trim()
            root.ethernetConnected = state === "connected"
            root.ethernetIp = (lines[1] || "").trim()
            root.ethernetMac = (lines[2] || "").trim()
            root.ethernetSpeed = (lines[3] || "").trim()
        }
    }

    Process {
        id: netListProc
        command: ["bash", "-c",
            "LANG=C nmcli -t -f active,ssid,signal,security dev wifi list 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._netBuf += d + "\n" }
        onExited: {
            var lines  = root._netBuf.trim().split("\n")
            root._netBuf = ""
            var seen   = {}
            var result = []

            // Get WiFi interface MAC
            var wifiMac = ""
            var wifiIface = root.wifiIface
            if (wifiIface) {
                // MAC will be fetched separately
            }

            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (!l) continue
                // format: active:ssid:signal:security
                // SSID may contain ':', so we parse carefully:
                //   - field 0: "yes" or "no" (active)
                //   - field 1: ssid (everything between first and second-to-last ':')
                //   - field N-1: signal (number)
                //   - field N: security (may also contain ':')
                // Strategy: split by ':', take first as active, last as security,
                // second-to-last as signal, and everything in between as ssid.
                var p = l.split(":")
                if (p.length < 3) continue
                var active   = p[0] === "yes"
                var security = p[p.length - 1].trim()
                var sig      = parseInt(p[p.length - 2]) || 0
                // SSID is everything between index 1 and index (length-3)
                var ssid     = p.slice(1, p.length - 2).join(":")
                if (!ssid) continue          // hidden network
                if (seen[ssid]) continue     // deduplicate
                seen[ssid] = true
                if (active) root.connectedSsid = ssid
                result.push({ ssid: ssid, signal: sig, security: security, active: active })
            }
            // Sort: active first, then by signal descending
            result.sort((a, b) => {
                if (a.active !== b.active) return a.active ? -1 : 1
                return b.signal - a.signal
            })
            root.networks = result
            root.working  = false

            // Load WiFi connection info (IP, Gateway, DNS)
            if (root.wifiIface) {
                wifiInfoProc.running = true
            }
        }
    }

    // Get WiFi connection info (IP, Gateway, DNS)
    Process {
        id: wifiInfoProc
        property string _buf: ""
        command: ["bash", "-c",
            "IFACE=$(nmcli dev | grep wifi | grep -v p2p | awk '{print $1}' | head -1); "
            + "if [ -n \"$IFACE\" ]; then "
            + "nmcli -g IP4.ADDRESS dev show \"$IFACE\" 2>/dev/null; "
            + "nmcli -g IP4.GATEWAY dev show \"$IFACE\" 2>/dev/null; "
            + "nmcli -g IP4.DNS dev show \"$IFACE\" 2>/dev/null; "
            + "fi"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wifiInfoProc._buf += d + "\n" }
        onExited: {
            var lines = wifiInfoProc._buf.trim().split("\n")
            wifiInfoProc._buf = ""
            root.wifiIp      = (lines[0] || "").split("/")[0].trim()
            root.wifiGateway = (lines[1] || "").trim()
            root.wifiDns     = (lines[2] || "").trim()
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────
    function signalIcon(s) {
        if (s >= 80) return "󰤨"
        if (s >= 60) return "󰤥"
        if (s >= 40) return "󰤢"
        return "󰤟"
    }

    Process {
        id: toggleRadioProc
        command: ["bash", "-c", ""]
        onExited: Qt.callLater(() => { root.loadNetworks(); root.working = false })
    }
    function toggleRadio() {
        root.working = true
        toggleRadioProc.command = ["bash", "-c",
            "LANG=C nmcli radio wifi " + (root.radioOn ? "off" : "on") + " 2>/dev/null"]
        toggleRadioProc.running = true
    }

    Process {
        id: rescanProc
        command: ["bash", "-c", "LANG=C nmcli dev wifi rescan 2>/dev/null; sleep 1"]
        onExited: { root.scanning = false; root.loadNetworks() }
    }
    function rescan() {
        root.scanning = true
        rescanProc.running = true
    }

    Process {
        id: connectProc
        command: ["bash", "-c", ""]
        property string _buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => connectProc._buf += d + "\n"
        }
        onExited: function(exitCode) {
            var output = connectProc._buf.trim()
            connectProc._buf = ""
            root.working = false
            
            // Show result based on exit code
            if (exitCode === 0) {
                root.statusMsg = "✓ Conectado"
                root.selectedIdx = -1
                root.showPassword = false
                root.passwordByIndex = ({})
            } else {
                var errLines = output.split("\n")
                var errMsg = errLines.filter(l => l && !l.startsWith("DEBUG:"))[0] || "Error de conexión"
                root.statusMsg = "✗ " + errMsg.substring(0, 40)
            }
            Qt.callLater(() => root.loadNetworks())
        }
    }
    function connectTo(ssid, password) {
        root.working   = true
        root.statusMsg = ""

        var cmd = [
            "bash", "-c",
            "SSID=$1; PASS=$2; IFACE=$(nmcli dev | grep wifi | grep -v p2p | awk '{print $1}' | head -1); " +
            "nmcli con delete \"$SSID\" 2>/dev/null || true; " +
            "nmcli con add type wifi con-name \"$SSID\" ssid \"$SSID\" " +
            "wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$PASS\" 2>&1 && " +
            "nmcli con up \"$SSID\" ifname \"$IFACE\" 2>&1",
            "--", ssid, password
        ]
        connectProc.command = cmd
        connectProc.running = true
    }

    Process { id: disconnectProc; command: ["bash", "-c", ""]
        onExited: { root.working = false; Qt.callLater(() => root.loadNetworks()) }
    }

    Process {
        id: savedPwProc
        property string ssid: ""
        property int index: -1
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => savedPwProc._buf += d }
        onExited: function(ec) {
            var pw = savedPwProc._buf.trim()
            savedPwProc._buf = ""
            root.working = false
            if (pw.length > 0) {
                root.connectTo(savedPwProc.ssid, pw)
            } else {
                root.statusMsg = "✗ No se pudo obtener contraseña guardada"
            }
        }
    }

    function disconnect_() {
        if (!root.wifiIface || root.wifiIface === "") {
            root.statusMsg = "✗ No hay interfaz WiFi"
            return
        }
        root.working = true
        disconnectProc.command = ["bash", "-c",
            "LANG=C nmcli dev disconnect " + root.wifiIface + " 2>/dev/null"]
        disconnectProc.running = true
    }

    // ── Menu actions (root-level, shared dropdown lives in wifiCard) ───────
    Process {
        id: menuCopyFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => menuCopyFetchProc._buf += d }
        onExited: {
            var output = menuCopyFetchProc._buf.trim()
            menuCopyFetchProc._buf = ""
            
            // Parse output: "PASS:xxx" or "ERROR:message"
            var pw = ""
            var errorMsg = ""
            
            var lines = output.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line.startsWith("PASS:")) {
                    pw = line.substring(5)
                    break
                } else if (line.startsWith("ERROR:")) {
                    errorMsg = line.substring(6)
                }
            }
            
            if (pw !== "") {
                menuCopyExecProc.command = ["bash", "-c", 'printf "%s" "$1" | wl-copy', "--", pw]
                menuCopyExecProc.running = true
            } else {
                root.statusMsg = "✗ " + (errorMsg || "No se encontró la contraseña")
            }
        }
    }
    Process {
        id: menuCopyExecProc
        property string _err: ""
        command: ["bash", "-c", ""]
        stderr: SplitParser { splitMarker: "\n"; onRead: d => menuCopyExecProc._err += d + "\n" }
        onExited: (ec) => {
            var err = menuCopyExecProc._err.trim()
            menuCopyExecProc._err = ""
            root.statusMsg = ec === 0
                ? "✓ Contraseña copiada"
                : "✗ wl-copy error " + ec + (err ? ": " + err : "")
        }
    }
    function menuCopyPassword() {
        var ssid = root.menuOpenSsid
        root.menuOpenIdx = -1
        // Try multiple methods to get saved password
        menuCopyFetchProc.command = ["bash", "-c",
            "SSID=" + JSON.stringify(ssid) + "; " +
            "PASS=$(nmcli -s -g 802-11-wireless-security.psk connection show \"$SSID\" 2>/dev/null); " +
            "if [ -z \"$PASS\" ]; then " +
            "  CONN_FILE=$(find /etc/NetworkManager/system-connections -name '*' -type f 2>/dev/null | xargs grep -l \"ssid=$SSID\" 2>/dev/null | head -1); " +
            "  if [ -n \"$CONN_FILE\" ]; then " +
            "    PASS=$(grep '^psk=' \"$CONN_FILE\" 2>/dev/null | head -1 | cut -d= -f2-); " +
            "  fi; " +
            "fi; " +
            "if [ -z \"$PASS\" ]; then " +
            "  PASS=$(nmcli -s device wifi show-password 2>/dev/null | grep '^psk:' | cut -d: -f2- | tr -d ' '); " +
            "fi; " +
            "if [ -n \"$PASS\" ]; then echo \"PASS:$PASS\"; else echo \"ERROR:No se encontró la contraseña\"; fi"
        ]
        menuCopyFetchProc.running = true
    }
    Process {
        id: menuForgetProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            root.statusMsg = ec === 0 ? "✓ Red olvidada" : "✗ No se pudo olvidar"
            Qt.callLater(() => root.loadNetworks())
        }
    }
    function menuForgetNetwork() {
        var ssid = root.menuOpenSsid
        root.menuOpenIdx = -1
        menuForgetProc.command = ["bash", "-c",
            "nmcli con delete " + JSON.stringify(ssid) + " 2>/dev/null"]
        menuForgetProc.running = true
    }

    Process {
        id: menuInfoProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => menuInfoProc._buf += d + "\n" }
        onExited: {
            var raw = menuInfoProc._buf.trim()
            menuInfoProc._buf = ""
            var d = Object.assign({}, root.infoData)
            raw.split("\n").forEach(function(line) {
                var kv = line.split(":")
                var key = kv[0].trim().toLowerCase()
                var val = kv.slice(1).join(":").trim()
                if (key === "ip4.address[1]") d.ip = val.split("/")[0]
            })
            root.infoData = d
        }
    }
    function menuShowInfo(idx, net) {
        root.menuOpenIdx = -1
        if (root.infoOpenIdx === idx) {
            root.infoOpenIdx = -1
            return
        }
        root.infoData = {
            ssid:     net.ssid,
            signal:   net.signal,
            security: net.security,
            active:   root.connectedSsid === net.ssid,
            isSaved:  root.savedSsids[net.ssid] || false,
            ip: ""
        }
        root.infoOpenIdx = idx
        if (root.connectedSsid === net.ssid && root.wifiIface !== "") {
            menuInfoProc.command = ["bash", "-c",
                "LANG=C nmcli -t -f IP4.ADDRESS dev show "
                + root.wifiIface + " 2>/dev/null"]
            menuInfoProc.running = true
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
        id: wifiCard
        focus: true
        anchors.centerIn:         parent
        width:                    400
        height:                   Math.min(560, cardCol.implicitHeight + 32)
        radius:                   14
        color:                    Theme.base

        Keys.onEscapePressed: root.visible = false

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
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
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: root.radioOn ? "󰤨" : "󰤮"
                        font.pixelSize: 20; color: root.radioOn ? Theme.accent : Theme.muted2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "WiFi"
                            font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            text: root.connectedSsid ? root.connectedSsid : (root.radioOn ? "Desconectado" : "Radio apagada")
                            font.pixelSize: 11; color: Theme.muted1
                        }
                    }
                }

                // Right controls
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    // Rescan button
                    Rectangle {
                        visible: root.radioOn
                        width: 28; height: 28; radius: 8
                        color: rescanMA.containsMouse ? Theme.surface3 : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 14
                            color: root.scanning ? Theme.accent : Theme.muted1
                            RotationAnimation on rotation {
                                running:  root.scanning
                                loops:    Animation.Infinite
                                from:     0; to: 360; duration: 1200
                            }
                        }
                        MouseArea { id: rescanMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.rescan() }
                    }

                    // Toggle radio
                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: root.radioOn ? Theme.accent : Theme.surface3
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.radioOn ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleRadio() }
                    }


                }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // ── Ethernet section ─────────────────────────────────────────────
            Item {
                visible: root.ethernetConnected
                width: parent.width
                height: ethernetConnected ? 64 : 0
                Behavior on height { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 8
                    radius: 10
                    color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.12)
                    border.color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.3)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "󰈀"
                            font.pixelSize: 20
                            color: Theme.success
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "Ethernet"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                text: root.ethernetIp || "Sin IP"
                                font.pixelSize: 10
                                color: Theme.muted1
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.ethernetSpeed !== ""

                            Text {
                                text: root.ethernetSpeed
                                font.pixelSize: 10
                                color: Theme.muted1
                                anchors.right: parent.right
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: root.ethernetMac || ""
                                font.pixelSize: 9
                                color: Theme.muted2
                                font.family: "monospace"
                                anchors.right: parent.right
                            }
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                visible: root.ethernetConnected
                width: parent.width; height: 1; color: Theme.surface2
            }

            // Status message
            Text {
                visible: root.statusMsg !== ""
                text: root.statusMsg
                font.pixelSize: 11
                color: root.statusMsg.startsWith("✓") ? Theme.success : Theme.error
                topPadding: 8; bottomPadding: 2
            }

            // Working indicator
            Text {
                visible: root.working
                text: "Cargando..."
                font.pixelSize: 11; color: Theme.muted1
                topPadding: 8; bottomPadding: 2
            }

            // No radio message
            Item {
                visible: !root.radioOn && !root.working
                width: parent.width; height: 80
                Text {
                    anchors.centerIn: parent
                    text: "WiFi está apagado"
                    font.pixelSize: 13; color: Theme.muted1
                }
            }

            // ── Network list ──────────────────────────────────────────────
            ScrollView {
                id: netScroll
                visible: root.radioOn
                width: parent.width
                height: Math.min(networkListCol.implicitHeight, 280)
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                Column {
                    id: networkListCol
                    width: netScroll.width - 12
                    spacing: 4
                    topPadding: 8
                    bottomPadding: 8

                Repeater {
                    model: root.networks

                    Column {
                        id: netRow
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: 0

                        // Per-row password state
                        property bool   isSaved:    root.savedSsids[modelData.ssid] || false
                        property bool   isActive:   root.connectedSsid === modelData.ssid
                        property bool   showPwText:     false
                        property string realPassword: ""
                        property bool   fetchingPw:     false

                        onIsSavedChanged: { showPwText = false; realPassword = "" }

                        function fetchSavedPassword() {
                            if (realPassword !== "" || fetchingPw) {
                                showPwText = !showPwText
                                return
                            }
                            fetchingPw = true
                            root.fetchPasswordFor(modelData.ssid, index)
                        }

                        // Observa el resultado del Process compartido
                        Connections {
                            target: root
                            function onPwFetchResultIdxChanged() {
                                if (root._pwFetchResultIdx !== index) return
                                var pw = root._pwFetchResult
                                netRow.realPassword = pw
                                netRow.fetchingPw   = false
                                if (pw !== "") netRow.showPwText = true
                            }
                        }

                        // Network row
                        Rectangle {
                            width: parent.width; height: 40; radius: 8
                            color: {
                                if (netRow.isActive)
                                    return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                if (root.selectedIdx === index)
                                    return Theme.surface3
                                return rowMA.containsMouse ? Theme.surface3 : Theme.surface2
                            }
                            Behavior on color { ColorAnimation { duration: 100 } }

                            // Active accent strip
                            Rectangle {
                                visible: netRow.isActive
                                width: 3; height: 20; radius: 2
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                color: Theme.accent
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                                spacing: 8

                                // Signal icon
                                Text {
                                    text: root.signalIcon(modelData.signal)
                                    font.pixelSize: 14
                                    color: netRow.isActive ? Theme.accent : Theme.muted2
                                }

                                // SSID
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.ssid
                                    font.pixelSize: 12
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }

                                // Security icon
                                Text {
                                    visible: modelData.security && modelData.security !== "--"
                                    text: "󰌆"; font.pixelSize: 11; color: Theme.muted2
                                }

                                // Signal % text
                                Text {
                                    text: modelData.signal + "%"
                                    font.pixelSize: 10; color: Theme.muted2; width: 30
                                    horizontalAlignment: Text.AlignRight
                                }

                                // Connect / Disconnect button
                                Rectangle {
                                    width: {
                                        if (netRow.isActive) return 88
                                        if (root.selectedIdx === index) return 76
                                        return 76
                                    }
                                    height: 24; radius: 6
                                    color: {
                                        if (netRow.isActive)
                                            return Theme.error
                                        return root.selectedIdx === index ? Theme.accent : Theme.surface3
                                    }
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (netRow.isActive) return "Desconectar"
                                            return "Conectar"
                                        }
                                        font.pixelSize: 10
                                        color: "white"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (netRow.isActive) {
                                                root.disconnect_()
                                            } else {
                                                var needsPw = modelData.security && modelData.security !== "--"
                                                if (root.selectedIdx !== index) {
                                                    root.selectedIdx  = index
                                                    root.showPassword = needsPw && !netRow.isSaved
                                                    root.passwordByIndex[index] = ""
                                                    showPwText = false
                                                } else {
                                                    var pw = pwInput ? pwInput.text : (root.passwordByIndex[index] || "")
                                                    if (needsPw && pw === "") {
                                                        if (netRow.isSaved) {
                                                            root.working = true
                                                            savedPwProc.ssid = modelData.ssid
                                                            savedPwProc.index = index
                                                            savedPwProc.command = ["bash", "-c",
                                                                "nmcli -s -g 802-11-wireless-security.psk connection show " + JSON.stringify(modelData.ssid) + " 2>/dev/null"]
                                                            savedPwProc.running = true
                                                        } else {
                                                            root.statusMsg = "✗ Ingresa una contraseña"
                                                        }
                                                    } else {
                                                        root.connectTo(modelData.ssid, pw)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }


                            }

                            MouseArea {
                                id: rowMA
                                anchors.fill: parent; hoverEnabled: true
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.menuOpenIdx = -1
                                    if (root.selectedIdx === index) {
                                        root.selectedIdx  = -1
                                        root.showPassword = false
                                        showPwText = false
                                    } else {
                                        root.selectedIdx  = index
                                        root.showPassword = modelData.security && modelData.security !== "--"
                                        root.passwordText = ""
                                        showPwText = false
                                        if (netRow.isActive && root.wifiIface !== "") {
                                            root.infoData = {
                                                ssid: modelData.ssid, signal: modelData.signal,
                                                security: modelData.security, active: true,
                                                isSaved: netRow.isSaved, ip: ""
                                            }
                                            menuInfoProc.command = ["bash", "-c",
                                                "LANG=C nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS dev show "
                                                + root.wifiIface + " 2>/dev/null"]
                                            menuInfoProc.running = true
                                        }
                                    }
                                }
                            }

                        }

                        // Unified expanded panel
                        Rectangle {
                            visible: root.selectedIdx === index
                            width: parent.width
                            height: visible ? expandInnerCol.implicitHeight + 24 : 0
                            radius: 8
                            color: Theme.surface2
                            clip: true
                            Behavior on height { NumberAnimation { duration: 150 } }

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius; color: "transparent"
                                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                                border.width: 1
                            }

                            Column {
                                id: expandInnerCol
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                                spacing: 8

                                // ── Contraseña ───────────────────────────────────────────────
                                RowLayout {
                                    visible: (modelData.security && modelData.security !== "--") && !netRow.isActive
                                    width: parent.width
                                    spacing: 6

                                    Text { text: "󰌋"; font.pixelSize: 13; color: Theme.muted1; Layout.alignment: Qt.AlignVCenter }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 24

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: netRow.isSaved && !netRow.showPwText
                                            text: "••••••••"
                                            font.pixelSize: 13; color: Theme.muted1
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: netRow.isSaved && netRow.showPwText
                                            text: netRow.realPassword !== "" ? netRow.realPassword : "—"
                                            font.pixelSize: 12; color: Theme.text; font.family: "monospace"
                                        }
                                        TextInput {
                                            id: pwInput
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                            visible: !netRow.isSaved
                                            text: root.passwordByIndex[index] || ""
                                            onTextChanged: root.passwordByIndex[index] = text
                                            echoMode: netRow.showPwText ? TextInput.Normal : TextInput.Password
                                            color: Theme.text; font.pixelSize: 12
                                            verticalAlignment: TextInput.AlignVCenter
                                            Keys.onReturnPressed: {
                                                var needsPw = modelData.security && modelData.security !== "--"
                                                var pw = root.passwordByIndex[index] || ""
                                                if (needsPw && !netRow.isSaved && pw === "") {
                                                    root.statusMsg = "✗ Ingresa una contraseña"
                                                } else {
                                                    root.connectTo(modelData.ssid, pw)
                                                }
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !netRow.isSaved && pwInput.text.length === 0
                                            text: "Contraseña"; font.pixelSize: 12; color: Theme.muted2
                                        }
                                    }

                                    // Ojo
                                    Rectangle {
                                        width: 26; height: 26; radius: 6
                                        color: eyeMA.containsMouse ? Theme.surface3 : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: netRow.showPwText ? "󰈊" : "󰈉"; font.pixelSize: 14; color: netRow.showPwText ? Theme.accent : Theme.muted2 }
                                        MouseArea {
                                            id: eyeMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: netRow.fetchSavedPassword()
                                        }
                                    }

                                    // Copiar contraseña (solo guardadas)
                                    Rectangle {
                                        visible: netRow.isSaved
                                        width: 26; height: 26; radius: 6
                                        color: copyPwMA.containsMouse ? Theme.surface3 : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: "󰂏"; font.pixelSize: 13; color: Theme.muted1 }
                                        MouseArea {
                                            id: copyPwMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.menuOpenSsid = modelData.ssid; root.menuCopyPassword() }
                                        }
                                    }
                                }

                                // Separador
                                Rectangle {
                                    visible: (modelData.security && modelData.security !== "--") && !netRow.isActive
                                    width: parent.width; height: 1; color: Theme.surface3
                                }

                                // ── Info ──────────────────────────────────────────────────────
                                Column {
                                    width: parent.width; spacing: 4

                                    Row {
                                        width: parent.width; spacing: 6
                                        Text { text: "Señal:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: modelData.signal + "%"; font.pixelSize: 11; color: Theme.text }
                                    }
                                    Row {
                                        width: parent.width; spacing: 6
                                        Text { text: "Seguridad:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: (modelData.security && modelData.security !== "--") ? modelData.security : "Abierta"; font.pixelSize: 11; color: Theme.text }
                                    }
                                    Row {
                                        width: parent.width; spacing: 6
                                        Text { text: "Estado:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: netRow.isActive ? "Conectada" : (netRow.isSaved ? "Guardada" : "No guardada"); font.pixelSize: 11; color: Theme.text }
                                    }
                                    Row {
                                        visible: netRow.isActive
                                        width: parent.width; spacing: 6
                                        Text { text: "IP:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: root.wifiIp !== "" ? root.wifiIp : "—"; font.pixelSize: 11; color: Theme.text; elide: Text.ElideRight; width: parent.width - 96 }
                                    }
                                    Row {
                                        visible: netRow.isActive
                                        width: parent.width; spacing: 6
                                        Text { text: "Gateway:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: root.wifiGateway !== "" ? root.wifiGateway : "—"; font.pixelSize: 11; color: Theme.text }
                                    }
                                    Row {
                                        visible: netRow.isActive
                                        width: parent.width; spacing: 6
                                        Text { text: "DNS:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: root.wifiDns !== "" ? root.wifiDns : "—"; font.pixelSize: 11; color: Theme.text }
                                    }
                                }

                                // ── Acciones ──────────────────────────────────────────────────
                                Row {
                                    visible: netRow.isSaved
                                    width: parent.width; spacing: 6

                                    Rectangle {
                                        width: forgetBtnText.implicitWidth + 20; height: 26; radius: 6
                                        color: forgetBtnMA.containsMouse
                                            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                            : Theme.surface3
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { id: forgetBtnText; anchors.centerIn: parent; text: "󱑃  Olvidar red"; font.pixelSize: 11; color: Theme.error }
                                        MouseArea {
                                            id: forgetBtnMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.menuOpenSsid = modelData.ssid; root.menuForgetNetwork() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }
}

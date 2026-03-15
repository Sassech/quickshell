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
    property string passwordText:  ""
    property string statusMsg:     ""
    property bool   working:       false

    // Parsed network list: [{ssid, signal, security, active}]
    property var networks: []

    // Set of saved connection names (ssid → true)
    property var savedSsids: ({})

    // Shared floating dropdown state
    property int    menuOpenIdx:  -1
    property real   menuDropX:    0
    property real   menuDropY:    0
    property string menuOpenSsid: ""

    // Network info panel
    property int infoOpenIdx: -1
    property var infoData:    ({})   // {ssid, signal, security, active, isSaved, ip, gateway, dns}

    onSelectedIdxChanged: infoOpenIdx = -1

    onVisibleChanged: {
        if (visible) {
            selectedIdx  = -1
            showPassword = false
            passwordText = ""
            statusMsg    = ""
            loadNetworks()
        } else {
            scanning = false
            root.menuOpenIdx  = -1
            root.infoOpenIdx  = -1
        }
    }

    // ── Data loading ──────────────────────────────────────────────────────
    function loadNetworks() {
        root.working = true
        ifaceProc.running   = true
        radioProc.running   = true
        netListProc.running = true
        savedProc.running   = true
    }

    property string _ifaceBuf: ""
    property string _radioBuf: ""
    property string _netBuf: ""
    property string _savedBuf: ""

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
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (!l) continue
                // format: active:ssid:signal:security
                // active may be "yes" (LANG=C ensured)
                var p = l.split(":")
                if (p.length < 3) continue
                var active   = p[0] === "yes"
                var ssid     = p[1]
                var sig      = parseInt(p[2]) || 0
                var security = p.slice(3).join(":").trim()
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

    Process { id: connectProc; command: ["bash", "-c", ""]
        onExited: (ec) => {
            root.working = false
            if (ec === 0) {
                root.statusMsg   = "✓ Conectado"
                root.selectedIdx = -1
                root.showPassword = false
                root.passwordText = ""
            } else {
                root.statusMsg = "✗ No se pudo conectar"
            }
            Qt.callLater(() => root.loadNetworks())
        }
    }
    function connectTo(ssid, password) {
        root.working   = true
        root.statusMsg = ""
        var cmd = "LANG=C nmcli dev wifi connect " + JSON.stringify(ssid)
        if (password) cmd += " password " + JSON.stringify(password)
        cmd += " 2>&1"
        connectProc.command = ["bash", "-c", cmd]
        connectProc.running = true
    }

    Process { id: disconnectProc; command: ["bash", "-c", ""]
        onExited: { root.working = false; Qt.callLater(() => root.loadNetworks()) }
    }
    function disconnect_() {
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
            var pw = menuCopyFetchProc._buf.trim()
            menuCopyFetchProc._buf = ""
            if (pw !== "") {
                // Pass password as positional $1 to avoid any shell quoting issues.
                // printf "%s" does NOT add a trailing newline; stdin mode is more
                // reliable with clipboard managers than argument mode.
                menuCopyExecProc.command = ["bash", "-c", 'printf "%s" "$1" | wl-copy', "--", pw]
                menuCopyExecProc.running = true
            } else {
                root.statusMsg = "✗ No se encontró la contraseña"
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
        menuCopyFetchProc.command = ["bash", "-c",
            "nmcli -s -t -f 802-11-wireless-security.psk con show "
            + JSON.stringify(ssid) + " 2>/dev/null | cut -d: -f2-"]
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
                if (key === "ip4.address[1]") d.ip      = val.split("/")[0]
                if (key === "ip4.gateway")    d.gateway = val
                if (key === "ip4.dns[1]")     d.dns     = val
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
            ip: "", gateway: "", dns: ""
        }
        root.infoOpenIdx = idx
        if (root.connectedSsid === net.ssid && root.wifiIface !== "") {
            menuInfoProc.command = ["bash", "-c",
                "LANG=C nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS dev show "
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
        anchors.centerIn:         parent
        width:                    400
        height:                   Math.min(560, cardCol.implicitHeight + 32)
        radius:                   14
        color:                    Theme.base

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
                            pwFetchProc.running = true
                        }

                        Process {
                            id: pwFetchProc
                            property string _buf: ""
                            command: ["bash", "-c",
                                "nmcli -s -t -f 802-11-wireless-security.psk con show "
                                + JSON.stringify(modelData.ssid) + " 2>/dev/null | cut -d: -f2-"]
                            stdout: SplitParser { splitMarker: "\n"
                                onRead: d => pwFetchProc._buf += d }
                            onExited: {
                                var pw = _buf.trim()
                                _buf = ""
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
                                                var secured = modelData.security && modelData.security !== "--"
                                                if (root.selectedIdx !== index) {
                                                    root.selectedIdx  = index
                                                    root.showPassword = secured
                                                    root.passwordText = ""
                                                    showPwText = false
                                                } else {
                                                    var needsPw = modelData.security && modelData.security !== "--"
                                                    if (needsPw && !netRow.isSaved && root.passwordText === "") {
                                                        root.statusMsg = "✗ Ingresa una contraseña"
                                                    } else {
                                                        root.connectTo(modelData.ssid, root.passwordText)
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
                                                isSaved: netRow.isSaved, ip: "", gateway: "", dns: ""
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
                                            text: root.passwordText
                                            onTextChanged: root.passwordText = text
                                            echoMode: netRow.showPwText ? TextInput.Normal : TextInput.Password
                                            color: Theme.text; font.pixelSize: 12
                                            verticalAlignment: TextInput.AlignVCenter
                                            Keys.onReturnPressed: {
                                                var needsPw = modelData.security && modelData.security !== "--"
                                                if (needsPw && !netRow.isSaved && root.passwordText === "") {
                                                    root.statusMsg = "✗ Ingresa una contraseña"
                                                } else {
                                                    root.connectTo(modelData.ssid, root.passwordText)
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
                                        visible: netRow.isActive && root.infoData.ssid === modelData.ssid && (root.infoData.ip || "") !== ""
                                        width: parent.width; spacing: 6
                                        Text { text: "IP:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: root.infoData.ip || ""; font.pixelSize: 11; color: Theme.text; elide: Text.ElideRight; width: parent.width - 96 }
                                    }
                                    Row {
                                        visible: netRow.isActive && root.infoData.ssid === modelData.ssid && (root.infoData.gateway || "") !== ""
                                        width: parent.width; spacing: 6
                                        Text { text: "Puerta enlace:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: root.infoData.gateway || ""; font.pixelSize: 11; color: Theme.text }
                                    }
                                    Row {
                                        visible: netRow.isActive && root.infoData.ssid === modelData.ssid && (root.infoData.dns || "") !== ""
                                        width: parent.width; spacing: 6
                                        Text { text: "DNS:"; font.pixelSize: 11; color: Theme.muted1; width: 90 }
                                        Text { text: root.infoData.dns || ""; font.pixelSize: 11; color: Theme.text }
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

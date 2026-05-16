import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
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

    // ── Señales hacia el orquestador (shell.qml) ──────────────────────────
    signal requestOpenAudio(var screen)

    // ── Power confirm state ───────────────────────────────────────────────
    property bool   _showConfirm:  false
    property string _confirmLabel: ""
    property var    _confirmCmd:   []

    // ── Bluetooth rev ─────────────────────────────────────────────────────
    property int  _btRev: 0

    // ── Paneles expandibles en toggles ───────────────────────────────────
    property string _expandedToggle: ""   // "wifi" | "power" | "battery" | "language" | ""

    // ── WiFi inline state ─────────────────────────────────────────────────
    property bool   _wifiRadioOn:       true
    property bool   _wifiScanning:      false
    property string _wifiConnectedSsid: ""
    property string _wifiIface:         ""
    property bool   _wifiWorking:       false
    property string _wifiStatusMsg:     ""
    property var    _wifiNetworks:      []
    property var    _wifiSavedSsids:    ({})
    property int    _wifiSelectedIdx:   -1
    property var    _wifiPasswordByIndex: ({})

    // WiFi connection info
    property string _wifiIp:      ""
    property string _wifiGateway: ""
    property string _wifiDns:     ""

    // Ethernet state
    property bool   _ethConnected: false
    property string _ethIp:        ""
    property string _ethMac:       ""
    property string _ethSpeed:     ""

    // Password fetch shared state
    property string _wifiPwFetchSsid:      ""
    property int    _wifiPwFetchIdx:       -1
    property string _wifiPwFetchResult:    ""
    property int    _wifiPwFetchResultIdx: -2

    // Menu copy/forget shared state
    property string _wifiMenuSsid: ""

    // Buffers
    property string _wIfaceBuf:  ""
    property string _wRadioBuf:  ""
    property string _wNetBuf:    ""
    property string _wSavedBuf:  ""
    property string _wEthBuf:    ""

    // ── Bluetooth inline state ────────────────────────────────────────────
    property var    _btAdapter:   Bluetooth.defaultAdapter
    property bool   _btAvailable: _btAdapter !== null
    property bool   _btPwrd:      _btAdapter ? _btAdapter.enabled : false
    property bool   _btScanning:  false
    property bool   _btWorking:   false
    property string _btStatusMsg: ""

    property var    _btDevices:      []
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
    property string _btCodecBuf:         ""

    // Fan profiles (read from fan-control.sh)
    property var    _fanProfiles:  []     // [{id, label}] from fan-control.sh list
    property string _fanBuf:       ""

    // Battery detail
    property int    _batHealth:    0
    property real   _batCapWh:     0
    property int    _batCycles:    0
    property string _batEpp:       ""
    property string _batBuf:       ""

    // Language detail
    property string _langLayout:   "—"
    property string _langLocale:   "—"
    property var    _langLayouts:  []   // [{label, code}]
    property string _langBuf:      ""
    property string _langSetBuf:   ""
    property var    _langLocales:  []
    property string _langLocaleBuf:""
    property string _langSearch:   ""
    property string _langTab:      "keyboard"

    property var _filteredLayouts: {
        root._langLayouts; root._langSearch
        var q = (root._langSearch || "").toLowerCase()
        if (!q) return root._langLayouts
        var result = []
        for (var i = 0; i < root._langLayouts.length; i++) {
            var item = root._langLayouts[i]
            if ((item.code || "").toLowerCase().indexOf(q) >= 0)
                result.push(item)
        }
        return result
    }

    property var _filteredLocales: {
        root._langLocales; root._langSearch
        var q = (root._langSearch || "").toLowerCase()
        if (!q) return root._langLocales
        var result = []
        for (var i = 0; i < root._langLocales.length; i++) {
            var item = root._langLocales[i]
            if ((item.value || "").toLowerCase().indexOf(q) >= 0)
                result.push(item)
        }
        return result
    }

    // ── Métricas expandibles — estado ─────────────────────────────────────
    property string _expandedMetric: ""   // "cpu" | "ram" | "gpu" | ""

    // CPU detail
    property bool   _cpuLoaded:    false
    property string _cpuModel:     ""
    property int    _cpuPkgTemp:   0
    property int    _cpuAvgFreq:   0
    property string _cpuGov:       ""
    property string _cpuEpp:       ""
    property var    _cpuCorePcts:  []
    property string _cpuBuf:       ""

    // GPU detail — list of GPU objects parsed from gpu-detail.sh
    // Each: { vendor, name, util, temp, tempJun, freq, power, vramUsed, vramTotal, driver, status }
    property bool   _gpuLoaded: false
    property var    _gpus:      []        // populated by gpuDetailProc
    property string _gpuBuf:    ""

    // Disk
    property int    _diskPct:      SysData.diskPercent
    property int    _diskUsed:     SysData.diskUsedGb
    property int    _diskTotal:    SysData.diskUsedGb + SysData.diskAvailGb
    property int    _homePct:      0
    property int    _homeUsed:     0
    property int    _homeTotal:    0
    property string _diskBuf:      ""

    // ── Audio — sink/source default ───────────────────────────────────────
    property var defaultSink:   Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [root.defaultSink, root.defaultSource] }

    property real masterVolume: 0.75
    property bool masterMuted:  false
    property real micVolume:    0.75
    property bool micMuted:     false

    // ── Brillo ────────────────────────────────────────────────────────────
    property int brightness: 50
    property bool _brightnessReady: false

    // ── Apps de audio (sink-inputs de Pipewire) ───────────────────────────
    property bool appsExpanded: false
    property int  _pwRev: 0

    // Tracker para todos los stream nodes
    Instantiator {
        model: Pipewire.nodes
        delegate: Connections {
            required property var modelData
            target: modelData.audio
            function onVolumesChanged() { root._pwRev++ }
            function onMutedChanged()   { root._pwRev++ }
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged()   { root._pwRev++; root._syncSink() }
        function onDefaultAudioSourceChanged() { root._pwRev++; root._syncSource() }
    }

    Connections {
        target: root.defaultSink?.audio ?? null
        function onVolumesChanged() {
            const v = root.defaultSink?.audio?.volume
            if (v !== undefined && !isNaN(v)) root.masterVolume = v
        }
        function onMutedChanged() {
            const m = root.defaultSink?.audio?.muted
            if (m !== undefined) root.masterMuted = m
        }
    }

    Connections {
        target: root.defaultSource?.audio ?? null
        function onVolumesChanged() {
            const v = root.defaultSource?.audio?.volume
            if (v !== undefined && !isNaN(v)) root.micVolume = v
        }
        function onMutedChanged() {
            const m = root.defaultSource?.audio?.muted
            if (m !== undefined) root.micMuted = m
        }
    }

    // ── Streams activos (aplicaciones) ────────────────────────────────────
    property var audioStreams: {
        _pwRev
        var all = Pipewire.nodes.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            var node = all[i]
            if (!node || !node.isSink || !node.isStream) continue
            var name = node.name || ""
            var desc = node.description || name
            if (desc === "" || desc === "(null)") desc = name
            out.push({ name: name, label: desc, node: node })
        }
        return out
    }

    // ── Perfil de energía — dinámico via powerprofilesctl ────────────────
    property string powerProfile:  ""          // id del perfil activo
    property var    powerProfiles: []          // [{id, label}] leídos del sistema
    property string _powerBuf:     ""

    // ── Bluetooth resumen ─────────────────────────────────────────────────
    property var  btAdapter: Bluetooth.defaultAdapter
    property bool btPowered: btAdapter ? btAdapter.enabled : false

    // Lista de dispositivos: conectados primero, luego emparejados
    property var btDeviceList: {
        _btRev
        var devs = btAdapter ? btAdapter.devices.values : []
        var conn = [], paired = []
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (!d) continue
            var isPaired = d.bonded || d.paired || d.trusted
            var isConn   = d.connected
            var entry = {
                name:      d.name || d.deviceName || d.address || "Device",
                address:   d.address || "",
                connected: isConn,
                paired:    isPaired,
                icon:      _btDeviceIcon(d)
            }
            if (isConn)        conn.push(entry)
            else if (isPaired) paired.push(entry)
        }
        return conn.concat(paired)
    }

    property int btConnectedCount: {
        var n = 0
        for (var i = 0; i < btDeviceList.length; i++) {
            if (btDeviceList[i].connected) n++
        }
        return n
    }

    function _btDeviceIcon(d) {
        var name = (d.name || d.deviceName || "").toLowerCase()
        if (name.includes("headphone") || name.includes("headset") || name.includes("earphone") || name.includes("airpod")) return "󰋋"
        if (name.includes("speaker")) return "󰓃"
        if (name.includes("keyboard")) return "󰌌"
        if (name.includes("mouse"))    return "󰍽"
        if (name.includes("phone") || name.includes("iphone") || name.includes("android")) return "󰄜"
        if (name.includes("watch"))    return "󰢗"
        if (name.includes("pad") || name.includes("tablet")) return "󰓶"
        return "󰂱"
    }

    Connections {
        target: btAdapter ? btAdapter.devices : null
        function onObjectInsertedPost(object, index) { root._btRev++ }
        function onObjectRemovedPost(object, index)  { root._btRev++ }
    }

    Instantiator {
        model: btAdapter ? btAdapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { root._btRev++ }
            function onNameChanged()      { root._btRev++ }
        }
    }

    // ── MPRIS — reproductor ───────────────────────────────────────────────
    property var mprisPlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property real playerPos: 0
    property int  _posSync: 0

    function _syncPlayerPos() {
        if (root.mprisPlayer && root.mprisPlayer.position !== undefined)
            root.playerPos = root.mprisPlayer.position
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.mprisPlayer?.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            root.playerPos += 1000
            root._posSync++
            if (root._posSync >= 10) { root._posSync = 0; root._syncPlayerPos() }
        }
    }

    Connections {
        target: root.mprisPlayer ?? null
        function onTrackTitleChanged() { root._syncPlayerPos(); root._posSync = 0 }
    }

    // ── Procesos auxiliares ───────────────────────────────────────────────
    property string _buf: ""

    // Leer brillo actual
    Process {
        id: getBrightnessProc
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._buf += d }
        onExited: {
            var v = parseInt(root._buf.trim())
            root._buf = ""
            if (!isNaN(v)) { root.brightness = v; root._brightnessReady = true }
        }
    }

    // Leer volumen master via wpctl
    Process {
        id: getVolProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._buf += d + "\n" }
        onExited: {
            var lines = root._buf.trim().split("\n")
            root._buf = ""
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
                if (!m) continue
                var v = parseFloat(m[1])
                if (isNaN(v)) continue
                if (i === 0) { root.masterVolume = v; root.masterMuted = !!m[2] }
                if (i === 1) { root.micVolume = v; root.micMuted = !!m[2] }
            }
        }
    }

    // Leer perfiles disponibles + activo via powerprofilesctl
    // Salida de `powerprofilesctl list`:
    //   * balanced:     (active)
    //     power-saver:
    //     performance:
    Process {
        id: getPowerProc
        command: ["bash", "-c",
            "powerprofilesctl list 2>/dev/null | grep -E '^[* ] [a-z]' || " +
            "echo 'FALLBACK:' $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._powerBuf += d + "\n" }
        onExited: {
            var raw  = root._powerBuf
            root._powerBuf = ""

            // Intentar parsear salida de powerprofilesctl list
            var lines  = raw.trim().split("\n")
            var parsed = []
            var active = ""

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line.length === 0) continue

                // Línea de fallback
                if (line.startsWith("FALLBACK:")) {
                    var fb = line.replace("FALLBACK:", "").trim()
                    if (fb.length > 0) {
                        parsed = [{ id: fb, label: _powerLabel(fb) }]
                        active = fb
                    }
                    break
                }

                // Formato: "* balanced:" (activo) o "  power-saver:" (inactivo)
                var isActive  = line.charAt(0) === "*"
                // quitar el marcador de actividad y los dos puntos finales
                var profileId = line.replace(/^[* ]\s*/, "").replace(/:.*$/, "").trim()
                if (profileId.length === 0) continue

                parsed.push({ id: profileId, label: _powerLabel(profileId) })
                if (isActive) active = profileId
            }

            if (parsed.length > 0) root.powerProfiles = parsed
            if (active.length > 0) root.powerProfile  = active
        }
    }

    // Aplicar brillo
    Process {
        id: setBrightnessProc
        property int targetPct: 50
        command: ["bash", "-c", "brightnessctl set " + targetPct + "% 2>/dev/null"]
    }

    // Aplicar perfil de energía
    Process {
        id: setPowerProc
        property string targetProfile: "balanced"
        command: ["bash", "-c", "powerprofilesctl set " + targetProfile + " 2>/dev/null || sudo " + Paths.scripts + "/set-power-mode.sh " + targetProfile + " 2>/dev/null"]
    }

    // Mutear/desmutear master
    Process {
        id: toggleMasterMuteProc
        command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
        onExited: { root._buf = ""; getVolProc.running = true }
    }

    // Mutear/desmutear mic
    Process {
        id: toggleMicMuteProc
        command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]
        onExited: { root._buf = ""; getVolProc.running = true }
    }

    // Setear volumen master
    Process {
        id: setMasterVolProc
        property real targetVol: 0.75
        command: ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + targetVol.toFixed(2)]
    }

    // Setear volumen mic
    Process {
        id: setMicVolProc
        property real targetVol: 0.75
        command: ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + targetVol.toFixed(2)]
    }

    // ── Funciones internas ────────────────────────────────────────────────
    function _syncSink() {
        var v = root.defaultSink?.audio?.volume
        if (v !== undefined && !isNaN(v)) root.masterVolume = v
        var m = root.defaultSink?.audio?.muted
        if (m !== undefined) root.masterMuted = m
    }

    function _syncSource() {
        var v = root.defaultSource?.audio?.volume
        if (v !== undefined && !isNaN(v)) root.micVolume = v
        var m = root.defaultSource?.audio?.muted
        if (m !== undefined) root.micMuted = m
    }

    function setMasterVolume(v) {
        root.masterVolume = v
        setMasterVolProc.targetVol = v
        if (!setMasterVolProc.running) setMasterVolProc.running = true
    }

    function setMicVol(v) {
        root.micVolume = v
        setMicVolProc.targetVol = v
        if (!setMicVolProc.running) setMicVolProc.running = true
    }

    function setBrightness(pct) {
        root.brightness = pct
        setBrightnessProc.targetPct = pct
        if (!setBrightnessProc.running) setBrightnessProc.running = true
    }

    // Convierte el id raw del sistema a label legible
    function _powerLabel(id) {
        var s = (id || "").toLowerCase()
        if (s === "balanced")    return "Balanced"
        if (s === "powersave" || s === "power-saver" || s === "power_saver") return "Power saver"
        if (s === "performance") return "Performance"
        // capitalizar palabras con guiones → "Ultra Performance"
        return s.split(/[-_]/).map(function(w) {
            return w.charAt(0).toUpperCase() + w.slice(1)
        }).join(" ")
    }

    // Icono Nerd-font por perfil (sin emojis)
    function _powerIcon(id) {
        var s = (id || "").toLowerCase()
        if (s === "performance")              return "󰓅"
        if (s.includes("powersave") || s.includes("power-saver") || s.includes("power_saver")) return "󰁹"
        return "󱐌"
    }

    function setPower(profileId) {
        root.powerProfile = profileId
        setPowerProc.targetProfile = profileId
        if (!setPowerProc.running) setPowerProc.running = true
    }

    function _fmtSpeed(bps) {
        if (!bps || bps < 1024)         return Math.round(bps || 0) + " B/s"
        if (bps < 1024 * 1024)          return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024)   return (bps / (1024 * 1024)).toFixed(1) + " MB/s"
        return (bps / (1024 * 1024 * 1024)).toFixed(2) + " GB/s"
    }

    function formatDuration(ms) {
        if (!ms || isNaN(ms)) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        var sec = s % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function volIcon(vol, muted) {
        if (muted || vol === 0) return "󰝟"
        if (vol < 0.33) return "󰕿"
        if (vol < 0.67) return "󰖀"
        return "󰕾"
    }

    function brightIcon(pct) {
        if (pct < 15) return "󰃞"
        if (pct < 50) return "󰃝"
        if (pct < 85) return "󰃟"
        return "󰃠"
    }

    // ── Bluetooth functions ───────────────────────────────────────────────
    function btSanitizeMac(mac) {
        return mac.replace(/[^0-9A-Fa-f:]/g, "")
    }

    function btRunNextCodecQuery() {
        if (root._btCodecQueue.length === 0 || btCodecProc.running) return
        root._btCurrentCodecMac = root._btCodecQueue[0]
        root._btCodecQueue      = root._btCodecQueue.slice(1)
        root._btCodecBuf        = ""
        var safeMac = root.btSanitizeMac(root._btCurrentCodecMac)
        btCodecProc.command = ["bash", "-c",
            "\"" + Paths.scripts + "/bt-codec.sh\" info " + safeMac]
        btCodecProc.running = true
    }

    function btSetCodec(mac, profile) {
        root._btStatusMsg = ""
        root._btCurrentCodecMac = mac
        var safeMac     = root.btSanitizeMac(mac)
        var safeProfile = profile.replace(/[^a-zA-Z0-9_-]/g, "")
        btSetCodecProc.command = ["bash", "-c",
            "\"" + Paths.scripts + "/bt-codec.sh\" set " + safeMac + " " + safeProfile]
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
        root._btDevices     = source
        root._btPairedList  = paired
        root._btNearbyList  = nearby
        root._btPairedCount = paired.length
        root._btNearbyCount = nearby.length
    }

    function btAutoConnectTrusted() {
        if (!root._btAvailable || !root._btPwrd) return
        if (root._btAutoConnRunning) return
        btRefreshDeviceLists()
        var q = []
        for (var i = 0; i < root._btDevices.length; i++) {
            var d = root._btDevices[i]
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
        root._btAutoConnQueue  = root._btAutoConnQueue
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
        if (!root._btPwrd) { root._btStatusMsg = "✗ Enciende el Bluetooth primero"; return }
        if (device.state === BluetoothDeviceState.Connecting || device.connected) return
        root._btActionDevice   = device
        root._btActionType     = "connect"
        root._btWorking        = true
        root._btStatusMsg      = "Conectando..."
        device.connect()
        btActionTimeout.restart()
    }

    function btDisconnectDevice(device) {
        if (!device || !device.connected) return
        root._btActionDevice = device
        root._btActionType   = "disconnect"
        root._btWorking      = true
        root._btStatusMsg    = "Desconectando..."
        device.disconnect()
        btActionTimeout.restart()
    }

    function btPairDevice(device) {
        if (!device) return
        if (!root._btPwrd) { root._btStatusMsg = "✗ Enciende el Bluetooth primero"; return }
        if (device.pairing || device.paired) return
        root._btActionDevice = device
        root._btActionType   = "pair"
        root._btWorking      = true
        root._btStatusMsg    = "Emparejando..."
        device.pair()
        btActionTimeout.restart()
    }

    function btForgetDevice(device) {
        if (!device) return
        root._btActionDevice = device
        root._btActionType   = "forget"
        root._btWorking      = true
        root._btStatusMsg    = "Olvidando..."
        device.forget()
        btActionTimeout.restart()
    }

    // ── Bluetooth timers & reactivity ─────────────────────────────────────
    Timer {
        id: btScanTimer
        interval: 13000
        onTriggered: {
            if (root._btAdapter) root._btAdapter.discovering = false
            root._btScanning = false
        }
    }

    Timer {
        id: btActionTimeout
        interval: 10000
        onTriggered: { if (root._btWorking) root.btResetAction("✗ Tiempo de espera") }
    }

    Timer {
        id: btAutoConnTimer
        interval: 1500
        onTriggered: root.btAutoConnNext()
    }

    Timer {
        id: btConnectRetryTimer
        interval: 1500
        onTriggered: {
            if (!root._btActionDevice || root._btActionType !== "connect") return
            root._btConnectRetries++
            root._btStatusMsg     = "Reintentando (" + root._btConnectRetries + "/2)..."
            root._btSawConnecting = false
            root._btActionDevice.connect()
            btActionTimeout.restart()
        }
    }

    Timer {
        id: btRefreshDebounce
        interval: 60
        onTriggered: root.btRefreshDeviceLists()
    }

    Timer {
        id: btCodecRefreshTimer
        interval: 12000; repeat: true
        running: root.visible && root._expandedToggle === "bluetooth"
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

    // Observe adapter device changes
    Connections {
        target: root._btAdapter ? root._btAdapter.devices : null
        function onObjectInsertedPost(object, index) { root.btRefreshDeviceLists() }
        function onObjectRemovedPost(object, index) {
            root.btRefreshDeviceLists()
            if (root._btActionType === "forget" && root._btActionDevice === object)
                root.btResetAction("✓ Dispositivo olvidado")
        }
    }

    Instantiator {
        model: root._btAdapter ? root._btAdapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged()     { btRefreshDebounce.restart() }
            function onConnectedChanged()  { btRefreshDebounce.restart() }
            function onTrustedChanged()    { btRefreshDebounce.restart() }
            function onNameChanged()       { btRefreshDebounce.restart() }
            function onDeviceNameChanged() { btRefreshDebounce.restart() }
            function onStateChanged()      { btRefreshDebounce.restart() }
        }
    }

    Connections {
        target: root._btActionDevice
        function onConnectedChanged() {
            if (!root._btActionDevice) return
            if (root._btActionType === "connect" && root._btActionDevice.connected) {
                root._btConnectRetries = 0
                root.btResetAction("✓ Conectado")
            } else if (root._btActionType === "disconnect" && !root._btActionDevice.connected) {
                root.btResetAction("✓ Desconectado")
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
                    root.btResetAction("✗ No se pudo conectar")
                }
            }
        }
        function onPairedChanged() {
            if (!root._btActionDevice) return
            if (root._btActionType === "pair" && root._btActionDevice.paired) {
                root._btActionDevice.trusted = true
                root.btResetAction("✓ Emparejado")
            }
        }
        function onPairingChanged() {
            if (!root._btActionDevice) return
            if (root._btActionType === "pair" && !root._btActionDevice.pairing && !root._btActionDevice.paired)
                root.btResetAction("✗ No se pudo emparejar")
        }
    }

    Connections {
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

    // ── Bluetooth codec processes ─────────────────────────────────────────
    Process {
        id: btCodecProc
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._btCodecBuf += d + "\n" }
        onExited: {
            var output = root._btCodecBuf.trim()
            root._btCodecBuf = ""
            try {
                var data   = JSON.parse(output)
                var mac    = root._btCurrentCodecMac.toUpperCase()
                var newMap = ({})
                Object.assign(newMap, root._btCodecData)
                newMap[mac]         = data
                root._btCodecData   = newMap
            } catch(e) {}
            root.btRunNextCodecQuery()
        }
    }

    Process {
        id: btSetCodecProc
        command: ["bash", "-c", ""]
        onExited: function(ec) {
            root._btStatusMsg = ec === 0 ? "✓ Codec cambiado" : "✗ Error al cambiar codec"
            Qt.callLater(() => root.btRunNextCodecQuery())
        }
    }

    // ── WiFi functions ────────────────────────────────────────────────────
    function wifiSignalIcon(s) {
        if (s >= 80) return "󰤨"
        if (s >= 60) return "󰤥"
        if (s >= 40) return "󰤢"
        return "󰤟"
    }

    function wifiLoadNetworks() {
        root._wifiWorking = true
        wIfaceProc.running   = true
        wRadioProc.running   = true
        wNetListProc.running = true
        wSavedProc.running   = true
        wEthProc.running     = true
    }

    function wifiToggleRadio() {
        root._wifiWorking = true
        wToggleRadioProc.command = ["bash", "-c",
            "LANG=C nmcli radio wifi " + (root._wifiRadioOn ? "off" : "on") + " 2>/dev/null"]
        wToggleRadioProc.running = true
    }

    function wifiRescan() {
        root._wifiScanning = true
        wRescanProc.running = true
    }

    function wifiConnectTo(ssid, password) {
        root._wifiWorking   = true
        root._wifiStatusMsg = ""
        var cmd = [
            "bash", "-c",
            "SSID=$1; PASS=$2; IFACE=$(nmcli dev | grep wifi | grep -v p2p | awk '{print $1}' | head -1); " +
            "nmcli con delete \"$SSID\" 2>/dev/null || true; " +
            "nmcli con add type wifi con-name \"$SSID\" ssid \"$SSID\" " +
            "wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$PASS\" 2>&1 && " +
            "nmcli con up \"$SSID\" ifname \"$IFACE\" 2>&1",
            "--", ssid, password
        ]
        wConnectProc.command = cmd
        wConnectProc.running = true
    }

    function wifiDisconnect() {
        if (!root._wifiIface || root._wifiIface === "") {
            root._wifiStatusMsg = "✗ No hay interfaz WiFi"
            return
        }
        root._wifiWorking = true
        wDisconnectProc.command = ["bash", "-c",
            "LANG=C nmcli dev disconnect " + root._wifiIface + " 2>/dev/null"]
        wDisconnectProc.running = true
    }

    function wifiFetchPasswordFor(ssid, idx) {
        root._wifiPwFetchSsid      = ssid
        root._wifiPwFetchIdx       = idx
        root._wifiPwFetchResult    = ""
        root._wifiPwFetchResultIdx = -2
        wSharedPwFetchProc._buf    = ""
        wSharedPwFetchProc.command = [
            "bash", "-c",
            "nmcli -s -t -f 802-11-wireless-security.psk con show "
            + JSON.stringify(ssid) + " 2>/dev/null | cut -d: -f2-"
        ]
        wSharedPwFetchProc.running = true
    }

    function wifiMenuCopyPassword() {
        var ssid = root._wifiMenuSsid
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

    function wifiMenuForgetNetwork() {
        var ssid = root._wifiMenuSsid
        wMenuForgetProc.command = ["bash", "-c",
            "nmcli con delete " + JSON.stringify(ssid) + " 2>/dev/null"]
        wMenuForgetProc.running = true
    }

    // ── WiFi processes ────────────────────────────────────────────────────
    Process {
        id: wIfaceProc
        command: ["bash", "-c",
            "LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null "
            + "| grep ':wifi:connected' | cut -d: -f1 | head -1; "
            + "LANG=C nmcli -t -f active,ssid dev wifi 2>/dev/null "
            + "| grep '^yes:' | cut -d: -f2- | head -1"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wIfaceBuf += d + "\n" }
        onExited: {
            var parts = root._wIfaceBuf.trim().split("\n")
            root._wIfaceBuf = ""
            root._wifiIface        = (parts[0] || "").trim()
            root._wifiConnectedSsid = (parts[1] || "").trim()
        }
    }

    Process {
        id: wRadioProc
        command: ["bash", "-c", "LANG=C nmcli radio wifi 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wRadioBuf += d }
        onExited: {
            root._wifiRadioOn = root._wRadioBuf.trim() === "enabled"
            root._wRadioBuf = ""
        }
    }

    Process {
        id: wSavedProc
        command: ["bash", "-c",
            "LANG=C nmcli -t -f name,type con show 2>/dev/null "
            + "| awk -F: '$2==\"802-11-wireless\"{print $1}'"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wSavedBuf += d + "\n" }
        onExited: {
            var lines = root._wSavedBuf.trim().split("\n")
            root._wSavedBuf = ""
            var map = {}
            for (var i = 0; i < lines.length; i++) {
                var s = lines[i].trim()
                if (s) map[s] = true
            }
            root._wifiSavedSsids = map
        }
    }

    Process {
        id: wEthProc
        command: ["bash", "-c",
            "ETH_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':ethernet:connected' | cut -d: -f1); "
            + "if [ -n \"$ETH_IFACE\" ]; then "
            + "echo \"connected\"; "
            + "LANG=C nmcli -t -f IP4.ADDRESS dev show \"$ETH_IFACE\" 2>/dev/null | cut -d: -f2 | cut -d/ -f1; "
            + "LANG=C nmcli -t -f DEVICE,HWADDR dev show 2>/dev/null | grep \"^$ETH_IFACE:\" | cut -d: -f2; "
            + "ethtool \"$ETH_IFACE\" 2>/dev/null | grep \"Speed:\" | awk '{print $2}'; "
            + "else echo \"disconnected\"; fi"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wEthBuf += d + "\n" }
        onExited: {
            var lines = root._wEthBuf.trim().split("\n")
            root._wEthBuf = ""
            root._ethConnected = (lines[0] || "").trim() === "connected"
            root._ethIp    = (lines[1] || "").trim()
            root._ethMac   = (lines[2] || "").trim()
            root._ethSpeed = (lines[3] || "").trim()
        }
    }

    Process {
        id: wNetListProc
        command: ["bash", "-c",
            "LANG=C nmcli -t -f active,ssid,signal,security dev wifi list 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wNetBuf += d + "\n" }
        onExited: {
            var lines  = root._wNetBuf.trim().split("\n")
            root._wNetBuf = ""
            var seen   = {}
            var result = []
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (!l) continue
                var p = l.split(":")
                if (p.length < 3) continue
                var active   = p[0] === "yes"
                var security = p[p.length - 1].trim()
                var sig      = parseInt(p[p.length - 2]) || 0
                var ssid     = p.slice(1, p.length - 2).join(":")
                if (!ssid) continue
                if (seen[ssid]) continue
                seen[ssid] = true
                if (active) root._wifiConnectedSsid = ssid
                result.push({ ssid: ssid, signal: sig, security: security, active: active })
            }
            result.sort((a, b) => {
                if (a.active !== b.active) return a.active ? -1 : 1
                return b.signal - a.signal
            })
            root._wifiNetworks = result
            root._wifiWorking  = false
            if (root._wifiIface) wWifiInfoProc.running = true
        }
    }

    Process {
        id: wWifiInfoProc
        property string _buf: ""
        command: ["bash", "-c",
            "IFACE=$(nmcli dev | grep wifi | grep -v p2p | awk '{print $1}' | head -1); "
            + "if [ -n \"$IFACE\" ]; then "
            + "nmcli -g IP4.ADDRESS dev show \"$IFACE\" 2>/dev/null; "
            + "nmcli -g IP4.GATEWAY dev show \"$IFACE\" 2>/dev/null; "
            + "nmcli -g IP4.DNS dev show \"$IFACE\" 2>/dev/null; "
            + "fi"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wWifiInfoProc._buf += d + "\n" }
        onExited: {
            var lines = wWifiInfoProc._buf.trim().split("\n")
            wWifiInfoProc._buf = ""
            root._wifiIp      = (lines[0] || "").split("/")[0].trim()
            root._wifiGateway = (lines[1] || "").trim()
            root._wifiDns     = (lines[2] || "").trim()
        }
    }

    Process {
        id: wToggleRadioProc
        command: ["bash", "-c", ""]
        onExited: Qt.callLater(() => { root.wifiLoadNetworks(); root._wifiWorking = false })
    }

    Process {
        id: wRescanProc
        command: ["bash", "-c", "LANG=C nmcli dev wifi rescan 2>/dev/null; sleep 1"]
        onExited: { root._wifiScanning = false; root.wifiLoadNetworks() }
    }

    Process {
        id: wConnectProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wConnectProc._buf += d + "\n" }
        onExited: function(exitCode) {
            var output = wConnectProc._buf.trim()
            wConnectProc._buf = ""
            root._wifiWorking = false
            if (exitCode === 0) {
                root._wifiStatusMsg    = "✓ Conectado"
                root._wifiSelectedIdx  = -1
                root._wifiPasswordByIndex = ({})
            } else {
                var errLines = output.split("\n")
                var errMsg = errLines.filter(l => l && !l.startsWith("DEBUG:"))[0] || "Error de conexión"
                root._wifiStatusMsg = "✗ " + errMsg.substring(0, 40)
            }
            Qt.callLater(() => root.wifiLoadNetworks())
        }
    }

    Process {
        id: wDisconnectProc
        command: ["bash", "-c", ""]
        onExited: { root._wifiWorking = false; Qt.callLater(() => root.wifiLoadNetworks()) }
    }

    Process {
        id: wSavedPwProc
        property string ssid:  ""
        property int    idx:   -1
        property string _buf:  ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wSavedPwProc._buf += d }
        onExited: function() {
            var pw = wSavedPwProc._buf.trim()
            wSavedPwProc._buf = ""
            root._wifiWorking = false
            if (pw.length > 0) {
                root.wifiConnectTo(wSavedPwProc.ssid, pw)
            } else {
                root._wifiStatusMsg = "✗ No se pudo obtener contraseña guardada"
            }
        }
    }

    Process {
        id: wSharedPwFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wSharedPwFetchProc._buf += d }
        onExited: {
            var pw = wSharedPwFetchProc._buf.trim()
            wSharedPwFetchProc._buf = ""
            root._wifiPwFetchResult    = pw
            root._wifiPwFetchResultIdx = root._wifiPwFetchIdx
        }
    }

    Process {
        id: wMenuCopyFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wMenuCopyFetchProc._buf += d }
        onExited: {
            var output = wMenuCopyFetchProc._buf.trim()
            wMenuCopyFetchProc._buf = ""
            var pw = ""
            var errorMsg = ""
            output.split("\n").forEach(function(line) {
                if (line.startsWith("PASS:"))  { pw = line.substring(5) }
                else if (line.startsWith("ERROR:")) { errorMsg = line.substring(6) }
            })
            if (pw !== "") {
                wMenuCopyExecProc.command = ["bash", "-c", 'printf "%s" "$1" | wl-copy', "--", pw]
                wMenuCopyExecProc.running = true
            } else {
                root._wifiStatusMsg = "✗ " + (errorMsg || "No se encontró la contraseña")
            }
        }
    }

    Process {
        id: wMenuCopyExecProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            root._wifiStatusMsg = ec === 0 ? "✓ Contraseña copiada" : "✗ wl-copy error " + ec
        }
    }

    Process {
        id: wMenuForgetProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            root._wifiStatusMsg = ec === 0 ? "✓ Red olvidada" : "✗ No se pudo olvidar"
            Qt.callLater(() => root.wifiLoadNetworks())
        }
    }

    Timer {
        interval: 15000
        running: root.visible && root._expandedToggle === "wifi" && !root._wifiWorking
        repeat: true
        onTriggered: root.wifiLoadNetworks()
    }

    // ── Startup ────────────────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            root._buf      = ""
            root._powerBuf = ""
            root._diskBuf  = ""
            root._cpuLoaded = false
            root._gpuLoaded = false
            getBrightnessProc.running = true
            getVolProc.running        = true
            getPowerProc.running      = true
            diskDetailProc.running    = true
            root._syncPlayerPos()
            root._pwRev++
            root._btRev++
            Qt.callLater(function() { ccCard.forceActiveFocus() })
        } else {
            root._expandedMetric = ""
            root._showConfirm    = false
        }
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    // ── Card principal ────────────────────────────────────────────────────
    Rectangle {
        id: ccCard
        focus: true
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 36
            rightMargin: 12
        }
        width: 360
        height: Math.min(parent.height - 72, ccFlick.contentHeight + 24)
        radius: 16
        color: Theme.cardBg3

        Keys.onEscapePressed: root.visible = false

        // Borde sutil
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
            border.width: 1
        }

        MouseArea { anchors.fill: parent }

        // ── Scroll container ───────────────────────────────────────────────
        Flickable {
            id: ccFlick
            anchors { fill: parent; margins: 12 }
            contentWidth: width
            contentHeight: scrollContent.height
            clip: true
            boundsMovement: Flickable.StopAtBounds

            Column {
                id: scrollContent
                // height se enlaza al implicitHeight real + animaciones hijas
                height: implicitHeight
                width: ccFlick.width
                spacing: 0

                // ── POWER BAR ─────────────────────────────────────────────
                Item {
                    width: parent.width; height: 44

                    // Power actions row — centered
                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: [
                                { icon: "⏻",  label: "Shut down",  cmd: ["systemctl", "poweroff"],        color: "#ff7b72", critical: true  },
                                { icon: "󰜉",  label: "Reboot",     cmd: ["systemctl", "reboot"],          color: "#e3b341", critical: true  },
                                { icon: "󰌾",  label: "Lock",       cmd: ["loginctl", "lock-session"],     color: "#79c0ff", critical: false },
                                { icon: "󰍃",  label: "Log out",    cmd: ["hyprctl", "dispatch", "exit"],  color: "#d2a8ff", critical: false },
                                { icon: "󰒲",  label: "Sleep",      cmd: ["systemctl", "suspend"],         color: "#7ee787", critical: false }
                            ]

                            Rectangle {
                                id: pwBtn
                                required property var modelData
                                width: 36; height: 36; radius: 9
                                color: pwHov.containsMouse
                                    ? Qt.rgba(Theme.surface3.r, Theme.surface3.g, Theme.surface3.b, 1)
                                    : Theme.surface2
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    color: pwHov.containsMouse ? modelData.color : Theme.muted1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    id: pwHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.critical) {
                                            root._confirmLabel = modelData.label
                                            root._confirmCmd   = modelData.cmd
                                            root._showConfirm  = true
                                        } else {
                                            root.visible = false
                                            ccExecProc.runCmd(modelData.cmd)
                                        }
                                    }
                                }

                                // Tooltip label on hover
                                Rectangle {
                                    visible: pwHov.containsMouse
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 4
                                    width: tipText.implicitWidth + 10; height: 18
                                    radius: 4; color: Theme.surface3

                                    Text {
                                        id: tipText
                                        anchors.centerIn: parent
                                        text: pwBtn.modelData.label
                                        font.pixelSize: 9; color: Theme.text
                                    }
                                }
                            }
                        }
                    }

                    // Close button — top right
                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 24; height: 24; radius: 6
                        color: closeHov.containsMouse ? Theme.surface3 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                        MouseArea { id: closeHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.visible = false }
                    }
                }

                // ── SEPARADOR ──────────────────────────────────────────────
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
                Item { width: parent.width; height: 8 }

                // ══════════════════════════════════════════════════════════
                // SECCIÓN 1 — Sliders de audio y brillo
                // ══════════════════════════════════════════════════════════

                // Slider volumen master
                Item {
                    width: parent.width; height: 36
                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        // Ícono / botón mute
                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: muteHov.containsMouse ? Theme.surface3 : Theme.surface2
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.volIcon(root.masterVolume, root.masterMuted)
                                font.pixelSize: 14
                                color: root.masterMuted ? Theme.muted2 : Theme.accent
                            }
                            MouseArea {
                                id: muteHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (!toggleMasterMuteProc.running) toggleMasterMuteProc.running = true }
                            }
                        }
                    }

                    // Track del slider
                    Item {
                        anchors {
                            left: parent.left; leftMargin: 44
                            right: parent.right; rightMargin: 44
                            verticalCenter: parent.verticalCenter
                        }
                        height: 20

                        Rectangle {
                            id: volTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2
                            color: Theme.surface3
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(8, root.masterVolume * volTrack.width)
                            height: 4; radius: 2
                            color: root.masterMuted ? Theme.muted2 : Theme.accent
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                        // Thumb
                        Rectangle {
                            id: volThumb
                            x: Math.min(root.masterVolume * volTrack.width - 6, volTrack.width - 12)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12; radius: 6
                            color: Theme.accent
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => {
                                if (mouse.buttons & Qt.LeftButton) {
                                    var v = Math.max(0, Math.min(1.5, mouse.x / volTrack.width))
                                    root.setMasterVolume(v)
                                }
                            }
                            onClicked: mouse => {
                                var v = Math.max(0, Math.min(1.5, mouse.x / volTrack.width))
                                root.setMasterVolume(v)
                            }
                        }
                    }

                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root.masterMuted ? "Muted" : Math.round(root.masterVolume * 100) + "%"
                        font.pixelSize: 10; color: root.masterMuted ? Theme.muted2 : Theme.muted1
                        width: 36; horizontalAlignment: Text.AlignRight
                    }
                }

                // Slider micrófono
                Item {
                    width: parent.width; height: 36
                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: micHov.containsMouse ? Theme.surface3 : Theme.surface2
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.micMuted ? "󰍭" : "󰍬"
                                font.pixelSize: 14
                                color: root.micMuted ? Theme.muted2 : Theme.accent
                            }
                            MouseArea {
                                id: micHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (!toggleMicMuteProc.running) toggleMicMuteProc.running = true }
                            }
                        }
                    }
                    Item {
                        anchors {
                            left: parent.left; leftMargin: 44
                            right: parent.right; rightMargin: 44
                            verticalCenter: parent.verticalCenter
                        }
                        height: 20
                        Rectangle {
                            id: micTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2; color: Theme.surface3
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(8, root.micVolume * micTrack.width)
                            height: 4; radius: 2
                            color: root.micMuted ? Theme.muted2 : Theme.accent
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                        Rectangle {
                            x: Math.min(root.micVolume * micTrack.width - 6, micTrack.width - 12)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12; radius: 6; color: Theme.accent
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => {
                                if (mouse.buttons & Qt.LeftButton) {
                                    var v = Math.max(0, Math.min(1.5, mouse.x / micTrack.width))
                                    root.setMicVol(v)
                                }
                            }
                            onClicked: mouse => {
                                var v = Math.max(0, Math.min(1.5, mouse.x / micTrack.width))
                                root.setMicVol(v)
                            }
                        }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root.micMuted ? "Muted" : Math.round(root.micVolume * 100) + "%"
                        font.pixelSize: 10; color: root.micMuted ? Theme.muted2 : Theme.muted1
                        width: 36; horizontalAlignment: Text.AlignRight
                    }
                }

                // Slider brillo
                Item {
                    width: parent.width; height: 36
                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Rectangle {
                            width: 28; height: 28; radius: 8; color: Theme.surface2
                            Text {
                                anchors.centerIn: parent
                                text: root.brightIcon(root.brightness)
                                font.pixelSize: 14; color: Theme.accent
                            }
                        }
                    }
                    Item {
                        anchors {
                            left: parent.left; leftMargin: 44
                            right: parent.right; rightMargin: 44
                            verticalCenter: parent.verticalCenter
                        }
                        height: 20
                        Rectangle {
                            id: briTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2; color: Theme.surface3
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(8, (root.brightness / 100) * briTrack.width)
                            height: 4; radius: 2; color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                        Rectangle {
                            x: Math.min((root.brightness / 100) * briTrack.width - 6, briTrack.width - 12)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12; radius: 6; color: Theme.accent
                            Behavior on x { NumberAnimation { duration: 80 } }
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => {
                                if (mouse.buttons & Qt.LeftButton) {
                                    var v = Math.max(1, Math.min(100, Math.round(mouse.x / briTrack.width * 100)))
                                    root.setBrightness(v)
                                }
                            }
                            onClicked: mouse => {
                                var v = Math.max(1, Math.min(100, Math.round(mouse.x / briTrack.width * 100)))
                                root.setBrightness(v)
                            }
                        }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root.brightness + "%"
                        font.pixelSize: 10; color: Theme.muted1
                        width: 36; horizontalAlignment: Text.AlignRight
                    }
                }

                // ── Apps de audio — header colapsable ──────────────────────
                Item { width: parent.width; height: 8 }
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

                Item {
                    width: parent.width; height: 36

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Applications"
                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.muted1
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6

                        Text {
                            visible: root.audioStreams.length > 0
                            text: root.audioStreams.length + " active"
                            font.pixelSize: 10; color: Theme.muted2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 24; height: 24; radius: 6
                            color: appsTogHov.containsMouse ? Theme.surface3 : Theme.surface2
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.appsExpanded ? "󰅃" : "󰅀"
                                font.pixelSize: 12; color: Theme.muted1
                            }
                            MouseArea {
                                id: appsTogHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.appsExpanded = !root.appsExpanded
                            }
                        }
                    }
                }

                // Lista de apps de audio
                 Column {
                     width: parent.width
                     spacing: 4
                     height: root.appsExpanded ? implicitHeight : 0
                     clip: true
                     Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: root.audioStreams

                        Item {
                            id: streamRow
                            required property var modelData
                            required property int index
                            width: parent.width; height: 38

                            property real streamVol: modelData.node?.audio?.volume ?? 1.0
                            property bool streamMuted: modelData.node?.audio?.muted ?? false

                            PwObjectTracker { objects: [streamRow.modelData.node] }

                            Connections {
                                target: streamRow.modelData.node?.audio ?? null
                                function onVolumesChanged() {
                                    var v = streamRow.modelData.node?.audio?.volume
                                    if (v !== undefined && !isNaN(v)) streamRow.streamVol = v
                                }
                                function onMutedChanged() {
                                    var m = streamRow.modelData.node?.audio?.muted
                                    if (m !== undefined) streamRow.streamMuted = m
                                }
                            }

                            // Ícono mute por app
                            Rectangle {
                                id: streamMuteBtn
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: 26; height: 26; radius: 7
                                color: streamMutHov.containsMouse ? Theme.surface3 : Theme.surface2
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: streamRow.streamMuted ? "󰝟" : "󰕾"
                                    font.pixelSize: 12
                                    color: streamRow.streamMuted ? Theme.muted2 : Theme.accent
                                }
                                MouseArea {
                                    id: streamMutHov; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var n = streamRow.modelData.node
                                        if (n && n.audio) {
                                            var safe = (streamRow.modelData.name || "").replace(/'/g, "'\\''")
                                            streamMuteProc.command = ["bash", "-c",
                                                "pactl set-sink-input-mute " + n.id + " toggle 2>/dev/null"]
                                            streamMuteProc.running = true
                                        }
                                    }
                                }
                            }

                            // Nombre app
                            Text {
                                anchors {
                                    left: streamMuteBtn.right; leftMargin: 6
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 80
                                text: streamRow.modelData.label
                                font.pixelSize: 11; color: Theme.text
                                elide: Text.ElideRight
                            }

                            // Slider volumen app
                            Item {
                                anchors {
                                    left: parent.left; leftMargin: 120
                                    right: parent.right; rightMargin: 38
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 20

                                Rectangle {
                                    id: stTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width; height: 4; radius: 2; color: Theme.surface3
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(6, Math.min(1, streamRow.streamVol) * stTrack.width)
                                    height: 4; radius: 2
                                    color: streamRow.streamMuted ? Theme.muted2 : Theme.accent
                                    Behavior on width { NumberAnimation { duration: 60 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPositionChanged: mouse => {
                                        if (!(mouse.buttons & Qt.LeftButton)) return
                                        var v = Math.max(0, Math.min(1.5, mouse.x / stTrack.width))
                                        var n = streamRow.modelData.node
                                        if (n && n.id !== undefined) {
                                            streamVolProc.command = ["bash", "-c",
                                                "pactl set-sink-input-volume " + n.id + " " + v.toFixed(2) + " 2>/dev/null"]
                                            if (!streamVolProc.running) streamVolProc.running = true
                                        }
                                    }
                                    onClicked: mouse => {
                                        var v = Math.max(0, Math.min(1.5, mouse.x / stTrack.width))
                                        var n = streamRow.modelData.node
                                        if (n && n.id !== undefined) {
                                            streamVolProc.command = ["bash", "-c",
                                                "pactl set-sink-input-volume " + n.id + " " + v.toFixed(2) + " 2>/dev/null"]
                                            if (!streamVolProc.running) streamVolProc.running = true
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: Math.round(Math.min(streamRow.streamVol, 1.5) * 100) + "%"
                                font.pixelSize: 10; color: Theme.muted2; width: 32
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Vacío si no hay streams
                    Item {
                        visible: root.audioStreams.length === 0
                        width: parent.width; height: 30
                        Text {
                            anchors.centerIn: parent
                            text: "No active applications"
                            font.pixelSize: 11; color: Theme.muted2
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════
                // SECCIÓN 2 — Conectividad y controles rápidos (grid 2×2)
                // ══════════════════════════════════════════════════════════
                Item { width: parent.width; height: 10 }
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
                Item { width: parent.width; height: 8 }

                Grid {
                    width: parent.width
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 6

                    // ── WiFi ──────────────────────────────────────────────
                    Rectangle {
                        id: wifiCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._expandedToggle === "wifi"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (SysData.netConnected
                                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                           : Theme.surface2))
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Barra lateral activo
                        Rectangle {
                            visible: SysData.netConnected || root._expandedToggle === "wifi"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: (SysData.netConnected || root._expandedToggle === "wifi") ? 14 : 10
                                rightMargin: 10
                            }
                            spacing: 8

                            Text {
                                text: {
                                    if (SysData.netConnectionType === "ethernet") return "󰈀"
                                    if (!SysData.netRadioOn)      return "󰤮"
                                    if (!SysData.netConnected)    return "󰤭"
                                    if (SysData.netSignal >= 80)  return "󰤨"
                                    if (SysData.netSignal >= 60)  return "󰤥"
                                    if (SysData.netSignal >= 40)  return "󰤢"
                                    return "󰤟"
                                }
                                font.pixelSize: 18
                                color: SysData.netConnected ? Theme.accent : Theme.muted2
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "WiFi"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                }
                                Text {
                                    width: parent.width
                                    text: {
                                        if (SysData.netConnectionType === "ethernet") return "Ethernet"
                                        if (!SysData.netRadioOn)      return "Radio off"
                                        if (!SysData.netConnected)    return "Disconnected"
                                        return (SysData.netSsid || "Connected") + " · " + SysData.netSignal + "%"
                                    }
                                    font.pixelSize: 9
                                    color: SysData.netConnected ? Theme.muted1 : Theme.muted2
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: root._expandedToggle === "wifi" ? "󰅃" : "󰅀"
                                font.pixelSize: 11; color: Theme.muted2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: wifiCard.hov = true
                            onExited:  wifiCard.hov = false
                            onClicked: {
                                var next = root._expandedToggle === "wifi" ? "" : "wifi"
                                root._expandedToggle = next
                                if (next === "wifi") {
                                    root._wifiStatusMsg    = ""
                                    root._wifiSelectedIdx  = -1
                                    root._wifiPasswordByIndex = ({})
                                    root.wifiLoadNetworks()
                                }
                            }
                        }
                    }

                    // ── Bluetooth ─────────────────────────────────────────
                    Rectangle {
                        id: btCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._expandedToggle === "bluetooth"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (root.btConnectedCount > 0
                                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                           : Theme.surface2))
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root.btConnectedCount > 0 || root._expandedToggle === "bluetooth"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: (root.btConnectedCount > 0 || root._expandedToggle === "bluetooth") ? 14 : 10
                                rightMargin: 10
                            }
                            spacing: 8

                            Text {
                                text: root.btConnectedCount > 0 ? "󰂱"
                                    : (root.btPowered ? "󰂯" : "󰂲")
                                font.pixelSize: 18
                                color: root.btConnectedCount > 0 ? Theme.accent
                                     : (root.btPowered ? Theme.muted1 : Theme.muted2)
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "Bluetooth"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                }
                                Text {
                                    width: parent.width
                                    text: {
                                        if (!root.btAdapter)           return "Not available"
                                        if (!root.btPowered)           return "Disabled"
                                        if (root.btConnectedCount > 0) {
                                            for (var i = 0; i < root.btDeviceList.length; i++) {
                                                if (root.btDeviceList[i].connected)
                                                    return root.btDeviceList[i].name
                                            }
                                        }
                                        return "No connections"
                                    }
                                    font.pixelSize: 9
                                    color: root.btConnectedCount > 0 ? Theme.muted1 : Theme.muted2
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: root._expandedToggle === "bluetooth" ? "󰅃" : "󰅀"
                                font.pixelSize: 11; color: Theme.muted2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: btCard.hov = true
                            onExited:  btCard.hov = false
                            onClicked: {
                                var next = root._expandedToggle === "bluetooth" ? "" : "bluetooth"
                                root._expandedToggle = next
                                if (next === "bluetooth") {
                                    root._btStatusMsg = ""
                                    root.btRefreshDeviceLists()
                                    if (root._btPwrd && root._btAdapter) {
                                        root._btAdapter.discoverable = true
                                        root._btAdapter.pairable     = true
                                        root.btAutoConnectTrusted()
                                    }
                                } else {
                                    if (root._btAdapter) {
                                        root._btAdapter.discovering  = false
                                        root._btAdapter.discoverable = false
                                        root._btAdapter.pairable     = false
                                    }
                                    root._btScanning = false
                                    btScanTimer.stop()
                                    btActionTimeout.stop()
                                    btAutoConnTimer.stop()
                                    btConnectRetryTimer.stop()
                                }
                            }
                        }
                    }

                    // ── Power & Fans ──────────────────────────────────────
                    Rectangle {
                        id: powerCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._expandedToggle === "power"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._expandedToggle === "power"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: root._expandedToggle === "power" ? 14 : 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                text: root._powerIcon(root.powerProfile)
                                font.pixelSize: 18
                                color: {
                                    var s = (root.powerProfile || "").toLowerCase()
                                    if (s === "performance") return "#ff7b72"
                                    if (s.includes("powersave") || s.includes("power-saver") || s.includes("power_saver")) return "#79c0ff"
                                    return Theme.accent
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Power & Fans"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                Text {
                                    width: parent.width
                                    text: {
                                        var p = root._powerLabel(root.powerProfile) || "—"
                                        if (SysData.fanAvailable && SysData.fan1Rpm > 0)
                                            p += " · " + SysData.fan1Rpm + " rpm"
                                        return p
                                    }
                                    font.pixelSize: 9; color: Theme.muted1
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: root._expandedToggle === "power" ? "󰅃" : "󰅀"
                                font.pixelSize: 11; color: Theme.muted2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: powerCard.hov = true
                            onExited:  powerCard.hov = false
                            onClicked: {
                                var next = root._expandedToggle === "power" ? "" : "power"
                                root._expandedToggle = next
                                if (next === "power" && root._fanProfiles.length === 0)
                                    fanProfilesProc.running = true
                            }
                        }
                    }

                    // ── Audio avanzado ────────────────────────────────────
                    Rectangle {
                        id: audioCard2
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3 : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            Text { text: "󰕾"; font.pixelSize: 18; color: Theme.accent }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "Audio"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                }
                                Text {
                                    text: "Outputs &amp; inputs"
                                    font.pixelSize: 9; color: Theme.muted1
                                }
                            }

                            Text { text: "󰅂"; font.pixelSize: 11; color: Theme.muted2 }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: audioCard2.hov = true
                            onExited:  audioCard2.hov = false
                            onClicked: { root.visible = false; root.requestOpenAudio(root.screen) }
                        }
                    }

                    // ── Battery ───────────────────────────────────────────
                    Rectangle {
                        id: batCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._expandedToggle === "battery"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._expandedToggle === "battery"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: root._expandedToggle === "battery" ? 14 : 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                text: {
                                    if (!SysData.batAvailable) return "󰂑"
                                    if (SysData.batCharging)   return "󰂄"
                                    if (SysData.batPercent > 80) return "󰁹"
                                    if (SysData.batPercent > 60) return "󰂁"
                                    if (SysData.batPercent > 40) return "󰁿"
                                    if (SysData.batPercent > 20) return "󰁽"
                                    return "󰂃"
                                }
                                font.pixelSize: 18
                                color: {
                                    if (!SysData.batAvailable) return Theme.muted2
                                    if (SysData.batCharging)   return Theme.success
                                    if (SysData.batPercent > 50) return Theme.accent
                                    if (SysData.batPercent > 20) return Theme.yellow
                                    return Theme.error
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Battery"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                Text {
                                    text: !SysData.batAvailable ? "Not available"
                                        : SysData.batCharging   ? SysData.batPercent + "% · Charging"
                                        : SysData.batStatus === "Full" ? "Full"
                                        : SysData.batPercent + "% · " + SysData.batStatus
                                    font.pixelSize: 9
                                    color: SysData.batPercent <= 20 && !SysData.batCharging ? Theme.error : Theme.muted1
                                    elide: Text.ElideRight; width: parent.width
                                }
                            }

                            Text {
                                text: root._expandedToggle === "battery" ? "󰅃" : "󰅀"
                                font.pixelSize: 11; color: Theme.muted2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: batCard.hov = true
                            onExited:  batCard.hov = false
                            onClicked: {
                                var next = root._expandedToggle === "battery" ? "" : "battery"
                                root._expandedToggle = next
                                if (next === "battery")
                                    batDetailProc.running = true
                            }
                        }
                    }

                    // ── Language ──────────────────────────────────────────
                    Rectangle {
                        id: langCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._expandedToggle === "language"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._expandedToggle === "language"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: root._expandedToggle === "language" ? 14 : 10; rightMargin: 10 }
                            spacing: 8

                            Text { text: "󰌌"; font.pixelSize: 18; color: Theme.accent }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Language"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                Text {
                                    text: root._langLayout !== "—" ? root._langLayout + " · " + root._langLocale : "Loading…"
                                    font.pixelSize: 9; color: Theme.muted1
                                    elide: Text.ElideRight; width: parent.width
                                }
                            }

                            Text {
                                text: root._expandedToggle === "language" ? "󰅃" : "󰅀"
                                font.pixelSize: 11; color: Theme.muted2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: langCard.hov = true
                            onExited:  langCard.hov = false
                            onClicked: {
                                var next = root._expandedToggle === "language" ? "" : "language"
                                root._expandedToggle = next
                                if (next === "language") {
                                    root._langSearch = ""
                                    root._langTab    = "keyboard"
                                    langLayoutProc.running     = true
                                    langCurrentProc.running    = true
                                    langLocaleProc.running     = true
                                    langLocaleListProc.running = true
                                }
                            }
                        }
                    }
                }

                 // ── WiFi detail panel ─────────────────────────────────────
                 Rectangle {
                     width: parent.width
                     height: root._expandedToggle === "wifi" ? wifiDetailCol.implicitHeight + 16 : 0
                     radius: 10; color: Theme.surface2; clip: true
                     Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                     Column {
                         id: wifiDetailCol
                         anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                         spacing: 6

                         // ── Header: toggle radio + rescan ──────────────────────
                         Item {
                             width: parent.width; height: 32

                             Row {
                                 anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                 spacing: 8

                                 Text {
                                     text: root._wifiRadioOn ? "󰤨" : "󰤮"
                                     font.pixelSize: 16
                                     color: root._wifiRadioOn ? Theme.accent : Theme.muted2
                                     anchors.verticalCenter: parent.verticalCenter
                                 }
                                 Column {
                                     anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                     Text {
                                         text: "WiFi"
                                         font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                     }
                                     Text {
                                         text: root._wifiConnectedSsid ? root._wifiConnectedSsid
                                               : (root._wifiRadioOn ? "Desconectado" : "Radio apagada")
                                         font.pixelSize: 9; color: Theme.muted1
                                     }
                                 }
                             }

                             Row {
                                 anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                 spacing: 8

                                 // Rescan button
                                 Rectangle {
                                     visible: root._wifiRadioOn
                                     width: 26; height: 26; radius: 7
                                     color: wRescanBtnMA.containsMouse ? Theme.surface3 : Theme.surface2
                                     Behavior on color { ColorAnimation { duration: 100 } }
                                     Text {
                                         anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 13
                                         color: root._wifiScanning ? Theme.accent : Theme.muted1
                                         RotationAnimation on rotation {
                                             running: root._wifiScanning
                                             loops: Animation.Infinite
                                             from: 0; to: 360; duration: 1200
                                         }
                                     }
                                     MouseArea {
                                         id: wRescanBtnMA; anchors.fill: parent; hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: root.wifiRescan()
                                     }
                                 }

                                 // Toggle radio
                                 Rectangle {
                                     width: 40; height: 22; radius: 11
                                     color: root._wifiRadioOn ? Theme.accent : Theme.surface3
                                     Behavior on color { ColorAnimation { duration: 200 } }
                                     Rectangle {
                                         width: 16; height: 16; radius: 8
                                         anchors.verticalCenter: parent.verticalCenter
                                         x: root._wifiRadioOn ? parent.width - width - 3 : 3
                                         color: "white"
                                         Behavior on x { NumberAnimation { duration: 200 } }
                                     }
                                     MouseArea {
                                         anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                         onClicked: root.wifiToggleRadio()
                                     }
                                 }
                             }
                         }

                         // ── Status / Working ───────────────────────────────────
                         Text {
                             visible: root._wifiStatusMsg !== ""
                             text: root._wifiStatusMsg
                             font.pixelSize: 10
                             color: root._wifiStatusMsg.startsWith("✓") ? Theme.success : Theme.error
                         }
                         Text {
                             visible: root._wifiWorking
                             text: "Cargando…"
                             font.pixelSize: 10; color: Theme.muted1
                         }

                         // ── Ethernet info (if connected) ───────────────────────
                         Rectangle {
                             visible: root._ethConnected
                             width: parent.width; height: root._ethConnected ? 48 : 0
                             radius: 8; color: Theme.successSurface
                             border.color: Qt.tint(Theme.surface2, Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.30))
                             Behavior on height { NumberAnimation { duration: 150 } }

                             Row {
                                 anchors { fill: parent; margins: 10 }
                                 spacing: 10
                                 Text { text: "󰈀"; font.pixelSize: 16; color: Theme.success; anchors.verticalCenter: parent.verticalCenter }
                                 Column {
                                     spacing: 1; anchors.verticalCenter: parent.verticalCenter
                                     Text { text: "Ethernet"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                     Text { text: root._ethIp || "Sin IP"; font.pixelSize: 9; color: Theme.muted1 }
                                 }
                                 Item { width: 1 }
                                 Text {
                                     visible: root._ethSpeed !== ""
                                     text: root._ethSpeed; font.pixelSize: 9; color: Theme.muted1
                                     anchors.verticalCenter: parent.verticalCenter
                                 }
                             }
                         }

                         // ── No radio message ───────────────────────────────────
                         Item {
                             visible: !root._wifiRadioOn && !root._wifiWorking
                             width: parent.width; height: 40
                             Text {
                                 anchors.centerIn: parent
                                 text: "WiFi está apagado"
                                 font.pixelSize: 11; color: Theme.muted1
                             }
                         }

                         // ── Network list ───────────────────────────────────────
                         Column {
                             visible: root._wifiRadioOn
                             width: parent.width
                             spacing: 4

                             Repeater {
                                 model: root._wifiNetworks

                                 Column {
                                     id: wNetRow
                                     required property var modelData
                                     required property int index
                                     width: parent.width
                                     spacing: 0

                                     property bool isSaved:    root._wifiSavedSsids[modelData.ssid] || false
                                     property bool isActive:   root._wifiConnectedSsid === modelData.ssid
                                     property bool showPwText:    false
                                     property string realPassword: ""
                                     property bool fetchingPw:    false

                                     onIsSavedChanged: { showPwText = false; realPassword = "" }

                                     function fetchSavedPassword() {
                                         if (realPassword !== "" || fetchingPw) {
                                             showPwText = !showPwText
                                             return
                                         }
                                         fetchingPw = true
                                         root.wifiFetchPasswordFor(modelData.ssid, index)
                                     }

                                     Connections {
                                         target: root
                                         function onWifiPwFetchResultIdxChanged() {
                                             if (root._wifiPwFetchResultIdx !== index) return
                                             var pw = root._wifiPwFetchResult
                                             wNetRow.realPassword = pw
                                             wNetRow.fetchingPw   = false
                                             if (pw !== "") wNetRow.showPwText = true
                                         }
                                     }

                                     // Network row
                                     Rectangle {
                                         width: parent.width; height: 36; radius: 8
                                         color: {
                                             if (wNetRow.isActive)                    return Theme.accentSurface
                                             if (root._wifiSelectedIdx === index)     return Theme.surface3
                                             return wRowMA.containsMouse ? Theme.surface3 : Theme.surface2
                                         }
                                         Behavior on color { ColorAnimation { duration: 100 } }

                                         Rectangle {
                                             visible: wNetRow.isActive
                                             width: 3; height: 18; radius: 2
                                             anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                                             color: Theme.accent
                                         }

                                         RowLayout {
                                             anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                                             spacing: 6

                                             Text {
                                                 text: root.wifiSignalIcon(modelData.signal)
                                                 font.pixelSize: 13
                                                 color: wNetRow.isActive ? Theme.accent : Theme.muted2
                                             }

                                             Text {
                                                 Layout.fillWidth: true
                                                 text: modelData.ssid
                                                 font.pixelSize: 11; color: Theme.text
                                                 elide: Text.ElideRight
                                             }

                                             Text {
                                                 visible: modelData.security && modelData.security !== "--"
                                                 text: "󰌆"; font.pixelSize: 10; color: Theme.muted2
                                             }

                                             Text {
                                                 text: modelData.signal + "%"
                                                 font.pixelSize: 9; color: Theme.muted2; width: 28
                                                 horizontalAlignment: Text.AlignRight
                                             }

                                             // Connect / Disconnect button
                                             Rectangle {
                                                 height: 22; radius: 6
                                                 width: wNetRow.isActive ? 78 : 64
                                                 color: wNetRow.isActive ? Theme.error
                                                      : (root._wifiSelectedIdx === index ? Theme.accent : Theme.surface3)
                                                 Behavior on color { ColorAnimation { duration: 100 } }
                                                 Text {
                                                     anchors.centerIn: parent
                                                     text: wNetRow.isActive ? "Desconectar" : "Conectar"
                                                     font.pixelSize: 9; color: "white"
                                                 }
                                                 MouseArea {
                                                     anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                     onClicked: {
                                                         if (wNetRow.isActive) {
                                                             root.wifiDisconnect()
                                                         } else {
                                                             var needsPw = modelData.security && modelData.security !== "--"
                                                             if (root._wifiSelectedIdx !== index) {
                                                                 root._wifiSelectedIdx = index
                                                                 root._wifiPasswordByIndex[index] = ""
                                                                 wNetRow.showPwText = false
                                                             } else {
                                                                 var pw = root._wifiPasswordByIndex[index] || ""
                                                                 if (needsPw && pw === "") {
                                                                     if (wNetRow.isSaved) {
                                                                         root._wifiWorking = true
                                                                         wSavedPwProc.ssid = modelData.ssid
                                                                         wSavedPwProc.idx  = index
                                                                         wSavedPwProc.command = ["bash", "-c",
                                                                             "nmcli -s -g 802-11-wireless-security.psk connection show " + JSON.stringify(modelData.ssid) + " 2>/dev/null"]
                                                                         wSavedPwProc.running = true
                                                                     } else {
                                                                         root._wifiStatusMsg = "✗ Ingresa una contraseña"
                                                                     }
                                                                 } else {
                                                                     root.wifiConnectTo(modelData.ssid, pw)
                                                                 }
                                                             }
                                                         }
                                                     }
                                                 }
                                             }
                                         }

                                         MouseArea {
                                             id: wRowMA
                                             anchors.fill: parent; hoverEnabled: true; z: -1
                                             cursorShape: Qt.PointingHandCursor
                                             onClicked: {
                                                 if (root._wifiSelectedIdx === index) {
                                                     root._wifiSelectedIdx = -1
                                                 } else {
                                                     root._wifiSelectedIdx = index
                                                     root._wifiPasswordByIndex[index] = ""
                                                     wNetRow.showPwText = false
                                                 }
                                             }
                                         }
                                     }

                                     // ── Expanded panel per network ─────────────────
                                     Rectangle {
                                         visible: root._wifiSelectedIdx === index
                                         width: parent.width
                                         height: visible ? wExpandCol.implicitHeight + 20 : 0
                                         radius: 8; color: Theme.surface3; clip: true
                                         Behavior on height { NumberAnimation { duration: 150 } }

                                         Rectangle {
                                             anchors.fill: parent; radius: parent.radius; color: "transparent"
                                             border.color: Theme.accentSurface; border.width: 1
                                         }

                                         Column {
                                             id: wExpandCol
                                             anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                                             spacing: 6

                                             // ── Password field ─────────────────────────
                                             RowLayout {
                                                 visible: (modelData.security && modelData.security !== "--") && !wNetRow.isActive
                                                 width: parent.width; spacing: 6

                                                 Text { text: "󰌋"; font.pixelSize: 12; color: Theme.muted1; Layout.alignment: Qt.AlignVCenter }

                                                 Item {
                                                     Layout.fillWidth: true; height: 22

                                                     Text {
                                                         anchors.verticalCenter: parent.verticalCenter
                                                         visible: wNetRow.isSaved && !wNetRow.showPwText
                                                         text: "••••••••"; font.pixelSize: 12; color: Theme.muted1
                                                     }
                                                     Text {
                                                         anchors.verticalCenter: parent.verticalCenter
                                                         visible: wNetRow.isSaved && wNetRow.showPwText
                                                         text: wNetRow.realPassword !== "" ? wNetRow.realPassword : "—"
                                                         font.pixelSize: 11; color: Theme.text; font.family: "monospace"
                                                     }
                                                     TextInput {
                                                         id: wPwInput
                                                         anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                         visible: !wNetRow.isSaved
                                                         text: root._wifiPasswordByIndex[index] || ""
                                                         onTextChanged: root._wifiPasswordByIndex[index] = text
                                                         echoMode: wNetRow.showPwText ? TextInput.Normal : TextInput.Password
                                                         color: Theme.text; font.pixelSize: 11
                                                         verticalAlignment: TextInput.AlignVCenter
                                                         Keys.onReturnPressed: {
                                                             var pw = root._wifiPasswordByIndex[index] || ""
                                                             if (!wNetRow.isSaved && pw === "") {
                                                                 root._wifiStatusMsg = "✗ Ingresa una contraseña"
                                                             } else {
                                                                 root.wifiConnectTo(modelData.ssid, pw)
                                                             }
                                                         }
                                                     }
                                                     Text {
                                                         anchors.verticalCenter: parent.verticalCenter
                                                         visible: !wNetRow.isSaved && wPwInput.text.length === 0
                                                         text: "Contraseña"; font.pixelSize: 11; color: Theme.muted2
                                                     }
                                                 }

                                                 // Eye toggle
                                                 Rectangle {
                                                     width: 24; height: 24; radius: 6
                                                     color: wEyeMA.containsMouse ? Theme.surface2 : "transparent"
                                                     Behavior on color { ColorAnimation { duration: 100 } }
                                                     Text {
                                                         anchors.centerIn: parent
                                                         text: wNetRow.showPwText ? "󰈊" : "󰈉"
                                                         font.pixelSize: 13
                                                         color: wNetRow.showPwText ? Theme.accent : Theme.muted2
                                                     }
                                                     MouseArea {
                                                         id: wEyeMA; anchors.fill: parent; hoverEnabled: true
                                                         cursorShape: Qt.PointingHandCursor
                                                         onClicked: wNetRow.fetchSavedPassword()
                                                     }
                                                 }

                                                 // Copy password (saved only)
                                                 Rectangle {
                                                     visible: wNetRow.isSaved
                                                     width: 24; height: 24; radius: 6
                                                     color: wCopyPwMA.containsMouse ? Theme.surface2 : "transparent"
                                                     Behavior on color { ColorAnimation { duration: 100 } }
                                                     Text { anchors.centerIn: parent; text: "󰂏"; font.pixelSize: 12; color: Theme.muted1 }
                                                     MouseArea {
                                                         id: wCopyPwMA; anchors.fill: parent; hoverEnabled: true
                                                         cursorShape: Qt.PointingHandCursor
                                                         onClicked: {
                                                             root._wifiMenuSsid = modelData.ssid
                                                             root.wifiMenuCopyPassword()
                                                         }
                                                     }
                                                 }
                                             }

                                             Rectangle {
                                                 visible: (modelData.security && modelData.security !== "--") && !wNetRow.isActive
                                                 width: parent.width; height: 1; color: Theme.surface2
                                             }

                                             // ── Info ───────────────────────────────────
                                             Column {
                                                 width: parent.width; spacing: 3

                                                 Row {
                                                     spacing: 4
                                                     Text { text: "Señal:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                                     Text { text: modelData.signal + "%"; font.pixelSize: 10; color: Theme.text }
                                                 }
                                                 Row {
                                                     spacing: 4
                                                     Text { text: "Seguridad:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                                     Text {
                                                         text: (modelData.security && modelData.security !== "--") ? modelData.security : "Abierta"
                                                         font.pixelSize: 10; color: Theme.text
                                                     }
                                                 }
                                                 Row {
                                                     spacing: 4
                                                     Text { text: "Estado:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                                     Text {
                                                         text: wNetRow.isActive ? "Conectada" : (wNetRow.isSaved ? "Guardada" : "No guardada")
                                                         font.pixelSize: 10; color: Theme.text
                                                     }
                                                 }
                                                 Row {
                                                     visible: wNetRow.isActive
                                                     spacing: 4
                                                     Text { text: "IP:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                                     Text {
                                                         text: root._wifiIp !== "" ? root._wifiIp : "—"
                                                         font.pixelSize: 10; color: Theme.text
                                                         elide: Text.ElideRight; width: wExpandCol.width - 76
                                                     }
                                                 }
                                                 Row {
                                                     visible: wNetRow.isActive
                                                     spacing: 4
                                                     Text { text: "Gateway:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                                     Text { text: root._wifiGateway !== "" ? root._wifiGateway : "—"; font.pixelSize: 10; color: Theme.text }
                                                 }
                                                 Row {
                                                     visible: wNetRow.isActive
                                                     spacing: 4
                                                     Text { text: "DNS:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                                     Text { text: root._wifiDns !== "" ? root._wifiDns : "—"; font.pixelSize: 10; color: Theme.text }
                                                 }
                                             }

                                             // ── Forget button ──────────────────────────
                                             Row {
                                                 visible: wNetRow.isSaved
                                                 width: parent.width

                                                 Rectangle {
                                                     height: 24; radius: 6
                                                     width: wForgetText.implicitWidth + 18
                                                     color: wForgetMA.containsMouse
                                                         ? Qt.tint(Theme.surface2, Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18))
                                                         : Theme.surface2
                                                     Behavior on color { ColorAnimation { duration: 100 } }
                                                     Text {
                                                         id: wForgetText
                                                         anchors.centerIn: parent
                                                         text: "󱑃  Olvidar red"; font.pixelSize: 10; color: Theme.error
                                                     }
                                                     MouseArea {
                                                         id: wForgetMA; anchors.fill: parent; hoverEnabled: true
                                                         cursorShape: Qt.PointingHandCursor
                                                         onClicked: {
                                                             root._wifiMenuSsid = modelData.ssid
                                                             root.wifiMenuForgetNetwork()
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

                 // ── Bluetooth detail panel ────────────────────────────────
                 Rectangle {
                     width: parent.width
                     height: root._expandedToggle === "bluetooth" ? btDetailCol.implicitHeight + 16 : 0
                     radius: 10; color: Theme.surface2; clip: true
                     Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                     Column {
                         id: btDetailCol
                         anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                         spacing: 8

                         // ── Header ─────────────────────────────────────────────
                         Item {
                             width: parent.width; height: 32

                             Row {
                                 anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                 spacing: 8
                                 Text {
                                     text: "󰂯"; font.pixelSize: 16
                                     color: root._btPwrd ? Theme.accent : Theme.muted2
                                     anchors.verticalCenter: parent.verticalCenter
                                 }
                                 Column {
                                     anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                     Text { text: "Bluetooth"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                     Text {
                                         text: !root._btAvailable ? "Sin adaptador"
                                             : !root._btPwrd      ? "Apagado"
                                             : root._btScanning   ? "Buscando..."
                                             : "Encendido"
                                         font.pixelSize: 9; color: Theme.muted1
                                     }
                                 }
                             }

                             Row {
                                 anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                 spacing: 8

                                 // Scan button
                                 Rectangle {
                                     visible: root._btAvailable && root._btPwrd
                                     width: 26; height: 26; radius: 7
                                     color: btScanBtnMA.containsMouse
                                         ? Theme.surface3
                                         : (root._btScanning ? Theme.accentSurface : Theme.surface2)
                                     Behavior on color { ColorAnimation { duration: 100 } }
                                     Text {
                                         anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 13
                                         color: root._btScanning ? Theme.accent : Theme.muted1
                                         RotationAnimation on rotation {
                                             running: root._btScanning; loops: Animation.Infinite
                                             from: 0; to: 360; duration: 1200
                                         }
                                     }
                                     MouseArea {
                                         id: btScanBtnMA; anchors.fill: parent; hoverEnabled: true
                                         cursorShape: Qt.PointingHandCursor
                                         onClicked: root.btToggleScan()
                                     }
                                 }

                                 // Power toggle
                                 Rectangle {
                                     visible: root._btAvailable
                                     width: 40; height: 22; radius: 11
                                     color: root._btPwrd ? Theme.accent : Theme.surface3
                                     Behavior on color { ColorAnimation { duration: 200 } }
                                     Rectangle {
                                         width: 16; height: 16; radius: 8; color: "white"
                                         anchors.verticalCenter: parent.verticalCenter
                                         x: root._btPwrd ? parent.width - width - 3 : 3
                                         Behavior on x { NumberAnimation { duration: 200 } }
                                     }
                                     MouseArea {
                                         anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                         onClicked: root.btTogglePower()
                                     }
                                 }
                             }
                         }

                         // ── Status message ─────────────────────────────────────
                         Text {
                             visible: root._btStatusMsg !== ""
                             text: root._btStatusMsg; font.pixelSize: 10
                             color: root._btStatusMsg.startsWith("✓") ? Theme.success : Theme.error
                         }

                         // ── No adapter ─────────────────────────────────────────
                         Item {
                             visible: !root._btAvailable
                             width: parent.width; height: 40
                             Text {
                                 anchors.centerIn: parent
                                 text: "No se encontró adaptador Bluetooth"
                                 font.pixelSize: 11; color: Theme.muted1
                             }
                         }

                         // ── Off message ────────────────────────────────────────
                         Item {
                             visible: root._btAvailable && !root._btPwrd
                             width: parent.width; height: 36
                             Text {
                                 anchors.centerIn: parent
                                 text: "Enciende el Bluetooth para ver dispositivos"
                                 font.pixelSize: 10; color: Theme.muted1
                             }
                         }

                         // ── Device lists ───────────────────────────────────────
                         Column {
                             visible: root._btAvailable && root._btPwrd
                             width: parent.width; spacing: 4

                             // Paired label
                             Text {
                                 visible: root._btPairedCount > 0
                                 text: "Dispositivos emparejados"
                                 font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
                             }

                             Repeater {
                                 model: root._btPairedList

                                 Column {
                                     id: btPairedEntry
                                     required property var modelData
                                     required property int index
                                     width: parent.width; spacing: 4

                                     property string devMac:   modelData.address.toUpperCase()
                                     property var    cInfo:    root._btCodecData[devMac] ?? null
                                     property bool   hasCodec: modelData.connected
                                                               && cInfo !== null
                                                               && (cInfo.profiles?.length ?? 0) > 0
                                     property bool   pendingForget: false

                                     Timer {
                                         id: btForgetCancelTimer
                                         interval: 3000
                                         onTriggered: btPairedEntry.pendingForget = false
                                     }

                                     Rectangle {
                                         width: parent.width; height: 38; radius: 8
                                         color: btPairedEntry.modelData.connected
                                             ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                             : Theme.surface3

                                         Rectangle {
                                             visible: btPairedEntry.modelData.connected
                                             width: 3; height: 18; radius: 2
                                             anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                                             color: Theme.accent
                                         }

                                         RowLayout {
                                             anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                                             spacing: 6

                                             Text {
                                                 text: "󰂱"; font.pixelSize: 14
                                                 color: btPairedEntry.modelData.connected ? Theme.accent : Theme.muted2
                                             }

                                             Column {
                                                 Layout.fillWidth: true; spacing: 1
                                                 Text {
                                                     text: btPairedEntry.modelData.name || btPairedEntry.modelData.deviceName
                                                     font.pixelSize: 11; color: Theme.text
                                                     elide: Text.ElideRight; width: parent.width
                                                 }
                                                 Text {
                                                     text: btPairedEntry.modelData.address
                                                     font.pixelSize: 8; color: Theme.muted2
                                                 }
                                             }

                                             Rectangle {
                                                 height: 24; radius: 6
                                                 width: btConnBtnText.implicitWidth + 16
                                                 color: btPairedEntry.modelData.connected ? Theme.error : Theme.accent
                                                 Behavior on color { ColorAnimation { duration: 150 } }
                                                 Text {
                                                     id: btConnBtnText; anchors.centerIn: parent
                                                     text: btPairedEntry.modelData.connected ? "Desconectar" : "Conectar"
                                                     font.pixelSize: 9; color: "white"
                                                 }
                                                 MouseArea {
                                                     anchors.fill: parent
                                                     enabled: !root._btWorking
                                                     cursorShape: root._btWorking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                     onClicked: {
                                                         if (btPairedEntry.modelData.connected)
                                                             root.btDisconnectDevice(btPairedEntry.modelData)
                                                         else
                                                             root.btConnectDevice(btPairedEntry.modelData)
                                                     }
                                                 }
                                             }

                                             // Forget button (2-step confirm)
                                             Rectangle {
                                                 id: btForgetBtn
                                                 height: 24; radius: 6
                                                 width: btPairedEntry.pendingForget
                                                     ? btForgetConfirmText.implicitWidth + 14
                                                     : 24
                                                 Behavior on width { NumberAnimation { duration: 120 } }
                                                 color: btPairedEntry.pendingForget
                                                     ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                                     : (btForgetMA.containsMouse
                                                         ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14)
                                                         : "transparent")
                                                 Behavior on color { ColorAnimation { duration: 120 } }

                                                 Text {
                                                     anchors.centerIn: parent
                                                     visible: !btPairedEntry.pendingForget
                                                     text: "󰩹"; font.pixelSize: 13
                                                     color: btForgetMA.containsMouse ? Theme.error : Theme.muted2
                                                     Behavior on color { ColorAnimation { duration: 100 } }
                                                 }
                                                 Text {
                                                     id: btForgetConfirmText; anchors.centerIn: parent
                                                     visible: btPairedEntry.pendingForget
                                                     text: "¿Borrar?"; font.pixelSize: 9; color: Theme.error
                                                 }
                                                 MouseArea {
                                                     id: btForgetMA; anchors.fill: parent; hoverEnabled: true
                                                     cursorShape: Qt.PointingHandCursor
                                                     onClicked: {
                                                         if (!btPairedEntry.pendingForget) {
                                                             btPairedEntry.pendingForget = true
                                                             btForgetCancelTimer.restart()
                                                         } else {
                                                             btForgetCancelTimer.stop()
                                                             btPairedEntry.pendingForget = false
                                                             root.btForgetDevice(btPairedEntry.modelData)
                                                         }
                                                     }
                                                 }
                                             }
                                         }
                                     }

                                     // ── Codec panel ────────────────────────────────
                                     Rectangle {
                                         visible: btPairedEntry.hasCodec
                                         width: parent.width; height: 34; radius: 7
                                         color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)

                                         RowLayout {
                                             anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                                             spacing: 6

                                             Column {
                                                 spacing: 1
                                                 Text {
                                                     text: "Codec: " + (btPairedEntry.cInfo?.codec ?? "")
                                                     font.pixelSize: 9; font.weight: Font.DemiBold; color: Theme.accent
                                                 }
                                                 Text {
                                                     text: btPairedEntry.cInfo?.bitrate ?? ""
                                                     font.pixelSize: 8; color: Theme.muted1
                                                     visible: (btPairedEntry.cInfo?.bitrate ?? "") !== ""
                                                 }
                                             }

                                             Item { Layout.fillWidth: true }

                                             Repeater {
                                                 model: btPairedEntry.cInfo?.profiles ?? []
                                                 delegate: Rectangle {
                                                     id: btProfileBtn
                                                     required property var modelData
                                                     property bool isActive: (btPairedEntry.cInfo?.active ?? "") === modelData.id
                                                     height: 20; radius: 5
                                                     width: btProfileLabel.implicitWidth + 10
                                                     color: isActive ? Theme.accent
                                                          : (btProfileMA.containsMouse ? Theme.surface3 : Theme.surface2)
                                                     Behavior on color { ColorAnimation { duration: 100 } }
                                                     Text {
                                                         id: btProfileLabel; anchors.centerIn: parent
                                                         text: btProfileBtn.modelData.label
                                                         font.pixelSize: 8
                                                         color: btProfileBtn.isActive ? "white" : Theme.muted1
                                                     }
                                                     MouseArea {
                                                         id: btProfileMA; anchors.fill: parent; hoverEnabled: true
                                                         cursorShape: Qt.PointingHandCursor
                                                         onClicked: root.btSetCodec(
                                                             btPairedEntry.modelData.address,
                                                             btProfileBtn.modelData.id
                                                         )
                                                     }
                                                 }
                                             }
                                         }
                                     }
                                 }
                             }

                             Text {
                                 visible: root._btPairedCount === 0 && !root._btWorking
                                 text: "No hay dispositivos emparejados"
                                 font.pixelSize: 10; color: Theme.muted1
                             }

                             // Nearby section
                             Item { visible: root._btNearbyCount > 0; width: parent.width; height: 8 }

                             Text {
                                 visible: root._btNearbyCount > 0
                                 text: "Dispositivos cercanos"
                                 font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
                             }

                             Repeater {
                                 model: root._btNearbyList

                                 Rectangle {
                                     required property var modelData
                                     width: parent.width; height: 38; radius: 8; color: Theme.surface3

                                     RowLayout {
                                         anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                                         spacing: 6

                                         Text { text: "󰂯"; font.pixelSize: 14; color: Theme.muted2 }

                                         Column {
                                             Layout.fillWidth: true; spacing: 1
                                             Text {
                                                 text: modelData.name || modelData.deviceName
                                                 font.pixelSize: 11; color: Theme.text
                                                 elide: Text.ElideRight; width: parent.width
                                             }
                                             Text { text: modelData.address; font.pixelSize: 8; color: Theme.muted2 }
                                         }

                                         Rectangle {
                                             height: 24; radius: 6; width: btPairBtnLabel.implicitWidth + 16
                                             color: Theme.surface2
                                             Text {
                                                 id: btPairBtnLabel; anchors.centerIn: parent
                                                 text: "Emparejar"; font.pixelSize: 9; color: Theme.text
                                             }
                                             MouseArea {
                                                 anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                 onClicked: root.btPairDevice(modelData)
                                             }
                                         }
                                     }
                                 }
                             }
                         }
                     }
                 }

                 // ── Power & Fans detail panel ─────────────────────────────
                 Rectangle {
                     width: parent.width
                      height: root._expandedToggle === "power" ? powerDetailCol.implicitHeight + 16 : 0
                      radius: 10; color: Theme.surface2; clip: true
                      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        id: powerDetailCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 10

                        // ── CPU power profiles ─────────────────────────────
                        Text {
                            text: "CPU Power Profile"
                            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.powerProfiles

                                Rectangle {
                                    id: pBtn
                                    required property var modelData
                                    property bool active: root.powerProfile === modelData.id

                                    width: (powerDetailCol.width - 6 * Math.max(1, root.powerProfiles.length - 1)) / Math.max(1, root.powerProfiles.length)
                                    height: 36; radius: 8
                                    color: active
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                        : (pBtnHov.containsMouse ? Theme.surface3 : Theme.surface2)
                                    border.color: active ? Theme.accent : "transparent"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: root._powerIcon(pBtn.modelData.id)
                                            font.pixelSize: 13
                                            color: pBtn.active ? Theme.accent : Theme.muted1
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: pBtn.modelData.label
                                            font.pixelSize: 8
                                            color: pBtn.active ? Theme.accent : Theme.muted2
                                        }
                                    }

                                    MouseArea {
                                        id: pBtnHov; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setPower(pBtn.modelData.id)
                                    }
                                }
                            }
                        }

                        // ── Fan profiles ───────────────────────────────────
                        Rectangle { width: parent.width; height: 1; color: Theme.surface3; visible: SysData.fanAvailable }

                        Text {
                            visible: SysData.fanAvailable
                            text: "Fan Profile"
                            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
                        }

                        // Fan RPM bars
                        Column {
                            visible: SysData.fanAvailable && SysData.fan1Rpm > 0
                            width: parent.width; spacing: 4

                            Repeater {
                                model: [
                                    { label: "F1", rpm: SysData.fan1Rpm, pct: SysData.fan1Percent, color: Theme.accent },
                                    { label: "F2", rpm: SysData.fan2Rpm, pct: SysData.fan2Percent, color: Theme.accent2 }
                                ]

                                Row {
                                    required property var modelData
                                    spacing: 6
                                    Text {
                                        text: modelData.label; font.pixelSize: 9; color: Theme.muted1
                                        width: 16; anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Item {
                                        width: powerDetailCol.width - 80; height: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                        Rectangle {
                                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                            width: Math.max(4, modelData.pct / 100 * parent.width)
                                            radius: 3; color: modelData.color
                                            Behavior on width { NumberAnimation { duration: 300 } }
                                        }
                                    }
                                    Text {
                                        text: modelData.rpm + " rpm"; font.pixelSize: 9; color: Theme.muted2
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Fan profile buttons — dynamic from fan-control.sh
                        Flow {
                            visible: SysData.fanAvailable && root._fanProfiles.length > 0
                            width: parent.width; spacing: 6

                            Repeater {
                                model: root._fanProfiles

                                Rectangle {
                                    id: fBtn
                                    required property var modelData
                                    property bool active: SysData.fanProfile === modelData.id

                                    width: (powerDetailCol.width - 6 * Math.max(1, root._fanProfiles.length - 1)) / Math.max(1, root._fanProfiles.length)
                                    height: 36; radius: 8
                                    color: fBtn.active
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                        : (fBtnHov.containsMouse ? Theme.surface3 : Theme.surface2)
                                    border.color: fBtn.active ? Theme.accent : "transparent"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: fBtn.modelData.icon
                                            font.pixelSize: 13; color: fBtn.active ? Theme.accent : Theme.muted1
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: fBtn.modelData.label
                                            font.pixelSize: 8
                                            color: fBtn.active ? Theme.accent : Theme.muted2
                                        }
                                    }

                                    MouseArea {
                                        id: fBtnHov; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!fanApplyProc.running) {
                                                fanApplyProc.command = ["sudo", Paths.scripts + "/fan-control.sh", "set_profile", fBtn.modelData.id]
                                                fanApplyProc.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Temps row
                        Row {
                            visible: SysData.fanAvailable
                            spacing: 8

                            Repeater {
                                model: [
                                    { label: "CPU", temp: SysData.fanCpuTemp },
                                    { label: "GPU", temp: SysData.fanGpuTemp }
                                ]
                                Row {
                                    required property var modelData
                                    spacing: 4
                                    Text { text: modelData.label + ":"; font.pixelSize: 9; color: Theme.muted2 }
                                    Text {
                                        text: modelData.temp + " °C"; font.pixelSize: 9
                                        color: modelData.temp >= 85 ? "#ff7b72"
                                             : modelData.temp >= 70 ? "#e3b341"
                                             : Theme.muted1
                                    }
                                }
                            }
                        }
                    }
                }

                 // ── Battery detail panel ───────────────────────────────────
                 Rectangle {
                     width: parent.width
                      height: root._expandedToggle === "battery" ? batDetailCol.implicitHeight + 16 : 0
                      radius: 10; color: Theme.surface2; clip: true
                      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        id: batDetailCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6

                        // Charge bar
                        Item {
                            width: parent.width; height: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(4, SysData.batPercent / 100 * parent.width)
                                radius: 3
                                color: SysData.batCharging ? Theme.success
                                     : SysData.batPercent > 50 ? Theme.accent
                                     : SysData.batPercent > 20 ? Theme.yellow
                                     : Theme.error
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }

                        Row {
                            spacing: 16
                            Text { text: SysData.batPercent + "%"; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text }
                            Text {
                                text: SysData.batCharging ? "Charging" : SysData.batStatus
                                font.pixelSize: 11; color: Theme.muted1
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Health / capacity / cycles — cards
                        Row {
                            width: parent.width
                            spacing: 6
                            visible: root._batHealth > 0 || root._batCapWh > 0 || root._batCycles > 0

                            Repeater {
                                model: [
                                    {
                                        value: root._batHealth > 0 ? root._batHealth.toFixed(1) + "%" : "—",
                                        label: "Health",
                                        color: root._batHealth >= 80 ? Theme.accent
                                             : root._batHealth >= 60 ? Theme.yellow
                                             : root._batHealth > 0 ? Theme.error : Theme.muted2
                                    },
                                    {
                                        value: root._batCapWh > 0 ? root._batCapWh.toFixed(1) + " Wh" : "—",
                                        label: "Capacity",
                                        color: Theme.text
                                    },
                                    {
                                        value: root._batCycles > 0 ? String(root._batCycles) : "—",
                                        label: "Cycles",
                                        color: Theme.muted1
                                    }
                                ]

                                Rectangle {
                                    required property var modelData
                                    width: (parent.width - 12) / 3
                                    height: 48; radius: 8; color: Theme.surface3

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.value
                                            font.pixelSize: 12; font.weight: Font.DemiBold
                                            color: modelData.color
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.label
                                            font.pixelSize: 9; color: Theme.muted2
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                 // ── Language detail panel ──────────────────────────────────
                 Rectangle {
                     width: parent.width
                      height: root._expandedToggle === "language" ? langDetailCol.implicitHeight + 16 : 0
                      radius: 10; color: Theme.surface2; clip: true
                      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        id: langDetailCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 8

                        // ── Mini tabs ──────────────────────────────────────────
                        Row {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: [
                                    { id: "keyboard", icon: "󰌌", label: "Keyboard" },
                                    { id: "locale",   icon: "󰗊", label: "Locale"   }
                                ]
                                Rectangle {
                                    required property var modelData
                                    height: 24
                                    width: langTabInner.implicitWidth + 16
                                    radius: 6
                                    color: root._langTab === modelData.id ? Theme.accentSurface : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Row {
                                        id: langTabInner
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: modelData.icon; font.pixelSize: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root._langTab === modelData.id ? Theme.accent : Theme.muted3
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }
                                        Text {
                                            text: modelData.label; font.pixelSize: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root._langTab === modelData.id ? Theme.accent : Theme.muted3
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root._langTab    = modelData.id
                                            root._langSearch = ""
                                            langSearchInput.text = ""
                                        }
                                    }
                                }
                            }
                        }

                        // ── Search ─────────────────────────────────────────────
                        Rectangle {
                            width: parent.width; height: 28; radius: 7
                            color: Theme.surface3

                            Row {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍉"; font.pixelSize: 11; color: Theme.muted2
                                }
                                TextInput {
                                    id: langSearchInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 26
                                    font.pixelSize: 10; color: Theme.text
                                    selectionColor: Theme.accent; selectedTextColor: Theme.text
                                    clip: true
                                    onTextChanged: root._langSearch = text
                                    Text {
                                        anchors.fill: parent
                                        text: root._langTab === "keyboard" ? "Search layout…" : "Search locale…"
                                        font.pixelSize: 10; color: Theme.muted2
                                        visible: !parent.text && !parent.activeFocus
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        // ── Keyboard tab: layout list ──────────────────────────
                        Item {
                            visible: root._langTab === "keyboard"
                            width: parent.width
                            height: visible ? Math.min(root._filteredLayouts.length, 5) * 32 + 4 : 0
                            clip: true

                            ListView {
                                anchors.fill: parent
                                model: root._filteredLayouts
                                spacing: 2
                                clip: true

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.surface3 }
                                }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width; height: 30; radius: 7
                                    property bool isActive: {
                                        var layout = (root._langLayout || "").toLowerCase()
                                        var code   = (modelData.code   || "").toLowerCase()
                                        return layout.indexOf(code) >= 0 || code.indexOf(layout) >= 0
                                    }
                                    color: langItemHov.containsMouse
                                        ? Theme.surface3
                                        : (isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 80 } }

                                    Rectangle {
                                        visible: isActive
                                        width: 3; height: 14; radius: 2
                                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                        color: Theme.accent
                                    }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: isActive ? 12 : 8; rightMargin: 8 }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.code
                                            font.pixelSize: 10; color: Theme.text
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            visible: isActive
                                            text: "󰄬"; font.pixelSize: 10; color: Theme.accent
                                        }
                                    }

                                    MouseArea {
                                        id: langItemHov
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var cmd = "hyprctl keyword input:kb_layout " + modelData.code +
                                                      " 2>/dev/null && sleep 0.4 && hyprctl dispatch switchxkblayout all 0"
                                            langSetProc.command = ["sh", "-c", cmd]
                                            if (!langSetProc.running) langSetProc.running = true
                                            root._langLayout = modelData.code
                                        }
                                    }
                                }
                            }
                        }

                        // ── Locale tab: locale list ────────────────────────────
                        Item {
                            visible: root._langTab === "locale"
                            width: parent.width
                            height: visible ? Math.min(root._filteredLocales.length, 5) * 32 + 4 : 0
                            clip: true

                            ListView {
                                anchors.fill: parent
                                model: root._filteredLocales
                                spacing: 2
                                clip: true

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.surface3 }
                                }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width; height: 30; radius: 7
                                    property bool isActive: {
                                        var locale = (root._langLocale  || "").toLowerCase()
                                        var value  = (modelData.value   || "").toLowerCase()
                                        return locale.indexOf(value) >= 0 || value.indexOf(locale) >= 0
                                    }
                                    color: localeItemHov.containsMouse
                                        ? Theme.surface3
                                        : (isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 80 } }

                                    Rectangle {
                                        visible: isActive
                                        width: 3; height: 14; radius: 2
                                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                        color: Theme.accent
                                    }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: isActive ? 12 : 8; rightMargin: 8 }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.value
                                            font.pixelSize: 10; color: Theme.text
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            visible: isActive
                                            text: "󰄬"; font.pixelSize: 10; color: Theme.accent
                                        }
                                    }

                                    MouseArea {
                                        id: localeItemHov
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            langSetLocaleProc.command = ["sh", "-c",
                                                "localectl set-locale LANG=" + modelData.value + " 2>/dev/null"]
                                            if (!langSetLocaleProc.running) langSetLocaleProc.running = true
                                            root._langLocale = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════
                 // ══════════════════════════════════════════════════════════
                 // SECCIÓN 3 — Métricas del sistema (expandibles inline)
                // ══════════════════════════════════════════════════════════
                Item { width: parent.width; height: 10 }
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
                Item { width: parent.width; height: 8 }

                Text {
                    text: "System"
                    font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.muted1
                }
                Item { width: parent.width; height: 6 }

                // ── Grid CPU / RAM / GPU ───────────────────────────────────
                Row {
                    id: metricsRow
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "cpu", label: "CPU", icon: "󰻠",
                              value: SysData.cpuPercent, temp: SysData.cpuTemp },
                            { key: "ram", label: "RAM", icon: "󰘚",
                              value: SysData.ramPercent, temp: -1 },
                            { key: "gpu", label: "GPU", icon: "󰟵",
                              value: SysData.gpuPercent >= 0 ? SysData.gpuPercent : 0,
                              temp: SysData.gpuTemp }
                        ]

                        Rectangle {
                            id: metCard
                            required property var modelData
                            required property int index
                            property bool hov: false
                            property bool expanded: root._expandedMetric === modelData.key

                            width: (metricsRow.width - 12) / 3
                            height: 70
                            radius: 12
                            color: expanded
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                : (hov ? Theme.surface3 : Theme.surface2)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                // ── Arc gauge: Canvas for arc + Text for icon ──────
                                Item {
                                    id: arcItem
                                    width: 42; height: 42
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    // Live value — updates the canvas
                                    property real arcPct: modelData.value / 100
                                    Behavior on arcPct { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    onArcPctChanged: arcCanvas.requestPaint()

                                    Canvas {
                                        id: arcCanvas
                                        anchors.fill: parent

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width / 2, cy = height / 2, r = 16

                                            // Track
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, -Math.PI * 0.75, Math.PI * 0.75)
                                            ctx.strokeStyle = Theme.surface3.toString()
                                            ctx.lineWidth = 3.5
                                            ctx.lineCap = "round"
                                            ctx.stroke()

                                            // Fill
                                            if (arcItem.arcPct > 0) {
                                                var end = -Math.PI * 0.75 + Math.PI * 1.5 * Math.min(arcItem.arcPct, 1)
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r, -Math.PI * 0.75, end)
                                                ctx.strokeStyle = arcItem.arcPct > 0.85 ? "#ff7b72"
                                                                : arcItem.arcPct > 0.65 ? "#e3b341"
                                                                : Theme.accent.toString()
                                                ctx.lineWidth = 3.5
                                                ctx.lineCap = "round"
                                                ctx.stroke()
                                            }
                                        }

                                        // Initial paint + repaint on theme/visibility changes
                                        Component.onCompleted: requestPaint()
                                    }

                                    // Icon as QML Text — Nerd Font renders correctly here
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.pixelSize: 14
                                        color: arcItem.arcPct > 0.85 ? "#ff7b72"
                                             : arcItem.arcPct > 0.65 ? "#e3b341"
                                             : Theme.muted1
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label + " " + Math.round(modelData.value) + "%"
                                    font.pixelSize: 9; font.weight: Font.DemiBold
                                    color: modelData.value > 85 ? "#ff7b72"
                                         : modelData.value > 65 ? "#e3b341"
                                         : Theme.text
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: metCard.hov = true
                                onExited:  metCard.hov = false
                                onClicked: {
                                    var k = modelData.key
                                    root._expandedMetric = (root._expandedMetric === k) ? "" : k
                                    if (root._expandedMetric === "cpu" && !root._cpuLoaded) {
                                        root._cpuBuf = ""; cpuDetailProc.running = true
                                    } else if (root._expandedMetric === "gpu" && !root._gpuLoaded) {
                                        root._gpuBuf = ""; gpuDetailProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }

                 // ── Panel de detalle expandible — CPU ──────────────────────
                 Rectangle {
                     width: parent.width
                     height: root._expandedMetric === "cpu" ? cpuDetailCol.implicitHeight + 16 : 0
                     radius: 10; color: Theme.surface2
                    clip: true
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        id: cpuDetailCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6

                        // Modelo
                        Text {
                            text: root._cpuModel || "CPU"
                            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.text
                            elide: Text.ElideRight; width: parent.width
                        }

                        // Uso global + temp + freq
                        Row {
                            spacing: 12
                            Text { text: "Usage: " + SysData.cpuPercent + "%"; font.pixelSize: 10; color: Theme.muted1 }
                            Text {
                                visible: root._cpuPkgTemp > 0
                                text: "Temp: " + root._cpuPkgTemp + " °C"
                                font.pixelSize: 10
                                color: root._cpuPkgTemp >= 85 ? "#ff7b72"
                                     : root._cpuPkgTemp >= 70 ? "#e3b341"
                                     : Theme.muted1
                            }
                            Text {
                                visible: root._cpuAvgFreq > 0
                                text: root._cpuAvgFreq + " MHz"
                                font.pixelSize: 10; color: Theme.muted1
                            }
                        }

                        // Barras por núcleo (máx 16 en grid 4 cols)
                        Grid {
                            columns: 4
                            spacing: 4
                            width: parent.width

                            Repeater {
                                model: Math.min(root._cpuCorePcts.length, 16)
                                Item {
                                    required property int index
                                    property int corePct: root._cpuCorePcts[index] || 0
                                    width: (cpuDetailCol.width - 12) / 4; height: 22

                                    Rectangle {
                                        anchors.fill: parent; radius: 4; color: Theme.surface3
                                    }
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: Math.max(4, corePct / 100 * parent.width)
                                        radius: 4
                                        color: corePct > 85 ? "#ff7b72"
                                             : corePct > 65 ? "#e3b341"
                                             : Theme.accent
                                        Behavior on width { NumberAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "C" + (index + 1)
                                        font.pixelSize: 8; color: Theme.muted1
                                    }
                                }
                            }
                        }

                        // Gov + EPP
                        Row {
                            spacing: 10
                            visible: root._cpuGov !== ""
                            Text { text: "Governor: " + root._cpuGov; font.pixelSize: 9; color: Theme.muted2 }
                            Text { visible: root._cpuEpp !== ""; text: "EPP: " + root._cpuEpp; font.pixelSize: 9; color: Theme.muted2 }
                        }
                    }
                }

                 // ── Panel de detalle expandible — RAM ──────────────────────
                 Rectangle {
                     width: parent.width
                     height: root._expandedMetric === "ram" ? ramDetailCol.implicitHeight + 16 : 0
                     radius: 10; color: Theme.surface2
                    clip: true
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        id: ramDetailCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6

                        // Barra RAM usada
                        Item {
                            width: parent.width; height: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(6, SysData.ramPercent / 100 * parent.width)
                                radius: 3
                                color: SysData.ramPercent >= 90 ? "#ff7b72"
                                     : SysData.ramPercent >= 75 ? "#e3b341"
                                     : Theme.accent
                                Behavior on width { NumberAnimation { duration: 200 } }
                            }
                        }

                        Row {
                            spacing: 12
                            Text { text: SysData.ramUsedGb.toFixed(1) + " / " + SysData.ramTotalGb.toFixed(1) + " GB"; font.pixelSize: 10; color: Theme.text }
                            Text { text: "(" + SysData.ramPercent + "%)"; font.pixelSize: 10; color: Theme.muted1 }
                        }

                        // Swap si hay
                        Item {
                            visible: SysData.swapPercent > 0
                            width: parent.width; height: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(4, SysData.swapPercent / 100 * parent.width)
                                radius: 3; color: "#e3b341"
                                Behavior on width { NumberAnimation { duration: 200 } }
                            }
                        }
                        Text {
                            visible: SysData.swapPercent > 0
                            text: "Swap: " + SysData.swapPercent + "%"

                            font.pixelSize: 9; color: Theme.muted2
                        }

                        Row {
                            spacing: 12
                            Text { text: "Free: " + SysData.ramAvailGb.toFixed(1) + " GB"; font.pixelSize: 9; color: Theme.muted2 }
                        }
                    }
                }

                 // ── Panel de detalle expandible — GPU (multi-vendor) ──────────
                 Rectangle {
                     width: parent.width
                     height: root._expandedMetric === "gpu" ? gpuDetailCol.implicitHeight + 16 : 0
                     radius: 10; color: Theme.surface2
                    clip: true
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Column {
                        id: gpuDetailCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        Repeater {
                            model: root._gpus

                            Column {
                                id: gpuEntry
                                required property var modelData
                                required property int index
                                width: gpuDetailCol.width
                                spacing: 4

                                // Separator between GPUs
                                Rectangle {
                                    visible: gpuEntry.index > 0
                                    width: parent.width; height: 1; color: Theme.surface3
                                }

                                // Name + vendor badge
                                Row {
                                    spacing: 6
                                    Text {
                                        text: {
                                            var v = gpuEntry.modelData.vendor
                                            if (v === "nvidia") return "󰾲"
                                            if (v === "amd")    return "󰢮"
                                            return "󰾅"  // intel
                                        }
                                        font.pixelSize: 13
                                        color: {
                                            var v = gpuEntry.modelData.vendor
                                            if (v === "nvidia") return "#76b900"
                                            if (v === "amd")    return "#ed1c24"
                                            return Theme.accent
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: gpuEntry.modelData.name || (gpuEntry.modelData.vendor.toUpperCase() + " GPU")
                                        font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.text
                                        elide: Text.ElideRight
                                        width: gpuDetailCol.width - 26
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Inactive overlay for NVIDIA when driver off
                                Text {
                                    visible: gpuEntry.modelData.vendor === "nvidia" && gpuEntry.modelData.status !== "active"
                                    text: "Driver inactive"
                                    font.pixelSize: 9; color: Theme.muted2
                                }

                                // Util bar (skip for Intel which reports -1)
                                Item {
                                    visible: gpuEntry.modelData.util >= 0 && gpuEntry.modelData.status === "active"
                                    width: parent.width; height: 5
                                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: Math.max(4, gpuEntry.modelData.util / 100 * parent.width)
                                        radius: 3; color: Theme.accent
                                        Behavior on width { NumberAnimation { duration: 200 } }
                                    }
                                }

                                // Stats row
                                Row {
                                    visible: gpuEntry.modelData.status === "active"
                                    spacing: 10

                                    Text {
                                        visible: gpuEntry.modelData.util >= 0
                                        text: gpuEntry.modelData.util + "% util"
                                        font.pixelSize: 9; color: Theme.muted1
                                    }
                                    Text {
                                        visible: gpuEntry.modelData.temp > 0
                                        text: gpuEntry.modelData.temp + " °C"
                                        font.pixelSize: 9
                                        color: gpuEntry.modelData.temp >= 85 ? "#ff7b72"
                                             : gpuEntry.modelData.temp >= 70 ? "#e3b341"
                                             : Theme.muted1
                                    }
                                    Text {
                                        visible: gpuEntry.modelData.freq > 0
                                        text: gpuEntry.modelData.freq + " MHz"
                                        font.pixelSize: 9; color: Theme.muted1
                                    }
                                    Text {
                                        visible: gpuEntry.modelData.vramTotal > 0
                                        text: gpuEntry.modelData.vramUsed + " / " + gpuEntry.modelData.vramTotal + " MiB"
                                        font.pixelSize: 9; color: Theme.muted1
                                    }
                                    Text {
                                        visible: gpuEntry.modelData.power > 0
                                        text: gpuEntry.modelData.power.toFixed(1) + " W"
                                        font.pixelSize: 9; color: Theme.muted2
                                    }
                                }
                            }
                        }

                        // Empty state
                        Text {
                            visible: root._gpus.length === 0
                            text: "No GPU data"
                            font.pixelSize: 10; color: Theme.muted2
                        }
                    }
                }

                // ── Disco: Root + Home ─────────────────────────────────────
                Item { width: parent.width; height: 8 }

                Grid {
                    width: parent.width
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: [
                            { label: "Root", icon: "󰋊",
                              pct: root._diskPct, used: root._diskUsed, total: root._diskTotal },
                            { label: "Home", icon: "󰋞",
                              pct: root._homePct, used: root._homeUsed, total: root._homeTotal }
                        ]

                        Rectangle {
                            required property var modelData
                            width: (parent.width - 6) / 2; height: 52; radius: 10
                            color: Theme.surface2

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8

                                Text {
                                    text: modelData.icon; font.pixelSize: 18
                                    color: modelData.pct >= 90 ? "#ff7b72"
                                         : modelData.pct >= 75 ? "#e3b341"
                                         : Theme.muted1
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Row {
                                        spacing: 6
                                        Text {
                                            text: modelData.label
                                            font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                                        }
                                        Text {
                                            text: modelData.pct + "%"
                                            font.pixelSize: 10
                                            color: modelData.pct >= 90 ? "#ff7b72"
                                                 : modelData.pct >= 75 ? "#e3b341"
                                                 : Theme.muted1
                                        }
                                    }

                                    // Barra de uso
                                    Item {
                                        width: parent.width; height: 4
                                        Rectangle { anchors.fill: parent; radius: 2; color: Theme.surface3 }
                                        Rectangle {
                                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                            width: Math.max(4, modelData.pct / 100 * parent.width)
                                            radius: 2
                                            color: modelData.pct >= 90 ? "#ff7b72"
                                                 : modelData.pct >= 75 ? "#e3b341"
                                                 : Theme.accent
                                            Behavior on width { NumberAnimation { duration: 300 } }
                                        }
                                    }

                                    Text {
                                        text: modelData.used + " / " + modelData.total + " GB"
                                        font.pixelSize: 9; color: Theme.muted2
                                    }
                                }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════
                // Media player — always at the bottom
                // ══════════════════════════════════════════════════════════
                Item { width: parent.width; height: 10 }
                Rectangle {
                    width: parent.width; height: 1; color: Theme.surface2
                    visible: root.mprisPlayer !== null
                }

                Item {
                    width: parent.width
                    height: root.mprisPlayer !== null ? (innerPlayer.implicitHeight + 16) : 0
                    visible: root.mprisPlayer !== null

                    Rectangle {
                        id: innerPlayer
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                        height: 80; radius: 10; color: Theme.surface2

                        RowLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 10

                            // Album art
                            Rectangle {
                                Layout.preferredWidth: 52; Layout.preferredHeight: 52
                                radius: 8; color: Theme.surface3; clip: true
                                Image {
                                    anchors.fill: parent
                                    source: root.mprisPlayer?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: (root.mprisPlayer?.trackArtUrl ?? "") === "" ||
                                             parent.children[1]?.status !== Image.Ready
                                    text: "󰝚"; font.pixelSize: 20; color: Theme.muted2
                                }
                            }

                            // Info + controls
                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.mprisPlayer?.trackTitle ?? "Nothing playing"
                                    font.pixelSize: 12; font.weight: Font.DemiBold
                                    color: Theme.text; elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: root.mprisPlayer?.trackArtist ?? ""
                                    font.pixelSize: 10; color: Theme.muted1; elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: [
                                            { icon: "󰒮", action: "prev" },
                                            { icon: root.mprisPlayer?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊", action: "play" },
                                            { icon: "󰒭", action: "next" }
                                        ]
                                        Rectangle {
                                            required property var modelData
                                            width: 26; height: 26; radius: 7
                                            color: pCtrlHov.containsMouse ? Theme.surface3 : "transparent"
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                            Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 14; color: Theme.text }
                                            MouseArea {
                                                id: pCtrlHov; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var p = root.mprisPlayer
                                                    if (!p) return
                                                    if (modelData.action === "prev")       p.previous()
                                                    else if (modelData.action === "next")  p.next()
                                                    else if (p.playbackState === MprisPlaybackState.Playing) p.pause()
                                                    else p.play()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { width: parent.width; height: 8 }
            }
        }

        // Scrollbar visual
        Rectangle {
            visible: ccFlick.contentHeight > ccFlick.height + 1
            anchors { right: parent.right; rightMargin: 3 }
            y: 12 + ccFlick.visibleArea.yPosition * (ccCard.height - 24)
            width: 3; radius: 2
            height: Math.max(20, ccFlick.visibleArea.heightRatio * (ccCard.height - 24))
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
        }
    }

    // ── Confirm overlay (critical power actions) ──────────────────────────
    Rectangle {
        visible: root._showConfirm
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        z: 100

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 240; height: confirmCol.implicitHeight + 40
            radius: 14; color: Theme.cardBg3
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            opacity: root._showConfirm ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Column {
                id: confirmCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 22 }
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root._confirmLabel
                    font.pixelSize: 16; font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Are you sure?"
                    font.pixelSize: 12; color: Qt.rgba(1, 1, 1, 0.50)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: 96; height: 34; radius: 9
                        color: cnNoHov.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                        border.color: Qt.rgba(1,1,1, cnNoHov.containsMouse ? 0.25 : 0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.80) }
                        MouseArea { id: cnNoHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._showConfirm = false }
                    }

                    Rectangle {
                        width: 96; height: 34; radius: 9
                        color: cnYesHov.containsMouse ? Qt.rgba(0.9,0.2,0.2,0.45) : Qt.rgba(0.8,0.15,0.15,0.25)
                        border.color: Qt.rgba(1,0.35,0.35, cnYesHov.containsMouse ? 0.7 : 0.40); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Confirm"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Qt.rgba(1,0.6,0.6,1) }
                        MouseArea { id: cnYesHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cmd = root._confirmCmd
                                root._showConfirm = false
                                root.visible = false
                                ccExecProc.runCmd(cmd)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Power exec process ────────────────────────────────────────────────
    Process {
        id: ccExecProc
        running: false
        function runCmd(cmd) { command = cmd; running = true }
        onExited: running = false
    }

    // ── Procesos globales para stream control ─────────────────────────────
    Process {
        id: streamMuteProc
        command: ["bash", "-c", ""]
        onExited: root._pwRev++
    }

    Process {
        id: streamVolProc
        command: ["bash", "-c", ""]
    }

    // ── CPU detail process ────────────────────────────────────────────────
    Process {
        id: cpuDetailProc
        command: ["bash", Paths.scripts + "/cpu-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._cpuBuf += d + "\n" }
        onExited: {
            var kv = {}
            root._cpuBuf.trim().split("\n").forEach(function(line) {
                var idx = line.indexOf(":")
                if (idx > 0) kv[line.substring(0, idx)] = line.substring(idx + 1)
            })
            root._cpuBuf = ""
            if (kv["MODEL"])      root._cpuModel    = kv["MODEL"]
            if (kv["PKG_TEMP"])   root._cpuPkgTemp  = parseInt(kv["PKG_TEMP"])  || 0
            if (kv["AVG_FREQ"])   root._cpuAvgFreq  = parseInt(kv["AVG_FREQ"])  || 0
            if (kv["GOV"])        root._cpuGov      = kv["GOV"]
            if (kv["EPP"])        root._cpuEpp      = kv["EPP"]
            if (kv["CORE_PCTS"])  root._cpuCorePcts = kv["CORE_PCTS"].split(",").map(function(s) { return parseInt(s) || 0 })
            root._cpuLoaded = true
        }
    }

    // Refrescar CPU mientras esté expandido
    Timer {
        interval: 1500; repeat: true
        running: root.visible && root._expandedMetric === "cpu"
        onTriggered: { root._cpuBuf = ""; cpuDetailProc.running = true }
    }

    // ── GPU detail process — multi-vendor parser ──────────────────────────
    Process {
        id: gpuDetailProc
        command: ["bash", Paths.scripts + "/gpu-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._gpuBuf += d + "\n" }
        onExited: {
            var kv = {}
            root._gpuBuf.trim().split("\n").forEach(function(line) {
                var idx = line.indexOf(":")
                if (idx > 0) kv[line.substring(0, idx)] = line.substring(idx + 1)
            })
            root._gpuBuf = ""

            var count = parseInt(kv["GPU_COUNT"]) || 0
            var list = []
            for (var i = 1; i <= count; i++) {
                var p = "GPU" + i + "_"
                var vendor = (kv[p + "VENDOR"] || "").toLowerCase()
                var obj = {
                    vendor:     vendor,
                    name:       kv[p + "NAME"]   || "",
                    status:     kv[p + "STATUS"] || "active",
                    util:       parseInt(kv[p + "UTIL"])       || 0,
                    temp:       parseInt(kv[p + "TEMP"])       || parseInt(kv[p + "TEMP_EDGE"]) || 0,
                    tempJun:    parseInt(kv[p + "TEMP_JUN"])   || 0,
                    freq:       parseInt(kv[p + "FREQ"])       || 0,
                    power:      parseFloat(kv[p + "POWER"])    || 0,
                    vramUsed:   parseInt(kv[p + "VRAM_USED"])  || 0,
                    vramTotal:  parseInt(kv[p + "VRAM_TOTAL"]) || 0,
                    driver:     kv[p + "DRIVER"] || ""
                }
                list.push(obj)
            }
            root._gpus = list
            root._gpuLoaded = true
        }
    }

    Timer {
        interval: 1500; repeat: true
        running: root.visible && root._expandedMetric === "gpu"
        onTriggered: { root._gpuBuf = ""; gpuDetailProc.running = true }
    }

    // ── Fan profiles process — reads available profiles dynamically ────────
    Process {
        id: fanProfilesProc
        command: ["bash", Paths.scripts + "/fan-control.sh", "list_profiles"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._fanBuf += d + "\n" }
        onExited: {
            var lines = root._fanBuf.trim().split("\n")
            root._fanBuf = ""
            var profiles = []
            for (var i = 0; i < lines.length; i++) {
                var id = lines[i].trim()
                if (id.length === 0) continue
                var icon = "󰈐"
                var label = id.charAt(0).toUpperCase() + id.slice(1)
                if (id === "cool" || id === "turbo_cool") { icon = "󰆏"; label = "Cool" }
                else if (id === "quiet")       { icon = "󰒲"; label = "Quiet" }
                else if (id === "balanced")    { icon = "󱐌"; label = "Balanced" }
                else if (id === "performance") { icon = "󰓅"; label = "Performance" }
                profiles.push({ id: id, label: label, icon: icon })
            }
            if (profiles.length > 0) root._fanProfiles = profiles
        }
    }

    // Fan apply process
    Process {
        id: fanApplyProc
        running: false
        onExited: running = false
    }

    // ── Battery detail process ────────────────────────────────────────────
    Process {
        id: batDetailProc
        command: ["bash", Paths.scripts + "/battery-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._batBuf += d + "\n" }
        onExited: {
            root._batBuf.trim().split("\n").forEach(function(line) {
                var idx = line.indexOf(":")
                if (idx < 1) return
                var k = line.substring(0, idx), v = line.substring(idx + 1)
                if (k === "HEALTH") root._batHealth = parseFloat(v) || 0
                if (k === "CAP_WH") root._batCapWh  = parseFloat(v) || 0
                if (k === "CYCLES") root._batCycles  = parseInt(v)  || 0
            })
            root._batBuf = ""
        }
    }

    // ── Language processes ────────────────────────────────────────────────
    // Current layout from Hyprland
    Process {
        id: langCurrentProc
        command: ["sh", "-c",
            "hyprctl devices -j 2>/dev/null | " +
            "python3 -c \"import json,sys; d=json.load(sys.stdin); k=d.get('keyboards',[]); kb=next((x for x in k if x.get('main')), k[0] if k else {}); print(kb.get('active_keymap',''))\""]
        stdout: SplitParser {
            splitMarker: ""
            onRead: d => {
                var v = d.trim()
                if (v) root._langLayout = v
            }
        }
    }

    // System locale
    Process {
        id: langLocaleProc
        command: ["sh", "-c",
            "localectl status 2>/dev/null | awk -F'LANG=' '/System Locale/{print $2}' | awk '{print $1}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: d => { var v = d.trim(); if (v) root._langLocale = v }
        }
    }

    // Available layouts from localectl
    Process {
        id: langLayoutProc
        command: ["sh", "-c", "timeout 3s localectl list-keymaps 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._langBuf += d + "\n" }
        onExited: {
            var lines = root._langBuf.trim().split("\n")
            root._langBuf = ""
            var layouts = []
            for (var i = 0; i < lines.length; i++) {
                var code = lines[i].trim()
                if (code.length === 0) continue
                layouts.push({ code: code, label: code })
            }
            if (layouts.length > 0) root._langLayouts = layouts
        }
    }

    // Apply layout via Hyprland
    Process {
        id: langSetProc
        command: ["sh", "-c", ""]
        onExited: Qt.callLater(() => langCurrentProc.running = true)
    }

    // Available locales from localectl
    Process {
        id: langLocaleListProc
        command: ["sh", "-c", "timeout 3s localectl list-locales 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._langLocaleBuf += d + "\n" }
        onExited: {
            var lines = root._langLocaleBuf.trim().split("\n")
            root._langLocaleBuf = ""
            var locales = []
            for (var i = 0; i < lines.length; i++) {
                var value = lines[i].trim()
                if (value.length === 0) continue
                locales.push({ value: value, label: value })
            }
            if (locales.length > 0) root._langLocales = locales
        }
    }

    // Apply locale via localectl
    Process {
        id: langSetLocaleProc
        command: ["sh", "-c", ""]
        onExited: langLocaleProc.running = true
    }

    // ── Disk detail process (root + home) ─────────────────────────────────
    Process {
        id: diskDetailProc
        command: ["bash", Paths.scripts + "/disk-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._diskBuf += d + "\n" }
        onExited: {
            var kv = {}
            root._diskBuf.trim().split("\n").forEach(function(line) {
                var idx = line.indexOf(":")
                if (idx > 0) kv[line.substring(0, idx)] = line.substring(idx + 1)
            })
            root._diskBuf = ""
            if (kv["PCT"])        root._diskPct   = parseInt(kv["PCT"])        || 0
            if (kv["USED"])       root._diskUsed  = parseInt(kv["USED"])       || 0
            if (kv["TOTAL"])      root._diskTotal = parseInt(kv["TOTAL"])      || 0
            if (kv["HOME_PCT"])   root._homePct   = parseInt(kv["HOME_PCT"])   || 0
            if (kv["HOME_USED"])  root._homeUsed  = parseInt(kv["HOME_USED"])  || 0
            if (kv["HOME_TOTAL"]) root._homeTotal = parseInt(kv["HOME_TOTAL"]) || 0
        }
    }

}

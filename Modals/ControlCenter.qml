import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import "../Components"
import "./cc"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true

    // ── Señales hacia el orquestador (shell.qml) ──────────────────────────

    // ── Power confirm state ───────────────────────────────────────────────
    property bool   _showConfirm:  false
    property string _confirmLabel: ""
    property var    _confirmCmd:   []

    // ── Bluetooth rev ─────────────────────────────────────────────────────
    property int  _btRev: 0

    // ── Paneles expandibles en toggles ───────────────────────────────────
    property string _activePanel: ""   // "wifi" | "bluetooth" | "audio" | "power" | "battery" | "language" | "cpu" | "ram" | "gpu" | ""
    property bool   _audioShowSources: true

    // ── WiFi inline state — Quickshell.Networking API ────────────────────
    // Networking singleton + first WiFi device
    property var    _nmWifiDev: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }

    property bool   _wifiRadioOn:    Networking.wifiEnabled
    property bool   _wifiScanning:   _nmWifiDev ? _nmWifiDev.scannerEnabled : false
    property bool   _wifiWorking:    false
    property string _wifiStatusMsg:  ""
    property int    _wifiSelectedIdx: -1
    property var    _wifiPasswordByIndex: ({})
    property var    _wifiTargetNet:  null   // red a la que se está intentando conectar

    // Derived: connected network (reactive)
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

    // IP/Gateway/DNS — still fetched via nmcli (not exposed by API)
    property string _wifiIp:      ""
    property string _wifiGateway: ""
    property string _wifiDns:     ""

    // Ethernet state — still fetched via nmcli (not exposed by Networking API)
    property bool   _ethConnected: false
    property string _ethIp:        ""
    property string _ethSpeed:     ""

    // Password fetch shared state (for revealing saved PSK via nmcli -s)
    property string _wifiPwFetchResult:    ""
    property int    wifiPwFetchResultIdx: -2
    property int    _wifiPwFetchIdx:       -1

    // Buffers
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

    // ── Battery — UPower API ──────────────────────────────────────────────
    property var    _upowerDev:    UPower.displayDevice
    // Derived properties — reactive, no polling needed
    property bool   _batAvailableUP: _upowerDev ? _upowerDev.isPresent && _upowerDev.isLaptopBattery : false
    property real   _batPctUP:       _upowerDev ? _upowerDev.percentage * 100 : 0
    property bool   _batChargingUP:  _upowerDev ? (_upowerDev.state === UPowerDeviceState.Charging ||
                                                    _upowerDev.state === UPowerDeviceState.PendingCharge) : false
    property bool   _batFullUP:      _upowerDev ? _upowerDev.state === UPowerDeviceState.FullyCharged : false
    property real   _batHealthUP:    _upowerDev ? (_upowerDev.healthSupported ? _upowerDev.healthPercentage : 0) : 0
    property real   _batCapWhUP:     _upowerDev ? _upowerDev.energyCapacity    : 0
    property real   _batEnergyUP:    _upowerDev ? _upowerDev.energy            : 0
    property real   _batChangeRate:  _upowerDev ? _upowerDev.changeRate        : 0
    property real   _batTimeEmpty:   _upowerDev ? _upowerDev.timeToEmpty       : 0
    property real   _batTimeFull:    _upowerDev ? _upowerDev.timeToFull        : 0

    // Language detail
    property string _langLayout:   "—"
    property string _langLocale:   "—"
    property var    _langLayouts:  []   // [{label, code}]
    property string _langBuf:      ""
    property string _langSetBuf:   ""
    property var    _langLocales:  []
    property string _langLocaleBuf:""
    property string _langSearch:        ""   // valor debounced (el que leen los filtros)
    property string _langSearchPending: ""   // valor inmediato del campo de texto
    property string _langTab:           "keyboard"

    // Debounce: aplica la búsqueda 150 ms después de la última tecla
    Timer {
        id: _langSearchDebounce
        interval: 150
        onTriggered: root._langSearch = root._langSearchPending
    }

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

    // ── Audio — Pipewire API nativa ───────────────────────────────────────
    property var defaultSink:   Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [root.defaultSink, root.defaultSource] }

    // masterVolume / masterMuted / micVolume / micMuted se enlazan reactivamente
    // desde el audio del sink/source default — sin procesos externos
    property real masterVolume: defaultSink?.audio?.volume  ?? 0.75
    property bool masterMuted:  defaultSink?.audio?.muted   ?? false
    property real micVolume:    defaultSource?.audio?.volume ?? 0.75
    property bool micMuted:     defaultSource?.audio?.muted  ?? false

    // Mantener sincronizados cuando cambia el sink/source default
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged()   { root._pwRev++ }
        function onDefaultAudioSourceChanged() { root._pwRev++ }
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

    // ── Brillo ────────────────────────────────────────────────────────────
    property int brightness: 50
    property bool _brightnessReady: false

    // ── Audio state ───────────────────────────────────────────────────────
    property int  _pwRev: 0   // cambios en sinks/sources/visibilidad

    // ── Audio device lists (sinks / sources) ──────────────────────────────
    // Puerto de disponibilidad — sigue necesitando pactl (no expuesto por API)
    property var    _audioSinkAvail:   ({})   // { nodeName: bool }
    property var    _audioSourceAvail: ({})
    property string _audioSinkBuf:     ""
    property string _audioSourceBuf:   ""

    // Computed — se recalcula cuando cambia _pwRev o los mapas de disponibilidad
    // Gate: solo escanea nodos cuando el panel de audio está activo y visible
    property var audioSinks: {
        _pwRev; _audioSinkAvail
        if (!root.visible || root._activePanel !== "audio") return root.audioSinks ?? []
        var activeName = root.defaultSink?.name ?? ""
        var out = []
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var node = all[i]
            if (!node || !node.isSink || node.isStream) continue
            var name = node.name ?? ""
            if (!name || name.endsWith(".monitor")) continue
            if (root._audioSinkAvail[name] !== true) continue
            out.push({
                id: name,
                label: _audioFormatDesc(node.description, name),
                icon:  _audioSinkIcon(name),
                active: name === activeName,
                node:  node
            })
        }
        return out
    }

    property var audioSources: {
        _pwRev; _audioSourceAvail
        if (!root.visible || root._activePanel !== "audio") return root.audioSources ?? []
        var activeName = root.defaultSource?.name ?? ""
        var out = []
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var node = all[i]
            if (!node || node.isSink || node.isStream) continue
            var name = node.name ?? ""
            if (!name || name.endsWith(".monitor")) continue
            if (root._audioSourceAvail[name] !== true) continue
            out.push({
                id: name,
                label: _audioFormatDesc(node.description, name),
                icon:  _audioSourceIcon(name),
                active: name === activeName,
                node:  node
            })
        }
        return out
    }

    function _audioSinkIcon(name) {
        const n = name.toLowerCase()
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("iec958")) return "󰡁"
        if (n.includes("bluez") || n.includes("bluetooth")) return "󰋋"
        if (n.includes("usb")) return "󱊣"
        if (n.includes("headphone") || n.includes("headset")) return "󰋋"
        return "󰕾"
    }

    function _audioSourceIcon(name) {
        const n = name.toLowerCase()
        if (n.includes("bluez") || n.includes("bluetooth")) return "󰋋"
        if (n.includes("usb")) return "󱊣"
        if (n.includes("webcam") || n.includes("camera")) return "󰄀"
        return "󰍹"
    }

    function _audioFormatDesc(desc, name) {
        if (desc && desc !== "" && desc !== "(null)") return desc
        var n = (name || "")
            .replace(/^alsa_(output|input)\./, "")
            .replace(/^bluez_(output|input)\.[0-9A-Fa-f:_]+$/, "Bluetooth")
            .replace(/^bluez_(output|input)\./, "Bluetooth: ")
            .replace(/pci-[0-9a-f]{4}_[0-9a-f]{2}_[0-9a-f]{2}\.\d+\./, "")
            .replace(/usb-[^.]+\./, "USB: ")
            .replace(/[-_.]+/g, " ").trim()
        return n.replace(/\b\w/g, function(c) { return c.toUpperCase() })
    }

    function setDefaultSink(entry) {
        if (!entry.node) return
        // API nativa para cambiar el sink default
        Pipewire.preferredDefaultAudioSink = entry.node
        // Mover streams activos al nuevo sink (no expuesto por API)
        var safe = entry.id.replace(/'/g, "'\\''")
        _audioMoveSinkProc.command = ["bash", "-c",
            "pactl list short sink-inputs | awk '{print $1}' | " +
            "xargs -r -I{} pactl move-sink-input {} '" + safe + "' 2>/dev/null"]
        _audioMoveSinkProc.running = true
    }

    function setDefaultSource(entry) {
        if (!entry.node) return
        Pipewire.preferredDefaultAudioSource = entry.node
        var safe = entry.id.replace(/'/g, "'\\''")
        _audioMoveSourceProc.command = ["bash", "-c",
            "pactl list short source-outputs | awk '{print $1}' | " +
            "xargs -r -I{} pactl move-source-output {} '" + safe + "' 2>/dev/null"]
        _audioMoveSourceProc.running = true
    }

    function loadAudioDevices() {
        _audioSinkBuf   = ""
        _audioSourceBuf = ""
        _audioSinkAvailProc.running   = true
        _audioSourceAvailProc.running = true
    }

    // Fetch port availability (pactl — no expuesto por Pipewire API)
    // LANG=C fuerza output en inglés — pactl es locale-sensitive
    Process {
        id: _audioSinkAvailProc
        command: ["bash", "-c", "LANG=C pactl --format=json list sinks 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._audioSinkBuf += d + "\n" }
        onExited: {
            try {
                var data = JSON.parse(root._audioSinkBuf)
                var map = ({})
                for (var i = 0; i < data.length; i++) {
                    var s = data[i]; var name = s.name || ""; if (!name) continue
                    var ports = s.ports || []
                    if (ports.length === 0) { map[name] = true; continue }
                    var ok = false
                    for (var p = 0; p < ports.length; p++) {
                        var av = (ports[p].availability || "").toString().toLowerCase()
                        if (av !== "not available") { ok = true; break }
                    }
                    map[name] = ok
                }
                root._audioSinkAvail = map
                root._pwRev++
            } catch(e) {}
            root._audioSinkBuf = ""
        }
    }

    Process {
        id: _audioSourceAvailProc
        command: ["bash", "-c", "LANG=C pactl --format=json list sources 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._audioSourceBuf += d + "\n" }
        onExited: {
            try {
                var data = JSON.parse(root._audioSourceBuf)
                var map = ({})
                for (var i = 0; i < data.length; i++) {
                    var s = data[i]; var name = s.name || ""
                    if (!name || name.endsWith(".monitor")) continue
                    var ports = s.ports || []
                    if (ports.length === 0) { map[name] = true; continue }
                    var ok = false
                    for (var p = 0; p < ports.length; p++) {
                        var av = (ports[p].availability || "").toString().toLowerCase()
                        if (av !== "not available") { ok = true; break }
                    }
                    map[name] = ok
                }
                root._audioSourceAvail = map
                root._pwRev++
            } catch(e) {}
            root._audioSourceBuf = ""
        }
    }

    // Mover streams al nuevo sink/source (pactl — necesario, no expuesto por API)
    Process { id: _audioMoveSinkProc;   command: ["bash", "-c", ""] }
    Process { id: _audioMoveSourceProc; command: ["bash", "-c", ""] }

    // Refresh cada 5 s mientras el panel esté abierto
    Timer {
        interval: 5000; repeat: true
        running: root.visible && root._activePanel === "audio"
        onTriggered: root.loadAudioDevices()
    }

    // ── Perfil de energía — UPower PowerProfiles API ─────────────────────
    // PowerProfiles.profile es read/write (PowerProfile enum)
    // PowerProfiles.hasPerformanceProfile indica si el perfil performance está disponible

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

    property real playerPos: 0   // en segundos (igual que el API)
    property int  _posSync: 0

    function _syncPlayerPos() {
        if (root.mprisPlayer && root.mprisPlayer.positionSupported)
            root.playerPos = root.mprisPlayer.position
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.mprisPlayer?.isPlaying
        onTriggered: {
            root.playerPos += 1   // 1 segundo
            root._posSync++
            if (root._posSync >= 10) { root._posSync = 0; root._syncPlayerPos() }
        }
    }

    Connections {
        target: root.mprisPlayer ?? null
        function onTrackChanged() { root._syncPlayerPos(); root._posSync = 0 }
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

    // Aplicar brillo
    Process {
        id: setBrightnessProc
        property int targetPct: 50
        command: ["bash", "-c", "brightnessctl set " + targetPct + "% 2>/dev/null"]
    }

    // ── Funciones de audio — Pipewire API nativa ──────────────────────────
    function setMasterVolume(v) {
        root.masterVolume = v
        if (root.defaultSink?.audio) root.defaultSink.audio.volume = v
    }

    function setMicVol(v) {
        root.micVolume = v
        if (root.defaultSource?.audio) root.defaultSource.audio.volume = v
    }

    function toggleMasterMute() {
        if (root.defaultSink?.audio) {
            root.defaultSink.audio.muted = !root.defaultSink.audio.muted
        }
    }

    function toggleMicMute() {
        if (root.defaultSource?.audio) {
            root.defaultSource.audio.muted = !root.defaultSource.audio.muted
        }
    }

    function setBrightness(pct) {
        root.brightness = pct
        setBrightnessProc.targetPct = pct
        if (!setBrightnessProc.running) setBrightnessProc.running = true
    }

    // ── Power profile helpers — UPower enum ──────────────────────────────
    function _powerLabel(profile) {
        if (profile === PowerProfile.Performance) return "Performance"
        if (profile === PowerProfile.PowerSaver)  return "Power saver"
        return "Balanced"
    }

    function _powerIcon(profile) {
        if (profile === PowerProfile.Performance) return "󰓅"
        if (profile === PowerProfile.PowerSaver)  return "󰁹"
        return "󱐌"
    }

    function setPower(profile) {
        PowerProfiles.profile = profile
    }

    // ── Battery time formatting ────────────────────────────────────────────
    function _fmtTime(seconds) {
        if (!seconds || seconds <= 0) return ""
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
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

    function langRefresh() {
        root._langSearchPending = ""
        root._langSearch        = ""
        _langSearchDebounce.stop()
        root._langTab           = "keyboard"
        langLayoutProc.running     = true
        langCurrentProc.running    = true
        langLocaleProc.running     = true
        langLocaleListProc.running = true
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
        running: root.visible && root._activePanel === "bluetooth"
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
    function wifiSignalIcon(strength) {
        // strength es 0.0–1.0 de WifiNetwork.signalStrength
        if (strength >= 0.80) return "󰤨"
        if (strength >= 0.60) return "󰤥"
        if (strength >= 0.40) return "󰤢"
        return "󰤟"
    }

    function wifiSecurityLabel(sec) {
        // WifiSecurityType enum → string legible
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
        // Auto-disable after 15 s if still running
        wScanStopTimer.restart()
    }

    // Conectar red conocida (native API)
    function wifiConnectKnown(net) {
        root._wifiWorking   = true
        root._wifiTargetNet = net
        root._wifiStatusMsg = "Conectando..."
        net.connect()
    }

    // Conectar red nueva con password (nmcli)
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
        root._wifiStatusMsg = "Desconectando..."
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

    // ── WiFi reactivity — observe Networking state changes ────────────────
    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            root._wifiWorking = false
            // When radio turns on, start scanner automatically
            if (Networking.wifiEnabled && root._nmWifiDev)
                root._nmWifiDev.scannerEnabled = true
        }
    }

    // Observe connected state on each network to detect connect/disconnect completion
    Instantiator {
        model: root._nmWifiDev ? root._nmWifiDev.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (modelData.connected) {
                    root._wifiWorking   = false
                    root._wifiTargetNet = null
                    root._wifiStatusMsg = "✓ Conectado"
                    root._wifiSelectedIdx = -1
                    root._wifiPasswordByIndex = ({})
                    wWifiInfoProc.running = true
                } else if (root._wifiWorking && root._wifiStatusMsg === "Desconectando...") {
                    root._wifiWorking   = false
                    root._wifiTargetNet = null
                    root._wifiStatusMsg = "✓ Desconectado"
                }
            }
            function onStateChanged() {
                // Detectar fallo real de conexión.
                // Requisitos para considerar un error genuino:
                // 1. Es la red que estamos intentando conectar (modelData === _wifiTargetNet)
                //    — sin esto, la red anterior que se desconecta al cambiar de red
                //    también dispara este handler con _wifiWorking=true.
                // 2. stateChanging === false — NM terminó de transicionar.
                // 3. El reason no es una desconexión normal:
                //    - None: sin razón (estado inicial)
                //    - UserDisconnected: el usuario desconectó explícitamente
                //    - DeviceDisconnected: NM desconectó la red vieja para conectar la nueva
                if (!modelData.connected
                        && !modelData.stateChanging
                        && modelData === root._wifiTargetNet
                        && modelData.nmReason !== NMConnectionStateReason.None
                        && modelData.nmReason !== NMConnectionStateReason.UserDisconnected
                        && modelData.nmReason !== NMConnectionStateReason.DeviceDisconnected
                        && root._wifiWorking && root._wifiStatusMsg === "Conectando...") {
                    root._wifiWorking   = false
                    root._wifiTargetNet = null
                    root._wifiStatusMsg = "✗ Error al conectar"
                }
            }
        }
    }

    // Auto-stop scanner after 15 s
    Timer {
        id: wScanStopTimer
        interval: 15000
        onTriggered: {
            if (root._nmWifiDev) root._nmWifiDev.scannerEnabled = false
        }
    }

    // Fetch ethernet info on panel open (still needs nmcli)
    Process {
        id: wEthProc
        command: ["bash", "-c",
            "ETH_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':ethernet:connected' | cut -d: -f1); "
            + "if [ -n \"$ETH_IFACE\" ]; then "
            + "echo \"connected\"; "
            + "LANG=C nmcli -t -f IP4.ADDRESS dev show \"$ETH_IFACE\" 2>/dev/null | cut -d: -f2 | cut -d/ -f1; "
            + "ethtool \"$ETH_IFACE\" 2>/dev/null | grep \"Speed:\" | awk '{print $2}'; "
            + "else echo \"disconnected\"; fi"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wEthBuf += d + "\n" }
        onExited: {
            var lines = root._wEthBuf.trim().split("\n")
            root._wEthBuf = ""
            root._ethConnected = (lines[0] || "").trim() === "connected"
            root._ethIp    = (lines[1] || "").trim()
            root._ethSpeed = (lines[2] || "").trim()
        }
    }

    // Connect new network with password
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
    }

    // Fetch IP/Gateway/DNS for connected WiFi (nmcli)
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

    // Reveal saved PSK (nmcli -s)
    Process {
        id: wSharedPwFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wSharedPwFetchProc._buf += d }
        onExited: {
            var pw = wSharedPwFetchProc._buf.trim()
            wSharedPwFetchProc._buf    = ""
            root._wifiPwFetchResult    = pw
            root.wifiPwFetchResultIdx = root._wifiPwFetchIdx
        }
    }

    // Copy password to clipboard (nmcli -s → wl-copy)
    Process {
        id: wMenuCopyFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wMenuCopyFetchProc._buf += d }
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
    }

    Process {
        id: wMenuCopyExecProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            root._wifiStatusMsg = ec === 0 ? "✓ Contraseña copiada" : "✗ wl-copy error " + ec
        }
    }

    // ── Startup ────────────────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            root._buf      = ""
            root._diskBuf  = ""
            root._cpuLoaded = false
            root._gpuLoaded = false
            getBrightnessProc.running = true
            diskDetailProc.running    = true
            Qt.callLater(root._syncPlayerPos)
            root._pwRev++
            root._btRev++
            Qt.callLater(function() { ccCard.forceActiveFocus() })
        } else {
            root._expandedMetric = ""
            root._showConfirm    = false
            root._activePanel    = ""
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
                                { icon: "󰌾",  label: "Lock",       cmd: ["hyprlock"],                     color: "#79c0ff", critical: false },
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
                                onClicked: root.toggleMasterMute()
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
                                onClicked: root.toggleMicMute()
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
                             : (root._activePanel === "wifi"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (SysData.netConnected
                                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                           : Theme.surface2))
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Barra lateral activo
                        Rectangle {
                            visible: SysData.netConnected || root._activePanel === "wifi"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: (SysData.netConnected || root._activePanel === "wifi") ? 14 : 10
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

                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: wifiCard.hov = true
                            onExited:  wifiCard.hov = false
                            onClicked: {
                                root._activePanel         = "wifi"
                                root._wifiStatusMsg       = ""
                                root._wifiSelectedIdx     = -1
                                root._wifiPasswordByIndex = ({})
                                wEthProc.running          = true
                                wWifiInfoProc.running     = root._wifiConnectedNet !== null
                                if (root._nmWifiDev && root._wifiRadioOn)
                                    root._nmWifiDev.scannerEnabled = true
                            }
                        }
                    }

                    // ── Bluetooth ─────────────────────────────────────────
                    Rectangle {
                        id: btCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._activePanel === "bluetooth"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (root.btConnectedCount > 0
                                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                           : Theme.surface2))
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root.btConnectedCount > 0 || root._activePanel === "bluetooth"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: (root.btConnectedCount > 0 || root._activePanel === "bluetooth") ? 14 : 10
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

                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: btCard.hov = true
                            onExited:  btCard.hov = false
                            onClicked: {
                                root._activePanel = "bluetooth"
                                root._btStatusMsg = ""
                                root.btRefreshDeviceLists()
                                if (root._btPwrd && root._btAdapter) {
                                    root._btAdapter.discoverable = true
                                    root._btAdapter.pairable     = true
                                    root.btAutoConnectTrusted()
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
                             : (root._activePanel === "power"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._activePanel === "power"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: root._activePanel === "power" ? 14 : 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                text: root._powerIcon(PowerProfiles.profile)
                                font.pixelSize: 18
                                color: {
                                    if (PowerProfiles.profile === PowerProfile.Performance) return "#ff7b72"
                                    if (PowerProfiles.profile === PowerProfile.PowerSaver)  return "#79c0ff"
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
                                        var p = root._powerLabel(PowerProfiles.profile)
                                        if (SysData.fanAvailable && SysData.fan1Rpm > 0)
                                            p += " · " + SysData.fan1Rpm + " rpm"
                                        return p
                                    }
                                    font.pixelSize: 9; color: Theme.muted1
                                    elide: Text.ElideRight
                                }
                            }

                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: powerCard.hov = true
                            onExited:  powerCard.hov = false
                            onClicked: {
                                root._activePanel = "power"
                                if (root._fanProfiles.length === 0)
                                    fanProfilesProc.running = true
                            }
                        }
                    }

                    // ── Audio — dispositivos ──────────────────────────────
                    Rectangle {
                        id: audioCard2
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._activePanel === "audio"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._activePanel === "audio"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: root._activePanel === "audio" ? 14 : 10
                                rightMargin: 10
                            }
                            spacing: 8

                            Text { text: "󰕾"; font.pixelSize: 18; color: Theme.accent }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Audio"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                Text {
                                    width: parent.width
                                    text: {
                                        var sink = root.defaultSink
                                        if (!sink) return "No output"
                                        return root._audioFormatDesc(sink.description, sink.name ?? "")
                                    }
                                    font.pixelSize: 9; color: Theme.muted1; elide: Text.ElideRight
                                }
                            }

                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: audioCard2.hov = true
                            onExited:  audioCard2.hov = false
                            onClicked: {
                                root._activePanel = "audio"
                                root.loadAudioDevices()
                            }
                        }
                    }

                    // ── Battery — UPower ──────────────────────────────────
                    Rectangle {
                        id: batCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._activePanel === "battery"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._activePanel === "battery"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: root._activePanel === "battery" ? 14 : 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                text: {
                                    if (!root._batAvailableUP) return "󰂑"
                                    if (root._batFullUP)       return "󰁹"
                                    if (root._batChargingUP)   return "󰂄"
                                    var p = root._batPctUP
                                    if (p > 80) return "󰁹"
                                    if (p > 60) return "󰂁"
                                    if (p > 40) return "󰁿"
                                    if (p > 20) return "󰁽"
                                    return "󰂃"
                                }
                                font.pixelSize: 18
                                color: {
                                    if (!root._batAvailableUP)  return Theme.muted2
                                    if (root._batChargingUP || root._batFullUP) return Theme.success
                                    if (root._batPctUP > 50)    return Theme.accent
                                    if (root._batPctUP > 20)    return Theme.yellow
                                    return Theme.error
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Battery"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                                Text {
                                    text: {
                                        if (!root._batAvailableUP) return "Not available"
                                        var pct = Math.round(root._batPctUP) + "%"
                                        if (root._batFullUP)     return "Full"
                                        if (root._batChargingUP) {
                                            var tf = root._fmtTime(root._batTimeFull)
                                            return pct + " · Charging" + (tf ? " · " + tf : "")
                                        }
                                        var te = root._fmtTime(root._batTimeEmpty)
                                        return pct + (te ? " · " + te : "")
                                    }
                                    font.pixelSize: 9
                                    color: root._batPctUP <= 20 && !root._batChargingUP ? Theme.error : Theme.muted1
                                    elide: Text.ElideRight; width: parent.width
                                }
                            }

                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: batCard.hov = true
                            onExited:  batCard.hov = false
                            onClicked: root._activePanel = "battery"
                        }
                    }

                    // ── Language ──────────────────────────────────────────
                    Rectangle {
                        id: langCard
                        property bool hov: false
                        width: (parent.width - 6) / 2; height: 52; radius: 10
                        color: hov ? Theme.surface3
                             : (root._activePanel === "language"
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: root._activePanel === "language"
                            width: 3; height: 24; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: root._activePanel === "language" ? 14 : 10; rightMargin: 10 }
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

                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: langCard.hov = true
                            onExited:  langCard.hov = false
                            onClicked: {
                                root._activePanel = "language"
                                root.langRefresh()
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
                            property bool expanded: root._activePanel === modelData.key

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
                                    root._activePanel = (root._activePanel === k) ? "" : k
                                }
                            }
                        }
                    }
                }

                // CPU / RAM / GPU: detalle ahora en CcCpuPanel / CcRamPanel / CcGpuPanel (overlay)

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
                }

                Item {
                    width: parent.width
                    height: innerPlayer.height + 16

                    Rectangle {
                        id: innerPlayer
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                        height: 90; radius: 10; color: Theme.surface2

                        // ── Helper: formatear segundos → m:ss ─────────────
                        function fmtSec(sec) {
                            if (!sec || sec <= 0) return "0:00"
                            const s = Math.floor(sec)
                            const m = Math.floor(s / 60)
                            return m + ":" + String(s % 60).padStart(2, "0")
                        }

                        RowLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 10

                            // ── Artwork ───────────────────────────────────
                            Rectangle {
                                Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                Layout.alignment: Qt.AlignVCenter
                                radius: 8; color: Theme.surface3; clip: true
                                Image {
                                    id: ccArtwork
                                    anchors.fill: parent
                                    source: root.mprisPlayer?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !ccArtwork.visible
                                    text: "󰝚"; font.pixelSize: 22; color: Theme.muted2
                                }
                            }

                            // ── Info + barra + controles ──────────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                // Título + ícono de app
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            width: parent.width
                                            text: root.mprisPlayer?.trackTitle ?? "Sin reproductor"
                                            font.pixelSize: 12; font.weight: Font.DemiBold
                                            color: Theme.text; elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: root.mprisPlayer?.trackArtist ?? ""
                                            font.pixelSize: 10; color: Theme.muted1; elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: "󰓇"
                                        font.pixelSize: 14
                                        color: Theme.muted2
                                        visible: root.mprisPlayer !== null
                                    }
                                }

                                // Barra de progreso (solo visual)
                                Item {
                                    Layout.fillWidth: true
                                    height: 3

                                    property real progress: {
                                        const p = root.mprisPlayer
                                        if (!p || !p.lengthSupported || p.length <= 0) return 0
                                        return Math.max(0, Math.min(1, root.playerPos / p.length))
                                    }

                                    Rectangle {
                                        anchors.fill: parent; radius: 2
                                        color: Theme.surface3
                                    }
                                    Rectangle {
                                        width: parent.width * parent.progress
                                        height: parent.height; radius: 2
                                        color: Theme.accent
                                    }
                                }

                                // Tiempo | controles | duración
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: innerPlayer.fmtSec(root.playerPos)
                                        font.pixelSize: 9; color: Theme.muted2
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Controles
                                    Row {
                                        spacing: 2
                                        Repeater {
                                            model: [
                                                { icon: "󰒮", action: "prev" },
                                                { icon: root.mprisPlayer?.isPlaying ? "󰏤" : "󰐊", action: "play" },
                                                { icon: "󰒭", action: "next" }
                                            ]
                                            Rectangle {
                                                required property var modelData
                                                width: 24; height: 24; radius: 6
                                                color: pCtrlHov.containsMouse ? Theme.surface3 : "transparent"
                                                Behavior on color { ColorAnimation { duration: 80 } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.icon; font.pixelSize: 13; color: Theme.text
                                                }
                                                MouseArea {
                                                    id: pCtrlHov; anchors.fill: parent; hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const p = root.mprisPlayer
                                                        if (!p) return
                                                        if      (modelData.action === "prev") p.previous()
                                                        else if (modelData.action === "next") p.next()
                                                        else p.togglePlaying()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: innerPlayer.fmtSec(root.mprisPlayer?.length ?? 0)
                                        font.pixelSize: 9; color: Theme.muted2
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

    // ── Panel overlay (popups de detalle) ─────────────────────────────────
    CcPanelOverlay {
        anchors.fill: parent
        z: 200

        activePanel: root._activePanel

        // WiFi
        nmWifiDev:           root._nmWifiDev
        wifiRadioOn:         root._wifiRadioOn
        wifiScanning:        root._wifiScanning
        wifiWorking:         root._wifiWorking
        wifiStatusMsg:       root._wifiStatusMsg
        wifiSelectedIdx:     root._wifiSelectedIdx
        wifiPasswordByIndex: root._wifiPasswordByIndex
        wifiConnectedSsid:   root._wifiConnectedSsid
        ethConnected:        root._ethConnected
        ethIp:               root._ethIp
        ethSpeed:            root._ethSpeed
        wifiIp:              root._wifiIp
        wifiGateway:         root._wifiGateway
        wifiDns:             root._wifiDns
        wifiPwFetchResult:    root._wifiPwFetchResult
        wifiPwFetchResultIdx: root.wifiPwFetchResultIdx

        // Bluetooth
        btAdapter:     root._btAdapter
        btAvailable:   root._btAvailable
        btPwrd:        root._btPwrd
        btScanning:    root._btScanning
        btWorking:     root._btWorking
        btStatusMsg:   root._btStatusMsg
        btPairedList:  root._btPairedList
        btNearbyList:  root._btNearbyList
        btPairedCount: root._btPairedCount
        btNearbyCount: root._btNearbyCount
        btCodecData:   root._btCodecData

        // Audio
        audioSinks:   root.audioSinks
        audioSources: root.audioSources

        // Power
        fanProfiles: root._fanProfiles
        fanProfile:  SysData.fanProfile

        // Battery
        batAvailable:  root._batAvailableUP
        batPct:        root._batPctUP
        batCharging:   root._batChargingUP
        batFull:       root._batFullUP
        batHealth:     root._batHealthUP
        batCapWh:      root._batCapWhUP
        batEnergy:     root._batEnergyUP
        batChangeRate: root._batChangeRate
        batTimeEmpty:  root._batTimeEmpty
        batTimeFull:   root._batTimeFull

        // CPU
        cpuAvailable: SysData.cpuAvailable
        cpuPercent:   SysData.cpuPercent
        cpuTemp:      SysData.cpuTemp

        // RAM
        ramAvailable: SysData.ramAvailable
        ramPercent:   SysData.ramPercent
        ramUsedGb:    SysData.ramUsedGb
        ramTotalGb:   SysData.ramTotalGb
        ramAvailGb:   SysData.ramAvailGb
        swapPercent:  SysData.swapPercent

        // GPU
        gpuAvailable:   SysData.gpuAvailable
        gpuPercent:     SysData.gpuPercent >= 0 ? SysData.gpuPercent : 0
        gpuTemp:        SysData.gpuTemp
        gpuName:        SysData.gpuName
        gpuVramUsedMb:  SysData.gpuVramUsedMb
        gpuVramTotalMb: SysData.gpuVramTotalMb

        // Language
        filteredLayouts: root._filteredLayouts
        filteredLocales: root._filteredLocales
        langLayout:      root._langLayout
        langLocale:      root._langLocale
        langTab:         root._langTab
        langSearch:      root._langSearch

        // ── Signal handlers ───────────────────────────────────────────────
        onClosePanel: {
            if (root._activePanel === "bluetooth") {
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
            root._activePanel = ""
        }

        // WiFi
        onWifiToggleRadio:    root.wifiToggleRadio()
        onWifiRescan:         root.wifiRescan()
        onWifiConnectKnown: (net) => root.wifiConnectKnown(net)
        onWifiConnectNew: (ssid, pw) => root.wifiConnectNew(ssid, pw)
        onWifiDisconnect: (net) => root.wifiDisconnect(net)
        onWifiForget: (net) => root.wifiForget(net)
        onWifiFetchPassword: (ssid, idx) => root.wifiFetchPasswordFor(ssid, idx)
        onWifiCopyPassword: (ssid) => root.wifiCopyPassword(ssid)
        onWifiSelectIdx: (idx) => { root._wifiSelectedIdx = idx }
        onWifiPasswordChanged: (idx, pw) => {
            var copy = Object.assign({}, root._wifiPasswordByIndex)
            copy[idx] = pw
            root._wifiPasswordByIndex = copy
        }

        // Bluetooth
        onBtTogglePower:  root.btTogglePower()
        onBtToggleScan:   root.btToggleScan()
        onBtConnect: (d)  => root.btConnectDevice(d)
        onBtDisconnect: (d) => root.btDisconnectDevice(d)
        onBtPair: (d)     => root.btPairDevice(d)
        onBtForget: (d)   => root.btForgetDevice(d)
        onBtSetCodec: (mac, prof) => root.btSetCodec(mac, prof)

        // Audio
        onAudioSetDefaultSink: (e)  => root.setDefaultSink(e)
        onAudioSetDefaultSource: (e) => root.setDefaultSource(e)

        // Power
        onPowerSetProfile: (p) => root.setPower(p)

        // Language
        onLangSelectTab: (tab) => {
            root._langTab           = tab
            root._langSearchPending = ""
            root._langSearch        = ""
            _langSearchDebounce.stop()
        }
        onLangSearchQuery: (q) => {
            root._langSearchPending = q
            _langSearchDebounce.restart()
        }
        onLangSetLayout: (code) => {
            var cmd = "hyprctl keyword input:kb_layout " + code +
                      " 2>/dev/null && sleep 0.4 && hyprctl dispatch switchxkblayout all 0"
            langSetProc.command = ["sh", "-c", cmd]
            if (!langSetProc.running) langSetProc.running = true
            root._langLayout = code
        }
        onLangSetLocale: (value) => {
            langSetLocaleProc.command = ["sh", "-c",
                "localectl set-locale LANG=" + value + " 2>/dev/null"]
            if (!langSetLocaleProc.running) langSetLocaleProc.running = true
            root._langLocale = value
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

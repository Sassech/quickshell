// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound

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

    // ── Mensajes de estado Bluetooth ──────────────────────────────────────
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
    property var    _cpuCoreTemps: []
    property int    _cpuNcores:    0
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

    PwObjectTracker { objects: [root.defaultSink, root.defaultSource, root._activeSink, root._activeSource] }

    // Pipewire.defaultAudioSink/defaultSource no cambian de forma confiable al
    // usar preferredDefaultAudioSink/Source, así que trackeamos nosotrxs el
    // nodo y nombre activos para highlight, volumen, mute y bindings.
    property var    _activeSink:        defaultSink
    property var    _activeSource:      defaultSource
    property string _activeSinkName:    defaultSink?.name   ?? ""
    property string _activeSourceName:  defaultSource?.name ?? ""

    // Volumen/mute bindeados al nodo activo (no al default de Pipewire)
    property real masterVolume: root._activeSink?.audio?.volume   ?? 0.75
    property bool masterMuted:  root._activeSink?.audio?.muted    ?? false
    property real micVolume:    root._activeSource?.audio?.volume ?? 0.75
    property bool micMuted:     root._activeSource?.audio?.muted  ?? false

    // Sincronizar tracking cuando Pipewire avisa de un cambio real
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root._pwRev++
            if (root.defaultSink?.name) {
                root._activeSink     = root.defaultSink
                root._activeSinkName = root.defaultSink.name
            }
        }
        function onDefaultAudioSourceChanged() {
            root._pwRev++
            if (root.defaultSource?.name) {
                root._activeSource     = root.defaultSource
                root._activeSourceName = root.defaultSource.name
            }
        }
    }

    // Volumen/mute del sink activo
    Connections {
        target: root._activeSink?.audio ?? null
        function onVolumesChanged() {
            const v = root._activeSink?.audio?.volume
            if (v !== undefined && !isNaN(v)) root.masterVolume = v
        }
        function onMutedChanged() {
            const m = root._activeSink?.audio?.muted
            if (m !== undefined) root.masterMuted = m
        }
    }

    // Volumen/mute del source activo
    Connections {
        target: root._activeSource?.audio ?? null
        function onVolumesChanged() {
            const v = root._activeSource?.audio?.volume
            if (v !== undefined && !isNaN(v)) root.micVolume = v
        }
        function onMutedChanged() {
            const m = root._activeSource?.audio?.muted
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
        _pwRev; _audioSinkAvail; root._activeSinkName
        if (!root.visible || root._activePanel !== "audio") return []
        var activeName = root._activeSinkName || root.defaultSink?.name || ""
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
        _pwRev; _audioSourceAvail; root._activeSourceName
        if (!root.visible || root._activePanel !== "audio") return []
        var activeName = root._activeSourceName || root.defaultSource?.name || ""
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
        // Pipewire.defaultAudioSink no se actualiza de forma confiable; usar
        // nuestro propio tracking para highlight, volumen y mute.
        root._activeSink     = entry.node
        root._activeSinkName = entry.id
        // API nativa para cambiar el sink default
        Pipewire.preferredDefaultAudioSink = entry.node
        root._pwRev++
        // Mover streams activos al nuevo sink (no expuesto por API)
        var safe = entry.id.replace(/'/g, "'\\''")
        _audioMoveSinkProc.command = ["bash", "-c",
            "pactl list short sink-inputs | awk '{print $1}' | " +
            "xargs -r -I{} pactl move-sink-input {} '" + safe + "' 2>/dev/null"]
        _audioMoveSinkProc.running = true
    }

    function setDefaultSource(entry) {
        if (!entry.node) return
        // Pipewire.defaultAudioSource no se actualiza de forma confiable.
        root._activeSource     = entry.node
        root._activeSourceName = entry.id
        Pipewire.preferredDefaultAudioSource = entry.node
        root._pwRev++
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
        // qmllint disable signal-handler-parameters
        onExited: {
            try {
                var data = JSON.parse(root._audioSinkBuf)
                var map = ({})
                var activeName = root.defaultSink?.name ?? ""
                for (var i = 0; i < data.length; i++) {
                    var s = data[i]; var name = s.name || ""; if (!name) continue
                    var ports = s.ports || []
                    var ok = true
                    if (ports.length > 0) {
                        ok = false
                        for (var p = 0; p < ports.length; p++) {
                            var port = ports[p]
                            var av = (port.availability || "").toString().toLowerCase()
                            var ptype = (port.type || "").toString().toLowerCase()
                            // Solo HDMI/DisplayPort dependen de un cable físico real —
                            // el resto (Headphones/Speaker combo-jack) puede marcar
                            // "not available" por jack-sense y aun así seguir sonando
                            // por el parlante interno (auto-switch hecho por firmware).
                            var requiresCable = (ptype === "hdmi" || ptype === "displayport")
                            if (!requiresCable || av !== "not available") { ok = true; break }
                        }
                    }
                    // Nunca ocultar el sink activo ahora mismo, sea cual sea su jack-sense.
                    if (name === activeName) ok = true
                    map[name] = ok
                }
                root._audioSinkAvail = map
                root._pwRev++
            } catch(e) {}
            root._audioSinkBuf = ""
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: _audioSourceAvailProc
        command: ["bash", "-c", "LANG=C pactl --format=json list sources 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._audioSourceBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
        onExited: {
            try {
                var data = JSON.parse(root._audioSourceBuf)
                var map = ({})
                var activeName = root.defaultSource?.name ?? ""
                for (var i = 0; i < data.length; i++) {
                    var s = data[i]; var name = s.name || ""
                    if (!name || name.endsWith(".monitor")) continue
                    var ports = s.ports || []
                    var ok = true
                    if (ports.length > 0) {
                        ok = false
                        for (var p = 0; p < ports.length; p++) {
                            var port = ports[p]
                            var av = (port.availability || "").toString().toLowerCase()
                            var ptype = (port.type || "").toString().toLowerCase()
                            // Mismo criterio que en sinks: solo HDMI/DisplayPort
                            // dependen de un cable físico real.
                            var requiresCable = (ptype === "hdmi" || ptype === "displayport")
                            if (!requiresCable || av !== "not available") { ok = true; break }
                        }
                    }
                    // Nunca ocultar la fuente activa ahora mismo.
                    if (name === activeName) ok = true
                    map[name] = ok
                }
                root._audioSourceAvail = map
                root._pwRev++
            } catch(e) {}
            root._audioSourceBuf = ""
        }
        // qmllint enable signal-handler-parameters
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

    // Bluetooth.devices expone SOLO los dispositivos actualmente conectados (doc oficial)
    // Más preciso y reactivo que iterar _btPairedList manualmente
    property int btConnectedCount: Bluetooth.devices.values.length

    readonly property string btFirstConnectedName: {
        const devs = Bluetooth.devices.values
        if (devs.length === 0) return ""
        const d = devs[0]
        return d.name || d.deviceName || d.address || ""
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
        running: root.visible && (root.mprisPlayer?.isPlaying ?? false)
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
        // qmllint disable signal-handler-parameters
        onExited: {
            var v = parseInt(root._buf.trim())
            root._buf = ""
            if (!isNaN(v)) { root.brightness = v; root._brightnessReady = true }
        }
        // qmllint enable signal-handler-parameters
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
        if (root._activeSink?.audio) root._activeSink.audio.volume = v
    }

    function setMicVol(v) {
        root.micVolume = v
        if (root._activeSource?.audio) root._activeSource.audio.volume = v
    }

    function toggleMasterMute() {
        if (root._activeSink?.audio) {
            root._activeSink.audio.muted = !root._activeSink.audio.muted
        }
    }

    function toggleMicMute() {
        if (root._activeSource?.audio) {
            root._activeSource.audio.muted = !root._activeSource.audio.muted
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
        // btAdapter.devices es el ObjectModel completo — sin necesidad de _btDevices
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
        // Usar _btAdapter.devices.values directamente — source of truth sin cache intermedio
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
        onTriggered: { if (root._btWorking) root.btResetAction(root._btMsgTimeout) }
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
            root._btSawConnecting = false
            root._btWorking = true   // garantizar spinner activo durante el reintento
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
        interval: 30000; repeat: true
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
        function onObjectInsertedPost(object, index) {
            btRefreshDebounce.restart()
        }
        function onObjectRemovedPost(object, index) {
            btRefreshDebounce.restart()
            // La detección de forget debe ser inmediata — antes de que el objeto desaparezca
            if (root._btActionType === "forget" && root._btActionDevice === object)
                root.btResetAction(root._btMsgForgotten)
        }
    }

    Instantiator {
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

    Connections {
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
        // qmllint disable signal-handler-parameters
        onExited: {
            var output = root._btCodecBuf.trim()
            root._btCodecBuf = ""
            try {
                var data = JSON.parse(output)
                var mac  = root._btCurrentCodecMac.toUpperCase()
                root._btCodecData[mac] = data
                root._btCodecDataChanged()
            } catch(e) {}
            root.btRunNextCodecQuery()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: btSetCodecProc
        command: ["bash", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: function(ec) {
            root._btStatusMsg = ec === 0 ? root._btMsgCodecOk : root._btMsgCodecErr
            Qt.callLater(() => root.btRunNextCodecQuery())
        }
        // qmllint enable signal-handler-parameters
    }

    // ── WiFi functions ────────────────────────────────────────────────────
    function _wifiIsNormalDisconnectReason(reason) {
        // qmllint disable unqualified
        return reason === NMConnectionStateReason.None
            || reason === NMConnectionStateReason.UserDisconnected
            || reason === NMConnectionStateReason.DeviceDisconnected
        // qmllint enable unqualified
    }

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
        root._wifiStatusMsg = ""   // el spinner (wifiWorking) muestra el progreso; el msg queda para el resultado
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
        root._wifiStatusMsg = ""   // el spinner muestra el progreso
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
        // qmllint disable signal-handler-parameters
        onExited: {
            var lines = root._wEthBuf.trim().split("\n")
            root._wEthBuf = ""
            root._ethConnected = (lines[0] || "").trim() === "connected"
            root._ethIp    = (lines[1] || "").trim()
            root._ethSpeed = (lines[2] || "").trim()
        }
        // qmllint enable signal-handler-parameters
    }

    // Connect new network with password
    Process {
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
        // qmllint disable signal-handler-parameters
        onExited: {
            var lines = wWifiInfoProc._buf.trim().split("\n")
            wWifiInfoProc._buf = ""
            root._wifiIp      = (lines[0] || "").split("/")[0].trim()
            root._wifiGateway = (lines[1] || "").trim()
            root._wifiDns     = (lines[2] || "").trim()
        }
        // qmllint enable signal-handler-parameters
    }

    // Reveal saved PSK (nmcli -s)
    Process {
        id: wSharedPwFetchProc
        property string _buf: ""
        command: ["bash", "-c", ""]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => wSharedPwFetchProc._buf += d }
        // qmllint disable signal-handler-parameters
        onExited: {
            var pw = wSharedPwFetchProc._buf.trim()
            wSharedPwFetchProc._buf = ""
            ccPanelOverlay.wifiPasswordFetched(root._wifiPwFetchIdx, pw)
        }
        // qmllint enable signal-handler-parameters
    }

    // Copy password to clipboard (nmcli -s → wl-copy)
    Process {
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

    Process {
        id: wMenuCopyExecProc
        command: ["bash", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: (ec) => {
            root._wifiStatusMsg = ec === 0 ? "✓ Contraseña copiada" : "✗ wl-copy error " + ec
        }
        // qmllint enable signal-handler-parameters
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
        height: Math.min(parent.height - 72, Math.max(scrollContent.implicitHeight + 24, 100))
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
            contentHeight: scrollContent.implicitHeight
            clip: true
            boundsMovement: Flickable.StopAtBounds

            Column {
                id: scrollContent
                width: ccFlick.width
                spacing: 0

                // ── POWER BAR ─────────────────────────────────────────────
                CcPowerBar {
                    width: parent.width
                    onShowConfirm: (label, cmd) => {
                        root._confirmLabel = label
                        root._confirmCmd   = cmd
                        root._showConfirm  = true
                    }
                    onRunCmd: cmd => {
                        root.visible = false
                        ccExecProc.runCmd(cmd)
                    }
                    onClose: root.visible = false
                }

                // ── SEPARADOR ──────────────────────────────────────────────
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
                Item { width: parent.width; height: 8 }

                // ══════════════════════════════════════════════════════════
                // SECCIÓN 1 — Sliders de audio y brillo
                // ══════════════════════════════════════════════════════════

                // ── Sliders audio + brillo ────────────────────────────────
                CcSliders {
                    width: parent.width
                    masterVolume: root.masterVolume
                    masterMuted:  root.masterMuted
                    micVolume:    root.micVolume
                    micMuted:     root.micMuted
                    brightness:   root.brightness
                    onSetMasterVolume: v => root.setMasterVolume(v)
                    onToggleMasterMute: root.toggleMasterMute()
                    onSetMicVol: v => root.setMicVol(v)
                    onToggleMicMute: root.toggleMicMute()
                    onSetBrightness: v => root.setBrightness(v)
                }

                // ── Apps de audio — header colapsable ──────────────────────
                Item { width: parent.width; height: 8 }
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }



                // ── Controles rápidos ─────────────────────────────────────
                CcQuickToggles {
                    width: parent.width
                    activePanel:          root._activePanel
                    btAdapter:            root.btAdapter
                    btPowered:            root.btPowered
                    btConnectedCount:     root.btConnectedCount
                    btFirstConnectedName: root.btFirstConnectedName
                    batAvailable:         root._batAvailableUP
                    batPct:               root._batPctUP
                    batCharging:          root._batChargingUP
                    batFull:              root._batFullUP
                    batTimeFull:          root._batTimeFull
                    batTimeEmpty:         root._batTimeEmpty
                    defaultSink:          root.defaultSink
                    langLayout:           root._langLayout
                    langLocale:           root._langLocale
                    powerLabelFn:         root._powerLabel
                    powerIconFn:          root._powerIcon
                    fmtTimeFn:            root._fmtTime
                    audioFormatDescFn:    root._audioFormatDesc

                    onOpenWifi: {
                        root._activePanel         = "wifi"
                        root._wifiStatusMsg       = ""
                        root._wifiSelectedIdx     = -1
                        root._wifiPasswordByIndex = ({})
                        wEthProc.running          = true
                        wWifiInfoProc.running     = root._wifiConnectedNet !== null
                        if (root._nmWifiDev && root._wifiRadioOn)
                            root._nmWifiDev.scannerEnabled = true
                    }
                    onOpenBluetooth: {
                        root._activePanel = "bluetooth"
                        root._btStatusMsg = ""
                        root.btRefreshDeviceLists()
                        if (root._btPwrd && root._btAdapter) {
                            root._btAdapter.discoverable = true
                            root.btAutoConnectTrusted()
                        }
                    }
                    onOpenPower: {
                        root._activePanel = "power"
                        if (root._fanProfiles.length === 0)
                            fanProfilesProc.running = true
                    }
                    onOpenAudio: {
                        root._activePanel = "audio"
                        root.loadAudioDevices()
                    }
                    onOpenBattery: root._activePanel = "battery"
                    onOpenLanguage: {
                        root._activePanel = "language"
                        root.langRefresh()
                    }
                }

                // ── Métricas del sistema ──────────────────────────────────
                CcSystemSection {
                    width: parent.width
                    activePanel: root._activePanel
                    diskPct:    root._diskPct
                    diskUsed:   root._diskUsed
                    diskTotal:  root._diskTotal
                    homePct:    root._homePct
                    homeUsed:   root._homeUsed
                    homeTotal:  root._homeTotal
                    onTogglePanel: function(key) {
                        root._activePanel = (root._activePanel === key) ? "" : key
                    }
                }

                // ── Media player ──────────────────────────────────────────
                CcMediaPlayer {
                    width: parent.width
                    mprisPlayer: root.mprisPlayer
                    playerPos:   root.playerPos
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
        id: ccPanelOverlay
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
        cpuAvailable:   SysData.cpuAvailable
        cpuPercent:     SysData.cpuPercent
        cpuTemp:        SysData.cpuTemp
        cpuModel:       root._cpuModel
        cpuAvgFreq:     root._cpuAvgFreq
        cpuGov:         root._cpuGov
        cpuNcores:      root._cpuNcores
        cpuCorePcts:    root._cpuCorePcts
        cpuCoreTemps:   root._cpuCoreTemps
        cpuLoaded:      root._cpuLoaded

        // RAM
        ramAvailable: SysData.ramAvailable
        ramPercent:   SysData.ramPercent
        ramUsedGb:    SysData.ramUsedGb
        ramTotalGb:   SysData.ramTotalGb
        ramAvailGb:   SysData.ramAvailGb
        ramCacheGb:   SysData.ramCacheGb
        ramAppsGb:    SysData.ramAppsGb
        swapPercent:  SysData.swapPercent
        swapTotalGb:  SysData.swapTotalGb
        swapFreeGb:   SysData.swapFreeGb

        // GPU — array completo del detail process + flag de carga
        gpus:       root._gpus
        gpuLoaded:  root._gpuLoaded

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
        onWifiStatusMessage: (msg) => { root._wifiStatusMsg = msg }
        onWifiPasswordChanged: (idx, pw) => {
            root._wifiPasswordByIndex[idx] = pw
            root._wifiPasswordByIndexChanged()
        }

        // Bluetooth
        onBtTogglePower:  root.btTogglePower()
        onBtToggleScan:   root.btToggleScan()
        onBtConnect: (d)      => root.btConnectDevice(d)
        onBtDisconnect: (d)   => root.btDisconnectDevice(d)
        onBtPair: (d)         => root.btPairDevice(d)
        onBtCancelPair: (d)   => { if (d) d.cancelPair() }
        onBtForget: (d)       => root.btForgetDevice(d)
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
            // Use array form to avoid shell injection and pass the layout name safely.
            // hyprctl keyword input:kb_layout expects an XKB layout identifier (e.g. "es", "us", "latam").
            // After setting, reload the config so Hyprland picks it up cleanly.
            langSetProc.command = ["hyprctl", "keyword", "input:kb_layout", code]
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
        // qmllint disable signal-handler-parameters
        onExited: running = false
        // qmllint enable signal-handler-parameters
    }

    // ── CPU detail process ────────────────────────────────────────────────
    Process {
        id: cpuDetailProc
        command: ["bash", Paths.scripts + "/cpu-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._cpuBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
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
            if (kv["CORE_PCTS"])   root._cpuCorePcts   = kv["CORE_PCTS"].split(",").map(function(s) { return parseInt(s) || 0 })
            if (kv["CORE_TEMPS"])  root._cpuCoreTemps  = kv["CORE_TEMPS"].split(",").map(function(s) { return parseInt(s) || 0 })
            if (kv["NCORES"])      root._cpuNcores     = parseInt(kv["NCORES"]) || 0
            root._cpuLoaded = true
        }
        // qmllint enable signal-handler-parameters
    }

    // Refrescar CPU mientras el panel esté abierto
    Timer {
        interval: 1500; repeat: true
        running: root.visible && root._activePanel === "cpu"
        onTriggered: { root._cpuBuf = ""; cpuDetailProc.running = true }
        onRunningChanged: {
            // Primera ejecución inmediata al abrir el panel
            if (running) { root._cpuBuf = ""; cpuDetailProc.running = true }
        }
    }

    // ── GPU detail process — multi-vendor parser ──────────────────────────
    Process {
        id: gpuDetailProc
        command: ["bash", Paths.scripts + "/gpu-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._gpuBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
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
                // Para Intel: freq activa puede ser 0 (idle) → usar cur como fallback
                var freqAct = parseInt(kv[p + "FREQ"]) || 0
                var freqCur = parseInt(kv[p + "FREQ_CUR"]) || 0
                var obj = {
                    vendor:      vendor,
                    name:        kv[p + "NAME"]   || "",
                    status:      kv[p + "STATUS"] || "active",
                    util:        parseInt(kv[p + "UTIL"])        || 0,
                    temp:        parseInt(kv[p + "TEMP"])        || parseInt(kv[p + "TEMP_EDGE"]) || 0,
                    tempJun:     parseInt(kv[p + "TEMP_JUN"])    || 0,
                    freq:        freqAct > 0 ? freqAct : freqCur,
                    freqMem:     parseInt(kv[p + "FREQ_MEM"])    || 0,
                    freqMax:     parseInt(kv[p + "FREQ_MAX"])    || 0,
                    freqMin:     parseInt(kv[p + "FREQ_MIN"])    || 0,
                    power:       parseFloat(kv[p + "POWER"])     || 0,
                    powerLimit:  parseFloat(kv[p + "POWER_LIMIT"]) || 0,
                    vramUsed:    parseInt(kv[p + "VRAM_USED"])   || 0,
                    vramTotal:   parseInt(kv[p + "VRAM_TOTAL"])  || 0,
                    driver:      kv[p + "DRIVER"]       || "",
                    rc6:         parseInt(kv[p + "RC6"]) || 0,
                    throttle:    parseInt(kv[p + "THROTTLE"]) || 0,
                    powerState:  kv[p + "POWER_STATE"]  || ""
                }
                list.push(obj)
            }
            root._gpus = list
            root._gpuLoaded = true
        }
        // qmllint enable signal-handler-parameters
    }

    Timer {
        interval: 1500; repeat: true
        running: root.visible && root._activePanel === "gpu"
        onTriggered: { root._gpuBuf = ""; gpuDetailProc.running = true }
        onRunningChanged: {
            if (running) { root._gpuBuf = ""; gpuDetailProc.running = true }
        }
    }

    // ── Fan profiles process — reads available profiles dynamically ────────
    Process {
        id: fanProfilesProc
        command: ["bash", Paths.scripts + "/fan-control.sh", "list_profiles"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._fanBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
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
        // qmllint enable signal-handler-parameters
    }

    // Fan apply process
    Process {
        id: fanApplyProc
        running: false
        // qmllint disable signal-handler-parameters
        onExited: running = false
        // qmllint enable signal-handler-parameters
    }

    // ── Language processes ────────────────────────────────────────────────
    // Current layout from Hyprland — reads the XKB layout code (e.g. "es", "us")
    // via getoption so it matches the identifiers in list-x11-keymap-layouts.
    Process {
        id: langCurrentProc
        command: ["sh", "-c",
            "hyprctl getoption input:kb_layout 2>/dev/null | awk '/^str:/{print $2}'"]
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

    // Available layouts from localectl (X11/XKB layouts — the ones Hyprland understands)
    Process {
        id: langLayoutProc
        command: ["sh", "-c", "timeout 3s localectl list-x11-keymap-layouts 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._langBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
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
        // qmllint enable signal-handler-parameters
    }

    // Apply layout via Hyprland — command is set dynamically before running
    Process {
        id: langSetProc
        command: ["hyprctl", "keyword", "input:kb_layout", ""]
        // qmllint disable signal-handler-parameters
        onExited: Qt.callLater(() => langCurrentProc.running = true)
        // qmllint enable signal-handler-parameters
    }

    // Available locales from localectl
    Process {
        id: langLocaleListProc
        command: ["sh", "-c", "timeout 3s localectl list-locales 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._langLocaleBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
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
        // qmllint enable signal-handler-parameters
    }

    // Apply locale via localectl
    Process {
        id: langSetLocaleProc
        command: ["sh", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: langLocaleProc.running = true
        // qmllint enable signal-handler-parameters
    }

    // ── Disk detail process (root + home) ─────────────────────────────────
    Process {
        id: diskDetailProc
        command: ["bash", Paths.scripts + "/disk-detail.sh"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._diskBuf += d + "\n" }
        // qmllint disable signal-handler-parameters
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
        // qmllint enable signal-handler-parameters
    }

}

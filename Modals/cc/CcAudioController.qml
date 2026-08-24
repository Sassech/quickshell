// Controlador de audio — Pipewire API nativa + pactl para disponibilidad de puertos
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../Components"

QtObject {
    id: root

    // Props requeridas: gate para computed sinks/sources
    required property bool panelVisible
    required property bool panelActive

    property var defaultSink:   Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource

    property var _pwTracker: PwObjectTracker { objects: [root.defaultSink, root.defaultSource, root._activeSink, root._activeSource] }

    // Pipewire.defaultAudioSink/defaultSource no cambian de forma confiable al usar preferredDefaultAudioSink/Source — trackeamos nosotros el nodo
    // y nombre activos para highlight, volumen, mute y bindings.
    property var    _activeSink:       defaultSink             // binding declarativo puro
    property var    _activeSource:     defaultSource           // binding declarativo puro
    // computed — se re-evalúan cuando defaultSink/defaultSource cambian
    // (no readonly: setDefaultSink/setDefaultSource asignan imperativamente al seleccionar)
    property string _activeSinkName:   defaultSink?.name   ?? ""
    property string _activeSourceName: defaultSource?.name ?? ""

    property real masterVolume: root._activeSink?.audio?.volume   ?? 0.75
    property bool masterMuted:  root._activeSink?.audio?.muted    ?? false
    property real micVolume:    root._activeSource?.audio?.volume ?? 0.75
    property bool micMuted:     root._activeSource?.audio?.muted  ?? false

    // Sincronizar tracking cuando Pipewire avisa de un cambio real
    property var _pwConnections: Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged()   { root._pwRev++ }
        function onDefaultAudioSourceChanged() { root._pwRev++ }
    }

    // Audio state
    property int _pwRev: 0   // bump en cambios de sinks/sources/visibilidad

    // Audio device lists (sinks / sources)
    property var _audioSinkAvail:   ({})   // { nodeName: bool }
    property var _audioSourceAvail: ({})

    // Combo-jack: tarjetas donde Speaker y Headphones son perfiles ALSA
    // mutuamente excluyentes (no puertos del mismo sink).
    property var _audioComboCards:  []     // [{ name, activeProfile, profiles: [{name, priority, available}] }]

    property string _pendingSinkToken:   ""   // "speaker" | "headphones"
    property int    _pendingSinkRetries: 0

    // Computed: lista de sinks disponibles
    // Gate: solo escanea cuando el panel de audio está activo y visible
    property var audioSinks: {
        _pwRev; _audioSinkAvail; root._activeSinkName; root._audioComboCards
        if (!root.panelVisible || !root.panelActive) return []
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

        // Combo-jack: Speaker y Headphones son perfiles ALSA excluyentes en este hardware, no puertos simultáneos del mismo sink. Si el perfil activo
        // no expone uno de los dos como nodo real, lo agregamos como entrada "virtual": al hacer click dispara un cambio de perfil de tarjeta.
        var wants = [
            { token: "speaker",    icon: "󰕾", label: "Altavoces" },
            { token: "headphones", icon: "󰋋", label: "Audífonos" }
        ]
        for (var ci = 0; ci < root._audioComboCards.length; ci++) {
            var card = root._audioComboCards[ci]
            for (var w = 0; w < wants.length; w++) {
                var token = wants[w].token
                var hasLiveNode = false
                for (var oi = 0; oi < out.length; oi++) {
                    if (out[oi].id.toLowerCase().indexOf(token) !== -1) { hasLiveNode = true; break }
                }
                if (hasLiveNode) continue
                var targetProfile = root._pickBestProfile(card, token)
                if (!targetProfile) continue
                out.push({
                    id: "virtual:" + card.name + ":" + token,
                    label: wants[w].label,
                    icon: wants[w].icon,
                    active: false,
                    node: null,
                    virtual: true,
                    cardName: card.name,
                    targetProfile: targetProfile,
                    targetToken: token
                })
            }
        }

        return out
    }

    // Computed: lista de sources disponibles
    property var audioSources: {
        _pwRev; _audioSourceAvail; root._activeSourceName
        if (!root.panelVisible || !root.panelActive) return []
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

    // Helpers de ícono y descripción
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

    // Tokens entre paréntesis de un nombre de perfil ALSA
    function _profileTokens(name) {
        if (!name) return []
        var m = name.match(/\(([^)]*)\)/)
        if (!m) return []
        return m[1].split(",").map(function(s) { return s.trim() })
    }

    // Entre los perfiles que incluyen `wantedToken`, elegir el mejor
    function _pickBestProfile(card, wantedToken) {
        var activeTokens = root._profileTokens(card.activeProfile).map(function(t) { return t.toLowerCase() })
        var best = null
        var bestScore = -1
        for (var i = 0; i < card.profiles.length; i++) {
            var p = card.profiles[i]
            if (!p.available) continue
            var tokens = root._profileTokens(p.name).map(function(t) { return t.toLowerCase() })
            if (tokens.indexOf(wantedToken) === -1) continue
            var score = 0
            for (var t = 0; t < tokens.length; t++) {
                if (tokens[t] !== wantedToken && activeTokens.indexOf(tokens[t]) !== -1) score++
            }
            if (score > bestScore || (score === bestScore && (!best || p.priority > best.priority))) {
                best = p
                bestScore = score
            }
        }
        return best ? best.name : null
    }

    // Funciones de control de volumen
    function setMasterVolume(v) {
        if (root._activeSink?.audio) root._activeSink.audio.volume = v
    }

    function setMicVol(v) {
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

    // Cambiar sink default
    function setDefaultSink(entry) {
        if (entry.virtual) {
            root._pendingSinkToken   = entry.targetToken
            root._pendingSinkRetries = 0
            var safeCard    = entry.cardName.replace(/'/g, "'\\''")
            var safeProfile = entry.targetProfile.replace(/'/g, "'\\''")
            _audioProfileSwitchProc.command = ["bash", "-c",
                "pactl set-card-profile '" + safeCard + "' '" + safeProfile + "' 2>/dev/null"]
            _audioProfileSwitchProc.running = true
            return
        }
        if (!entry.node) return
        root._activeSink     = entry.node
        root._activeSinkName = entry.id
        Pipewire.preferredDefaultAudioSink = entry.node
        root._pwRev++
        var safe = entry.id.replace(/'/g, "'\\''")
        _audioMoveSinkProc.command = ["bash", "-c",
            "pactl list short sink-inputs | awk '{print $1}' | " +
            "xargs -r -I{} pactl move-sink-input {} '" + safe + "' 2>/dev/null"]
        _audioMoveSinkProc.running = true
    }

    // Cambiar source default
    function setDefaultSource(entry) {
        if (!entry.node) return
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

    // Debounce para colapsar llamadas rápidas en un solo batch
    property bool _audioDevLoadPending: false
    property var _audioDevDebounce: Timer {
        id: _audioDevDebounce
        interval: 500
        repeat: false
        onTriggered: {
            root._audioDevLoadPending = false
            _audioSinkAvailProc.running   = true
            _audioSourceAvailProc.running = true
            _audioCardsProc.running       = true
        }
    }

    // Cargar disponibilidad de dispositivos
    function loadAudioDevices() {
        if (root._audioDevLoadPending) return
        root._audioDevLoadPending = true
        _audioDevDebounce.restart()
    }

    // Aplicar pending sink switch tras profile change
    function _applyPendingSinkSwitch() {
        if (!root._pendingSinkToken) return
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var node = all[i]
            if (!node || !node.isSink || node.isStream) continue
            var name = (node.name || "").toLowerCase()
            if (name.indexOf(root._pendingSinkToken) !== -1) {
                root._pendingSinkToken   = ""
                root._pendingSinkRetries = 0
                root.setDefaultSink({ id: node.name, node: node })
                return
            }
        }
        if (root._pendingSinkRetries < 5) {
            root._pendingSinkRetries++
            _pendingSinkApplyTimer.restart()
        } else {
            root._pendingSinkToken   = ""
            root._pendingSinkRetries = 0
        }
    }

    // Fetch port availability (pactl)
    property var _audioSinkAvailProc: JsonProcess {
        id: _audioSinkAvailProc
        command: ["bash", "-c", "LANG=C pactl --format=json list sinks 2>/dev/null"]
        onParsed: data => {
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
                        // Solo HDMI/DisplayPort dependen de un cable físico real
                        var requiresCable = (ptype === "hdmi" || ptype === "displayport")
                        if (!requiresCable || av !== "not available") { ok = true; break }
                    }
                }
                // Nunca ocultar el sink activo ahora mismo
                if (name === activeName) ok = true
                map[name] = ok
            }
            root._audioSinkAvail = map
            root._pwRev++
        }
    }

    property var _audioSourceAvailProc: JsonProcess {
        id: _audioSourceAvailProc
        command: ["bash", "-c", "LANG=C pactl --format=json list sources 2>/dev/null"]
        onParsed: data => {
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
                        var requiresCable = (ptype === "hdmi" || ptype === "displayport")
                        if (!requiresCable || av !== "not available") { ok = true; break }
                    }
                }
                // Nunca ocultar la fuente activa ahora mismo
                if (name === activeName) ok = true
                map[name] = ok
            }
            root._audioSourceAvail = map
            root._pwRev++
        }
    }

    // Mover streams al nuevo sink/source
    property var _audioMoveSinkProc:   Process { id: _audioMoveSinkProc;   command: ["bash", "-c", ""] }
    property var _audioMoveSourceProc: Process { id: _audioMoveSourceProc; command: ["bash", "-c", ""] }

    // Detectar tarjetas combo-jack (Speaker/Headphones como perfiles ALSA)
    property var _audioCardsProc: JsonProcess {
        id: _audioCardsProc
        command: ["bash", "-c", "LANG=C pactl --format=json list cards 2>/dev/null"]
        onParsed: data => {
            var combos = []
            for (var i = 0; i < data.length; i++) {
                var c = data[i]
                var ports = c.ports || {}
                var hasSpeaker = false, hasHeadphones = false
                for (var portKey in ports) {
                    var t = (ports[portKey].type || "").toString().toLowerCase()
                    if (t === "speaker") hasSpeaker = true
                    if (t === "headphones") hasHeadphones = true
                }
                if (!hasSpeaker || !hasHeadphones) continue
                var profiles = []
                var pmap = c.profiles || {}
                for (var key in pmap) {
                    profiles.push({
                        name: key,
                        priority: pmap[key].priority || 0,
                        available: pmap[key].available !== false
                    })
                }
                combos.push({ name: c.name, activeProfile: c.active_profile || "", profiles: profiles })
            }
            root._audioComboCards = combos
            root._pwRev++
        }
    }

    // Cambiar perfil ALSA (combo-jack)
    property var _audioProfileSwitchProc: Process {
        id: _audioProfileSwitchProc
        command: ["bash", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: {
            root.loadAudioDevices()
            _pendingSinkApplyTimer.restart()
        }
        // qmllint enable signal-handler-parameters
    }

    // Timer: dar tiempo a PipeWire para enumerar el nodo del nuevo perfil
    property var _pendingSinkApplyTimer: Timer {
        id: _pendingSinkApplyTimer
        interval: 400
        repeat: false
        onTriggered: root._applyPendingSinkSwitch()
    }

    // Cargar dispositivos al activar el panel
    onPanelActiveChanged: {
        if (root.panelActive && root.panelVisible) root.loadAudioDevices()
    }
}

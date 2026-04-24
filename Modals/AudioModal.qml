import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
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
    property var    defaultSink:   Pipewire.defaultAudioSink
    property var    defaultSource: Pipewire.defaultAudioSource
    readonly property string defaultSinkName:   defaultSink?.name ?? ""
    readonly property string defaultSourceName: defaultSource?.name ?? ""
    property real   volume:        0.05
    property bool   muted:         false
    property string statusMsg:     ""
    property bool   showSources:   true
    property var    _sinkAvailable: ({})
    property var    _sourceAvailable: ({})
    property var    sinkVolumes: ({})
    property string _pendingSinkName: ""

    // ── Bind nodes — REQUIRED for .audio.volume/.muted to be valid ────────
    PwObjectTracker {
        objects: [root.defaultSink, root.defaultSource]
    }

    // ── Sync volume/mute from PipeWire (event-driven, NaN-safe) ───────────
    Connections {
        target: root.defaultSink?.audio ?? null
        function onVolumesChanged() {
            var v = root.defaultSink?.audio?.volume
            if (v !== undefined && v !== null && !isNaN(v)) {
                root.volume = v
                if (root.defaultSinkName !== "") {
                    var map = ({})
                    Object.assign(map, root.sinkVolumes)
                    map[root.defaultSinkName] = v
                    root.sinkVolumes = map
                }
            }
        }
        function onMutedChanged() {
            var m = root.defaultSink?.audio?.muted
            if (m !== undefined && m !== null) root.muted = m
        }
    }

    // ── Debounce volume slider writes via wpctl ───────────────────────────
    property real _pendingVol: -1
    Timer {
        id: volDebounce
        interval: 80
        onTriggered: {
            if (root._pendingVol >= 0) {
                var v = root._pendingVol.toFixed(2)
                root._pendingVol = -1
                var sinkName = root.defaultSinkName
                var safeSink = sinkName.replace(/'/g, "'\\''")
                setVolProc.command = ["bash", "-c",
                    (sinkName
                        ? "wpctl set-volume '" + safeSink + "' " + v + " 2>/dev/null"
                        : "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v + " 2>/dev/null")]
                setVolProc.running = true
            }
        }
    }
    Process { id: setVolProc; command: ["bash", "-c", ""] }

    Process { id: setSinkVolProc; command: ["bash", "-c", ""] }

    Process {
        id: setSinkProc
        command: ["bash", "-c", ""]
        onExited: {
            root._nodesRevision++
        }
    }

    Process {
        id: setSourceProc
        command: ["bash", "-c", ""]
        onExited: {
            root._nodesRevision++
        }
    }

    Timer {
        id: applySinkVolumeTimer
        interval: 220
        onTriggered: {
            var name = root._pendingSinkName || root.defaultSinkName
            if (!name) return
            var target = root.sinkVolumes[name]
            if (target === undefined || target === null || isNaN(target)) target = 0.10
            var safeName = name.replace(/'/g, "'\\''")
            setSinkVolProc.command = ["bash", "-c",
                "wpctl set-volume '" + safeName + "' " + target.toFixed(2) + " 2>/dev/null"]
            setSinkVolProc.running = true
            root.volume = target
            root._pendingSinkName = ""
        }
    }

    // Auto-clear status message after 3 seconds
    Timer {
        id: statusClear
        interval: 3000
        onTriggered: root.statusMsg = ""
    }
    onStatusMsgChanged: if (statusMsg !== "") statusClear.restart()

    onVisibleChanged: {
        if (visible) {
            statusMsg = ""
            root._nodesRevision++
            sinkAvailBuf = ""
            sourceAvailBuf = ""
            sinkAvailProc.running = true
            sourceAvailProc.running = true
            var v = root.defaultSink?.audio?.volume
            var m = root.defaultSink?.audio?.muted
            if (v !== undefined && v !== null && !isNaN(v)) root.volume = v
            if (m !== undefined && m !== null) root.muted = m
            Qt.callLater(function() { audioCard.forceActiveFocus() })
        } else {
            volDebounce.stop()
            statusClear.stop()
            availPoll.stop()
        }
    }

    Timer {
        id: availPoll
        interval: 3000
        repeat: true
        running: root.visible
        onTriggered: {
            if (!sinkAvailProc.running) {
                sinkAvailBuf = ""
                sinkAvailProc.running = true
            }
            if (!sourceAvailProc.running) {
                sourceAvailBuf = ""
                sourceAvailProc.running = true
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function volIcon(v, m) {
        if (m || v === 0) return "󰝟"
        if (v < 0.33) return "󰕿"
        if (v < 0.67) return "󰖀"
        return "󰕾"
    }

    function sinkIcon(name) {
        var n = name.toLowerCase()
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("iec958")) return "󰡁"
        if (n.includes("bluez") || n.includes("bluetooth")) return "󰋋"
        if (n.includes("usb"))                               return "󱊣"
        if (n.includes("headphone") || n.includes("headset")) return "󰋋"
        return "󰕾"
    }

    function sourceIcon(name) {
        var n = name.toLowerCase()
        if (n.includes("bluez") || n.includes("bluetooth")) return "󰋋"
        if (n.includes("usb"))  return "󱊣"
        if (n.includes("webcam") || n.includes("camera"))   return "󰄀"
        return "󰍹"
    }

    function formatDesc(desc, name) {
        if (desc && desc !== "" && desc !== "(null)") return desc
        var n = name || ""
        n = n.replace(/^alsa_(output|input)\./, "")
        n = n.replace(/^bluez_(output|input)\.[0-9A-Fa-f:_]+$/, "Bluetooth")
        n = n.replace(/^bluez_(output|input)\./, "Bluetooth: ")
        n = n.replace(/pci-[0-9a-f]{4}_[0-9a-f]{2}_[0-9a-f]{2}\.\d+\./, "")
        n = n.replace(/usb-[^.]+\./, "USB: ")
        n = n.replace(/[-_.]+/g, " ").trim()
        return n.replace(/\b\w/g, function(c) { return c.toUpperCase() })
    }

    function toggleMute() {
        muteProc.running = true
    }

    Process {
        id: muteProc
        command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null"]
    }

    // ── Port availability (hide unavailable DP/HDMI entries) ─────────────
    property string sinkAvailBuf: ""
    Process {
        id: sinkAvailProc
        command: ["bash", "-c", "pactl --format=json list sinks 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root.sinkAvailBuf += d + "\n" }
        onExited: {
            try {
                var data = JSON.parse(root.sinkAvailBuf)
                var map = ({})
                for (var i = 0; i < data.length; i++) {
                    var s = data[i]
                    var name = s.name || ""
                    if (!name) continue
                    var ports = s.ports || []
                    if (ports.length === 0) {
                        map[name] = true
                        continue
                    }
                    var ok = false
                    for (var p = 0; p < ports.length; p++) {
                        var av = (ports[p].availability || "").toString().toLowerCase()
                        if (av !== "no disponible" && av !== "not available") {
                            ok = true
                            break
                        }
                    }
                    map[name] = ok
                }
                root._sinkAvailable = map
                root._nodesRevision++
            } catch(e) {}
            root.sinkAvailBuf = ""
        }
    }

    property string sourceAvailBuf: ""
    Process {
        id: sourceAvailProc
        command: ["bash", "-c", "pactl --format=json list sources 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root.sourceAvailBuf += d + "\n" }
        onExited: {
            try {
                var data = JSON.parse(root.sourceAvailBuf)
                var map = ({})
                for (var i = 0; i < data.length; i++) {
                    var s = data[i]
                    var name = s.name || ""
                    if (!name || name.endsWith(".monitor")) continue
                    var ports = s.ports || []
                    if (ports.length === 0) {
                        map[name] = true
                        continue
                    }
                    var ok = false
                    for (var p = 0; p < ports.length; p++) {
                        var av = (ports[p].availability || "").toString().toLowerCase()
                        if (av !== "no disponible" && av !== "not available") {
                            ok = true
                            break
                        }
                    }
                    map[name] = ok
                }
                root._sourceAvailable = map
                root._nodesRevision++
            } catch(e) {}
            root.sourceAvailBuf = ""
        }
    }

    function setVolume(v) {
        var clamped = Math.max(0, Math.min(1.5, v))
        root.volume = clamped
        root._pendingVol = clamped
        if (root.defaultSinkName !== "") {
            var map = ({})
            Object.assign(map, root.sinkVolumes)
            map[root.defaultSinkName] = clamped
            root.sinkVolumes = map
        }
        volDebounce.restart()
    }

    // ── Build filtered lists from Pipewire.nodes ──────────────────────────
    property int _nodesRevision: 0

    property string _wpctlBuf: ""
    Process {
        id: wpctlRefreshProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._wpctlBuf += d }
        onExited: {
            var m = root._wpctlBuf.trim().match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            root._wpctlBuf = ""
            if (m) {
                var v = parseFloat(m[1])
                if (!isNaN(v)) root.volume = v
                root.muted = !!m[2]
            }
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root._nodesRevision++
            // New sink may not be bound yet — wpctl is the reliable fallback
            if (!wpctlRefreshProc.running) {
                root._wpctlBuf = ""
                wpctlRefreshProc.running = true
            }
        }
        function onDefaultAudioSourceChanged() { root._nodesRevision++ }
        function onReadyChanged()              { root._nodesRevision++ }
    }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(object, index) { root._nodesRevision++ }
        function onObjectRemovedPost(object, index)  { root._nodesRevision++ }
    }

    // Track node changes for revision bumps
    Instantiator {
        model: Pipewire.nodes
        delegate: Connections {
            required property var modelData
            target: modelData.audio
            function onVolumesChanged() { root._nodesRevision++ }
            function onMutedChanged()   { root._nodesRevision++ }
        }
    }

    property var sinks: {
        _nodesRevision
        var all = Pipewire.nodes.values
        var out = []
        var activeName = root.defaultSink?.name || ""
        for (var i = 0; i < all.length; i++) {
            var node = all[i]
            if (!node || !node.isSink || node.isStream) continue
            var name = node.name || ""
            if (name === "" || name.endsWith(".monitor")) continue
            // Only include real pactl sinks; excludes Dummy/Freewheel/MIDI bridge nodes
            if (root._sinkAvailable[name] !== true) continue
            out.push({
                id:          name,
                displayName: formatDesc(node.description, name),
                icon:        sinkIcon(name),
                active:      name === activeName,
                node:        node
            })
        }
        return out
    }

    property var sources: {
        _nodesRevision
        var all = Pipewire.nodes.values
        var out = []
        var activeName = root.defaultSource?.name || ""
        for (var i = 0; i < all.length; i++) {
            var node = all[i]
            if (!node || node.isSink || node.isStream) continue
            var name = node.name || ""
            if (name === "" || name.endsWith(".monitor")) continue
            // Only include real pactl sources; excludes bridge/virtual nodes
            if (root._sourceAvailable[name] !== true) continue
            out.push({
                id:          name,
                displayName: formatDesc(node.description, name),
                icon:        sourceIcon(name),
                active:      name === activeName,
                node:        node
            })
        }
        return out
    }

    function setDefaultSink(name) {
        if (root.defaultSinkName !== "" && !isNaN(root.volume)) {
            var current = ({})
            Object.assign(current, root.sinkVolumes)
            current[root.defaultSinkName] = root.volume
            root.sinkVolumes = current
        }
        root._pendingSinkName = name
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].id === name && sinks[i].node) {
                var safe = name.replace(/'/g, "'\\''")
                setSinkProc.command = ["bash", "-c",
                    "pactl set-default-sink '" + safe + "' 2>/dev/null; "
                    + "pactl list short sink-inputs | awk '{print $1}' | xargs -r -I{} pactl move-sink-input {} '" + safe + "' 2>/dev/null"]
                setSinkProc.running = true
                applySinkVolumeTimer.restart()
                break
            }
        }
    }

    function setDefaultSource(name) {
        for (var i = 0; i < sources.length; i++) {
            if (sources[i].id === name && sources[i].node) {
                var safe = name.replace(/'/g, "'\\''")
                setSourceProc.command = ["bash", "-c",
                    "pactl set-default-source '" + safe + "' 2>/dev/null; "
                    + "pactl list short source-outputs | awk '{print $1}' | xargs -r -I{} pactl move-source-output {} '" + safe + "' 2>/dev/null"]
                setSourceProc.running = true
                break
            }
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
        id: audioCard
        focus: true
        anchors.centerIn: parent
        width:  420
        height: Math.min(580, cardCol.implicitHeight + 32)
        radius: 14
        color:  Theme.base

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
                        text: root.volIcon(root.volume, root.muted)
                        font.pixelSize: 20
                        color: root.muted ? Theme.muted2 : Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Audio"
                            font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            text: root.defaultSink?.description ?? "Sin dispositivo"
                            font.pixelSize: 11; color: Theme.muted1
                            elide: Text.ElideRight
                            width: 220
                        }
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    // Close
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: closeMA.containsMouse ? Theme.surface3 : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 13; color: Theme.muted1 }
                        MouseArea { id: closeMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.visible = false }
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
                topPadding: 6; bottomPadding: 2
            }

            // ── Volume section ────────────────────────────────────────────
            Item {
                width: parent.width; height: 64

                // Mute button
                Rectangle {
                    id: muteBtn
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 36; height: 36; radius: 10
                    color: {
                        if (!muteBtnMA.containsMouse)
                            return root.muted
                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                : Theme.surface2
                        return root.muted
                            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
                            : Theme.surface3
                    }
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.volIcon(root.volume, root.muted)
                        font.pixelSize: 16
                        color: root.muted ? Theme.error : Theme.accent
                    }
                    MouseArea {
                        id: muteBtnMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                // Volume % label
                Text {
                    id: volPct
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root.muted ? "Mudo" : Math.round(root.volume * 100) + "%"
                    font.pixelSize: 13; font.weight: Font.Normal
                    color: root.muted ? Theme.muted2 : Theme.text
                    width: 46
                    horizontalAlignment: Text.AlignRight
                }

                // Slider
                Item {
                    anchors {
                        left: muteBtn.right; leftMargin: 10
                        right: volPct.left;  rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    height: 28

                    Rectangle {
                        id: sliderTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 6; radius: 3
                        color: Theme.surface3

                        // Filled part
                        Rectangle {
                            width: (Math.min(1.5, Math.max(0, root.volume)) / 1.5) * sliderTrack.width
                            height: parent.height; radius: parent.radius
                            color: root.muted ? Theme.muted2 : Theme.accent
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // 100 % marker line
                        Rectangle {
                            x: (1.0 / 1.5) * sliderTrack.width - 1
                            height: 10; width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                            radius: 1
                        }

                        // Handle dot
                        Rectangle {
                            x: (Math.min(1.5, Math.max(0, root.volume)) / 1.5) * sliderTrack.width - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: root.muted ? Theme.muted2 : "white"
                        }

                        MouseArea {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height + 20
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (mouse) => root.setVolume((mouse.x / sliderTrack.width) * 1.5)
                            onPositionChanged: (mouse) => {
                                if (pressed) root.setVolume((mouse.x / sliderTrack.width) * 1.5)
                            }
                        }
                    }
                }
            }

            // ── Salidas ───────────────────────────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            Item {
                width: parent.width; height: 36
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Salidas de audio"
                    font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.muted1
                }
            }

            // Sinks list — max 3 rows visible, scrollable
            Item {
                width: parent.width
                height: Math.max(0, Math.min(root.sinks.length * 44 - 4, 128))

                Flickable {
                    id: sinksFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: sinksCol.implicitHeight
                    clip: true
                    boundsMovement: Flickable.StopAtBounds

                    Column {
                        id: sinksCol
                        width: sinksFlick.width
                        spacing: 4

                        Repeater {
                            model: root.sinks

                            Rectangle {
                                id: sinkDelegate
                                required property var modelData
                                property bool hovered: false

                                width: sinksCol.width; height: 40; radius: 8
                                color: modelData.active
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (hovered ? Theme.surface3 : Theme.surface2)
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Rectangle {
                                    visible: modelData.active
                                    width: 3; height: 20; radius: 2
                                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                    color: Theme.accent
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                                    spacing: 8
                                    Text { text: modelData.icon; font.pixelSize: 15; color: modelData.active ? Theme.accent : Theme.muted2 }
                                    Text { Layout.fillWidth: true; text: modelData.displayName; font.pixelSize: 12; color: Theme.text; elide: Text.ElideRight }
                                    Text { visible: modelData.active; text: "Activa"; font.pixelSize: 10; color: Theme.accent }
                                }

                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: sinkDelegate.hovered = true
                                    onExited:  sinkDelegate.hovered = false
                                    onClicked: { if (!modelData.active) root.setDefaultSink(modelData.id) }
                                }
                            }
                        }
                    }
                }

                // Scroll indicator
                Rectangle {
                    visible: sinksFlick.contentHeight > sinksFlick.height + 1
                    anchors.right: parent.right
                    y: sinksFlick.visibleArea.yPosition * sinksFlick.height
                    width: 3; radius: 2
                    height: Math.max(20, sinksFlick.visibleArea.heightRatio * sinksFlick.height)
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                }
            }
            Item { width: parent.width; height: 10 }

            // ── Entradas ──────────────────────────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            Item {
                width: parent.width; height: 36

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Entradas de audio"
                    font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.muted1
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; radius: 6
                    color: srcToggleMA.containsMouse ? Theme.surface3 : Theme.surface2
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.showSources ? "󰅃" : "󰅀"
                        font.pixelSize: 12; color: Theme.muted1
                    }
                    MouseArea {
                        id: srcToggleMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showSources = !root.showSources
                    }
                }
            }

            // Sources list — max 3 rows visible, scrollable
            Item {
                visible: root.showSources
                width: parent.width
                height: Math.max(0, Math.min(root.sources.length * 44 - 4, 128))

                Flickable {
                    id: sourcesFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: sourcesCol.implicitHeight
                    clip: true
                    boundsMovement: Flickable.StopAtBounds

                    Column {
                        id: sourcesCol
                        width: sourcesFlick.width
                        spacing: 4

                        Repeater {
                            model: root.sources

                            Rectangle {
                                id: sourceDelegate
                                required property var modelData
                                property bool hovered: false

                                width: sourcesCol.width; height: 40; radius: 8
                                color: modelData.active
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (hovered ? Theme.surface3 : Theme.surface2)
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Rectangle {
                                    visible: modelData.active
                                    width: 3; height: 20; radius: 2
                                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                    color: Theme.accent
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                                    spacing: 8
                                    Text { text: modelData.icon; font.pixelSize: 15; color: modelData.active ? Theme.accent : Theme.muted2 }
                                    Text { Layout.fillWidth: true; text: modelData.displayName; font.pixelSize: 12; color: Theme.text; elide: Text.ElideRight }
                                    Text { visible: modelData.active; text: "Activa"; font.pixelSize: 10; color: Theme.accent }
                                }

                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: sourceDelegate.hovered = true
                                    onExited:  sourceDelegate.hovered = false
                                    onClicked: { if (!modelData.active) root.setDefaultSource(modelData.id) }
                                }
                            }
                        }
                    }
                }

                // Scroll indicator
                Rectangle {
                    visible: sourcesFlick.contentHeight > sourcesFlick.height + 1
                    anchors.right: parent.right
                    y: sourcesFlick.visibleArea.yPosition * sourcesFlick.height
                    width: 3; radius: 2
                    height: Math.max(20, sourcesFlick.visibleArea.heightRatio * sourcesFlick.height)
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                }
            }
            Item { width: parent.width; height: 10 }
        }
    }
}

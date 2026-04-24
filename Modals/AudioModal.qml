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
    property bool   showSources:   true
    property var    _sinkAvailable: ({})
    property var    _sourceAvailable: ({})

    // ── Bind nodes — REQUIRED for node properties ─────────────────────────
    PwObjectTracker {
        objects: [root.defaultSink, root.defaultSource]
    }

    onVisibleChanged: {
        if (visible) {
            root._nodesRevision++
            sinkAvailBuf = ""
            sourceAvailBuf = ""
            sinkAvailProc.running = true
            sourceAvailProc.running = true
            Qt.callLater(function() { audioCard.forceActiveFocus() })
        } else {
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

    // ── Port availability ────────────────────────────────────────────────
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
                    if (ports.length === 0) { map[name] = true; continue }
                    var ok = false
                    for (var p = 0; p < ports.length; p++) {
                        var av = (ports[p].availability || "").toString().toLowerCase()
                        if (av !== "no disponible" && av !== "not available") { ok = true; break }
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
                    if (ports.length === 0) { map[name] = true; continue }
                    var ok = false
                    for (var p = 0; p < ports.length; p++) {
                        var av = (ports[p].availability || "").toString().toLowerCase()
                        if (av !== "no disponible" && av !== "not available") { ok = true; break }
                    }
                    map[name] = ok
                }
                root._sourceAvailable = map
                root._nodesRevision++
            } catch(e) {}
            root.sourceAvailBuf = ""
        }
    }

    // ── Build filtered lists from Pipewire.nodes ──────────────────────────
    property int _nodesRevision: 0

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged()   { root._nodesRevision++ }
        function onDefaultAudioSourceChanged() { root._nodesRevision++ }
        function onReadyChanged()              { root._nodesRevision++ }
    }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(object, index) { root._nodesRevision++ }
        function onObjectRemovedPost(object, index)  { root._nodesRevision++ }
    }

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

    Process {
        id: setSinkProc
        command: ["bash", "-c", ""]
        onExited: root._nodesRevision++
    }

    Process {
        id: setSourceProc
        command: ["bash", "-c", ""]
        onExited: root._nodesRevision++
    }

    function setDefaultSink(name) {
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].id === name && sinks[i].node) {
                var safe = name.replace(/'/g, "'\\''")
                setSinkProc.command = ["bash", "-c",
                    "pactl set-default-sink '" + safe + "' 2>/dev/null; "
                    + "pactl list short sink-inputs | awk '{print $1}' | xargs -r -I{} pactl move-sink-input {} '" + safe + "' 2>/dev/null"]
                setSinkProc.running = true
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
        height: Math.min(480, cardCol.implicitHeight + 32)
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
                width: parent.width; height: 42

                Text {
                    text: "Audio"
                    font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

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

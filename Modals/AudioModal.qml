import QtQuick
import QtQuick.Layouts
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

    property string _scriptsPath: Qt.resolvedUrl("../scripts").toString().replace("file://", "")

    // ── State ─────────────────────────────────────────────────────────────
    property real   volume:        0.75   // 0.0 – 1.5  (1.0 = 100%, 1.5 = 150%)
    property bool   muted:         false
    property string defaultSink:   ""
    property string defaultSource: ""
    property var    sinks:         []     // [{id, name, displayName, icon, active}]
    property var    sources:       []     // [{id, name, displayName, icon, active}]
    property bool   working:       false
    property string statusMsg:     ""
    property bool   showSources:   true
    property bool   _hasDeviceSuccessfulRead: false
    property int    _emptyDeviceReads: 0

    // Debounce volume slider writes
    property real _pendingVol: -1
    Timer {
        id: volDebounce
        interval: 80
        onTriggered: {
            if (root._pendingVol >= 0) {
                var v = root._pendingVol.toFixed(2)
                root._pendingVol = -1
                setVolProc.command = ["bash", "-c",
                    "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v + " 2>/dev/null"]
                setVolProc.running = true
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            statusMsg = ""
            loadAudio()
            Qt.callLater(function() { root.forceActiveFocus() })
        } else {
            hotplugPoll.stop()
            volDebounce.stop()
            statusClear.stop()
            reloadDelay.stop()
        }
    }

    Component.onDestruction: {
        hotplugPoll.stop()
        volDebounce.stop()
        statusClear.stop()
        reloadDelay.stop()
        volProc.running = false
        deviceListProc.running = false
        setVolProc.running = false
        muteProc.running = false
        setSinkProc.running = false
        setSourceProc.running = false
    }

    // Delay timer so PipeWire has time to update after set-default
    Timer {
        id: reloadDelay
        interval: 450
        onTriggered: {
            root._deviceBuf = ""
            root.working = true
            volProc.running        = true
            deviceListProc.running = true
        }
    }

    // Auto-clear status message after 3 seconds
    Timer {
        id: statusClear
        interval: 3000
        onTriggered: root.statusMsg = ""
    }
    onStatusMsgChanged: if (statusMsg !== "") statusClear.restart()

    // Poll for device hotplug while modal is open
    Timer {
        id: hotplugPoll
        interval: 1500
        repeat: true
        running: root.visible
        onTriggered: {
            if (!root.working && !deviceListProc.running) {
                root._deviceBuf = ""
                deviceListProc.running = true
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function loadAudio() {
        root._deviceBuf = ""
        root._volBuf = ""
        working = true
        volProc.running        = true
        deviceListProc.running = true
    }

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

    function formatName(name) {
        var n = name
        n = n.replace(/^alsa_(output|input)\./, "")
        n = n.replace(/^bluez_(output|input)\.[0-9A-Fa-f:_]+$/, "Bluetooth")
        n = n.replace(/^bluez_(output|input)\./, "Bluetooth: ")
        n = n.replace(/pci-[0-9a-f]{4}_[0-9a-f]{2}_[0-9a-f]{2}\.\d+\./, "")
        n = n.replace(/usb-[^.]+\./, "USB: ")
        n = n.replace(/[-_.]+/g, " ").trim()
        return n.replace(/\b\w/g, function(c) { return c.toUpperCase() })
    }

    // ── Processes ─────────────────────────────────────────────────────────
    property string _volBuf: ""
    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._volBuf += d }
        onExited: {
            var s = root._volBuf.trim()
            root._volBuf = ""
            var m = s.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (m) {
                root.volume = parseFloat(m[1])
                root.muted  = !!m[2]
            }
            root.working = false
        }
    }

    Process { id: setVolProc; command: ["bash", "-c", ""] }

    Process {
        id: muteProc
        command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null"]
        onExited: volProc.running = true
    }

    function toggleMute() { muteProc.running = true }

    function setVolume(v) {
        root.volume     = Math.max(0, Math.min(1.5, v))
        root._pendingVol = root.volume
        volDebounce.restart()
    }

    property string _deviceBuf: ""
    Process {
        id: deviceListProc
        command: ["python3", root._scriptsPath + "/audio-devices.py"]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => root._deviceBuf += d + "\n" }
        onExited: {
            var lines       = root._deviceBuf.trim().split("\n")
            root._deviceBuf = ""
            var newSinks    = []
            var newSources  = []
            var parsedCount = 0
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (!l) continue
                // format: SINK:active:stable_name:Human Description
                var p0      = l.indexOf(":")
                if (p0 <= 0) continue
                var section = l.slice(0, p0)
                var rest    = l.slice(p0 + 1)
                var p1      = rest.indexOf(":")
                if (p1 < 0) continue
                var active  = rest.slice(0, p1) === "1"
                var rest2   = rest.slice(p1 + 1)
                var p2      = rest2.indexOf(":")
                if (p2 < 0) continue
                var id      = rest2.slice(0, p2).trim()    // stable pactl name
                var display = rest2.slice(p2 + 1).trim()   // human-readable description
                if (!id) continue
                parsedCount++
                var entry = {
                    id:          id,
                    name:        id,
                    displayName: display || root.formatName(id),
                    icon:        section === "SINK" ? root.sinkIcon(id) : root.sourceIcon(id),
                    active:      active
                }
                if (section === "SINK")        newSinks.push(entry)
                else if (section === "SOURCE") newSources.push(entry)
            }

            if (parsedCount === 0) {
                root._emptyDeviceReads++
                if (root._hasDeviceSuccessfulRead && root._emptyDeviceReads < 3) {
                    return
                }
            } else {
                root._hasDeviceSuccessfulRead = true
                root._emptyDeviceReads = 0
            }

            var toKey = function(arr) { return arr.map(function(x) { return x.id + (x.active ? '1' : '0') }).join(',') }
            if (toKey(newSinks)   !== toKey(root.sinks))   root.sinks   = newSinks
            if (toKey(newSources) !== toKey(root.sources)) root.sources = newSources
        }
    }

    Process {
        id: setSinkProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            if (ec === 0) {
                reloadDelay.restart()
            } else {
                root.statusMsg = "Error al cambiar salida"
            }
        }
    }
    function sanitizeName(name) {
        return name.replace(/[^a-zA-Z0-9._-]/g, "")
    }

    function setDefaultSink(name) {
        // Optimistically mark new sink as active for instant feedback
        var updated = []
        for (var i = 0; i < root.sinks.length; i++) {
            var s = root.sinks[i]
            updated.push({ id: s.id, name: s.name, displayName: s.displayName,
                           icon: s.icon, active: s.id === name })
        }
        root.sinks = updated
        var safeName = sanitizeName(name)
        setSinkProc.command = ["bash", "-c", "pactl set-default-sink " + safeName + " 2>/dev/null"]
        setSinkProc.running = true
    }

    Process {
        id: setSourceProc
        command: ["bash", "-c", ""]
        onExited: (ec) => {
            if (ec === 0) {
                root.statusMsg = "✓ Entrada cambiada"
                reloadDelay.restart()
            } else {
                root.statusMsg = "✗ Error al cambiar entrada"
            }
        }
    }
    function setDefaultSource(name) {
        // Optimistically mark new source as active for instant feedback
        var updated = []
        for (var i = 0; i < root.sources.length; i++) {
            var s = root.sources[i]
            updated.push({ id: s.id, name: s.name, displayName: s.displayName,
                           icon: s.icon, active: s.id === name })
        }
        root.sources = updated
        var safeName = sanitizeName(name)
        setSourceProc.command = ["bash", "-c", "pactl set-default-source " + safeName + " 2>/dev/null"]
        setSourceProc.running = true
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
                            text: {
                                for (var i = 0; i < root.sinks.length; i++)
                                    if (root.sinks[i].active) return root.sinks[i].displayName
                                return root.working ? "Cargando..." : "Sin dispositivo"
                            }
                            font.pixelSize: 11; color: Theme.muted1
                            elide: Text.ElideRight
                            width: 220
                        }
                    }
                }

                // Right controls
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    // Refresh
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: refreshMA.containsMouse ? Theme.surface3 : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 14
                            color: root.working ? Theme.accent : Theme.muted1
                            RotationAnimation on rotation {
                                running: root.working; loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }
                        MouseArea { id: refreshMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.loadAudio() }
                    }

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
                                    onEntered: parent.hovered = true
                                    onExited:  parent.hovered = false
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
                                    onEntered: parent.hovered = true
                                    onExited:  parent.hovered = false
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

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Components"

// ─────────────────────────────────────────────────────────────────────────────
// OverviewModal — 2×5 workspace grid, windows at real positions (scaled)
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    property bool overviewOpen: false

    visible: false
    color:   "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    // ── State ─────────────────────────────────────────────────────────────
    property var clients:    []
    property int activeWsId: -1

    property string _wsRaw:   ""
    property string _clRaw:   ""
    property string _actRaw:  ""
    property bool   _wsReady:  false
    property bool   _clReady:  false
    property bool   _actReady: false

    property string _dragAddr:   ""
    property int    _dragFromWs: -1

    // Timestamp set once per open() → all Images load once per session, no flash
    property string _openTs: "0"

    // ── Grid geometry ─────────────────────────────────────────────────────
    readonly property int   _cols:   5
    readonly property int   _rows:   2
    readonly property int   _total:  _cols * _rows     // 10 workspace slots
    readonly property real  _gap:    6                 // gap between cells
    readonly property real  _ipad:   14                // inner card padding
    readonly property real  _lblH:   24                // label bar height per cell

    // Monitor dimensions (real screen)
    readonly property real  _monW:   root.width  > 0 ? root.width  : 1920
    readonly property real  _monH:   root.height > 0 ? root.height : 1080

    // Card fills the available width minus a small margin on each side
    readonly property real  _cardW:  root.width  - 40          // 20 px each side
    readonly property real  _cellW:  (_cardW - _ipad*2 - _gap*(_cols-1)) / _cols

    // Cell height preserves the exact monitor aspect ratio → proper landscape thumbnail
    readonly property real  _cellH:  Math.round(_cellW * _monH / _monW)

    // Card height derived from cells so it always fits
    readonly property real  _cardH:  _cellH * _rows + _lblH * _rows + _gap * (_rows-1) + _ipad * 2

    // Scale factor (uniform, aspect preserved)
    readonly property real  _sc:     _cellW / _monW

    // ── Animation ─────────────────────────────────────────────────────────
    property real _gridScale: 0.94
    property real _dimOp:     0.0
    property real _gridOp:    0.0

    function open() {
        _openTs      = "" + Date.now()   // fresh timestamp → Images reload once per open
        overviewOpen = true
        visible      = true
        _gridScale   = 0.94
        _dimOp       = 0.0
        _gridOp      = 0.0
        _refresh()
        openAnim.start()
    }

    function close() {
        closeAnim.start()
    }

    function toggle() {
        if (overviewOpen) close()
        else              open()
    }

    function _refresh() {
        _wsRaw = ""; _clRaw = ""; _actRaw = ""
        _wsReady = false; _clReady = false; _actReady = false
        wsProc.running  = true
        clProc.running  = true
        actProc.running = true
    }

    function _tryBuild() {
        if (!_wsReady || !_clReady || !_actReady) return
        try {
            try { root.activeWsId = JSON.parse(_actRaw.trim()).id || -1 } catch(e) {}

            var cls = JSON.parse(_clRaw.trim())
            var clArr = []
            for (var j = 0; j < cls.length; j++) {
                var c = cls[j]
                if (!c.workspace || c.workspace.id <= 0 || c.workspace.id > root._total) continue
                clArr.push({
                    address:  c.address || "",
                    appClass: c.class   || "unknown",
                    title:    c.title   || c.class || "?",
                    wsId:     c.workspace.id,
                    atX:      (c.at   && c.at.length   > 0) ? c.at[0]   : 0,
                    atY:      (c.at   && c.at.length   > 1) ? c.at[1]   : 0,
                    sizeW:    (c.size && c.size.length > 0) ? c.size[0] : 400,
                    sizeH:    (c.size && c.size.length > 1) ? c.size[1] : 300
                })
            }
            root.clients = clArr

        } catch(e) { console.log("Overview parse error:", e) }
    }

    // ── Animations ────────────────────────────────────────────────────────
    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "_dimOp";    to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "_gridOp";   to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "_gridScale";to: 1.0; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "_dimOp";    to: 0.0;  duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_gridOp";   to: 0.0;  duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_gridScale";to: 0.96; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.visible = false; root.overviewOpen = false } }
    }

    // ── Dim backdrop (click outside → close) ─────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        Theme.dim
        opacity:      root._dimOp
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── 2×5 grid card (centered, smaller than screen) ─────────────────────
    Rectangle {
        id:              card
        anchors.centerIn: parent
        width:           root._cardW
        height:          root._cardH
        radius:          14
        color:           Theme.cardBg
        border.color:    Theme.surface2
        border.width:    1
        opacity:         root._gridOp
        scale:           root._gridScale
        transformOrigin: Item.Center

        // Block backdrop clicks
        MouseArea { anchors.fill: parent; onClicked: {} }

        Grid {
            id:            wsGrid
            anchors.fill:  parent
            anchors.margins: root._ipad
            columns:       root._cols
            rows:          root._rows
            columnSpacing: root._gap
            rowSpacing:    root._gap

            Repeater {
                // Always 10 fixed slots (wsId 1..10)
                model: root._total

                // ── One workspace slot ────────────────────────────────────
                Item {
                    id:   slot
                    required property int index
                    readonly property int wsId: index + 1

                    width:  root._cellW
                    height: root._cellH + root._lblH

                    readonly property bool isActive: slot.wsId === root.activeWsId
                    readonly property var myClients: {
                        var arr = []
                        for (var i = 0; i < root.clients.length; i++)
                            if (root.clients[i].wsId === slot.wsId) arr.push(root.clients[i])
                        return arr
                    }

                    // ── Canvas ────────────────────────────────────────────
                    Rectangle {
                        id:     canvas
                        width:  root._cellW
                        height: root._cellH
                        radius: 8
                        color:  Theme.surface1
                        border.color: slot.isActive ? Theme.accent : Theme.surface2
                        border.width: slot.isActive ? 2 : 1
                        clip:   true

                        property bool hovered: false

                        // Screenshot background — static path + open-session timestamp
                        // The bg process keeps /tmp/qs-ws-N.png fresh on every workspace switch.
                        Image {
                            id:           wsImg
                            anchors.fill: parent
                            source:       "file:///tmp/qs-ws-" + slot.wsId + ".png?" + root._openTs
                            fillMode:     Image.PreserveAspectCrop
                            cache:        false
                            asynchronous: true
                            smooth:       true
                        }

                        // Hover highlight – rendered above screenshot
                        Rectangle {
                            anchors.fill: parent
                            radius:       parent.radius
                            color:        canvas.hovered ? Theme.hover : "transparent"
                        }

                        // Click → go to workspace
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onEntered:    canvas.hovered = true
                            onExited:     canvas.hovered = false
                            onClicked: {
                                Hyprland.dispatch("workspace " + slot.wsId)
                                root.close()
                            }
                        }

                        // Drop target
                        DropArea {
                            anchors.fill: parent
                            keys:         ["windowAddress"]
                            onEntered:    { canvas.color = Theme.surface1 }
                            onExited:     { canvas.color = Theme.surface1 }
                            onDropped: {
                                canvas.color = Theme.surface1
                                if (root._dragFromWs !== slot.wsId && root._dragAddr !== "") {
                                    Hyprland.dispatch("movetoworkspacesilent " + slot.wsId + ",address:" + root._dragAddr)
                                    root._dragAddr = ""; root._dragFromWs = -1
                                    refreshTimer.start()
                                }
                            }
                        }

                        // Empty workspace number (shown only when screenshot is absent and no windows)
                        Text {
                            anchors.centerIn: parent
                            visible:          slot.myClients.length === 0 && wsImg.status !== Image.Ready
                            text:             "" + slot.wsId
                            color:            slot.isActive ? Theme.accentSurface : Theme.base
                            font.pixelSize:   Math.min(root._cellH * 0.55, 90)
                            font.bold:        true
                        }

                        // Window tiles – solid color tiles when no screenshot, transparent overlays when screenshot loaded
                        Repeater {
                            model: slot.myClients

                            Rectangle {
                                id: winTile
                                required property var modelData
                                required property int index

                                x:      Math.round(modelData.atX  * root._sc)
                                y:      Math.round(modelData.atY  * root._sc)
                                width:  Math.max(Math.round(modelData.sizeW * root._sc), 16)
                                height: Math.max(Math.round(modelData.sizeH * root._sc), 12)

                                radius:       3
                                color:        "transparent"
                                border.color: "transparent"
                                border.width: 0
                                clip:         false

                                Drag.active:    wd.drag.active
                                Drag.keys:      ["windowAddress"]
                                Drag.hotSpot.x: width  / 2
                                Drag.hotSpot.y: height / 2

                                states: State {
                                    when: winTile.Drag.active
                                    PropertyChanges { target: winTile; opacity: 0.4; z: 999 }
                                }

                                MouseArea {
                                    id:           wd
                                    anchors.fill: parent
                                    drag.target:  winTile
                                    cursorShape:  drag.active ? Qt.DragMoveCursor : Qt.PointingHandCursor
                                    onPressed: {
                                        root._dragAddr   = modelData.address
                                        root._dragFromWs = modelData.wsId
                                    }
                                    onClicked: {
                                        Hyprland.dispatch("focuswindow address:" + modelData.address)
                                        root.close()
                                    }
                                }
                            }
                        }
                    }

                    // ── Label bar ─────────────────────────────────────────
                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height:         root._lblH
                        color:          "transparent"

                        Text {
                            anchors.left:           parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin:     6
                            text:                   slot.myClients.length > 0
                                                    ? slot.myClients.length + " ventana" + (slot.myClients.length === 1 ? "" : "s")
                                                    : ""
                            color:                  Theme.surface3
                            font.pixelSize:         10
                        }

                        Text {
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin:    6
                            text:                   "" + slot.wsId
                            color:                  slot.isActive ? Theme.accent : Theme.surface3
                            font.pixelSize:         slot.isActive ? 13 : 11
                            font.bold:              slot.isActive
                        }
                    }
                }
            }
        }
    }

    // ── Screenshot capture ───────────────────────────────────────────────
    // bgCapture keeps /tmp/qs-ws-N.png fresh whenever you switch workspace.
    // initCapture grabs the active workspace once at startup.
    // Workspaces never visited just show a clean dark cell with their number.
    Process {
        id: bgCapture
        // Hyprland event socket: $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock
        // Events arrive as  "workspace>>3\n"  (plain text, one per line)
        command: ["sh", "-c",
            "_sock=\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\"; "
            + "nc -U \"$_sock\" | "
            + "while IFS= read -r _e; do "
            + "  case \"$_e\" in "
            + "    workspace>>*) "
            + "      _w=\"${_e#workspace>>}\"; "
            + "      _w=$(printf '%s' \"$_w\" | tr -dc '0-9'); "
            + "      [ -z \"$_w\" ] && continue; "
            + "      sleep 0.25; "
            + "      _m=$(hyprctl activeworkspace -j | awk -F'\"' '/monitor/{print $4; exit}'); "
            + "      [ -n \"$_m\" ] && grim -o \"$_m\" /tmp/qs-ws-\"$_w\".png ;; "
            + "  esac; "
            + "done"]
        running: true
        onExited: bgRestartTimer.start()
    }

    Timer {
        id:       bgRestartTimer
        interval: 3000
        repeat:   false
        onTriggered: bgCapture.running = true
    }

    // One-shot: capture the workspace active when the shell first loads (monitor-aware).
    Process {
        id: initCapture
        command: ["sh", "-c",
            "_info=$(hyprctl activeworkspace -j); "
            + "_w=$(echo \"$_info\" | grep -m1 '\"id\"' | grep -o '[0-9]*'); "
            + "_m=$(echo  \"$_info\" | awk -F'\"' '/monitor/{print $4; exit}'); "
            + "[ -n \"$_m\" ] && grim -o \"$_m\" /tmp/qs-ws-\"$_w\".png"]
        running: false
    }

    Component.onCompleted: initCapture.running = true

    // ── Data fetch ────────────────────────────────────────────────────────
    Process {
        id: actProc
        command: ["sh", "-c", "hyprctl activeworkspace -j"]
        running: false
        stdout: SplitParser { splitMarker: ""; onRead: data => { root._actRaw += data } }
        onExited: { root._actReady = true; root._tryBuild() }
    }
    Process {
        id: wsProc
        command: ["sh", "-c", "hyprctl workspaces -j"]
        running: false
        stdout: SplitParser { splitMarker: ""; onRead: data => { root._wsRaw += data } }
        onExited: { root._wsReady = true; root._tryBuild() }
    }
    Process {
        id: clProc
        command: ["sh", "-c", "hyprctl clients -j"]
        running: false
        stdout: SplitParser { splitMarker: ""; onRead: data => { root._clRaw += data } }
        onExited: { root._clReady = true; root._tryBuild() }
    }

    Timer {
        id: refreshTimer
        interval: 1500
        running:  root.overviewOpen
        repeat:   true
        onTriggered: root._refresh()
    }

    function _classColor(cls) {
        var c = cls.toLowerCase()
        if (c.indexOf("firefox")  >= 0 || c.indexOf("brave")    >= 0) return Theme.error
        if (c.indexOf("code")     >= 0 || c.indexOf("cursor")   >= 0) return Theme.accent
        if (c.indexOf("kitty")    >= 0 || c.indexOf("term")     >= 0) return Theme.success
        if (c.indexOf("nautilus") >= 0 || c.indexOf("thunar")   >= 0) return Theme.sky
        if (c.indexOf("spotify")  >= 0 || c.indexOf("mpv")      >= 0) return Theme.success
        if (c.indexOf("discord")  >= 0 || c.indexOf("signal")   >= 0) return Theme.accent2
        if (c.indexOf("gimp")     >= 0 || c.indexOf("inkscape") >= 0) return Theme.warning
        return Theme.sky
    }
}

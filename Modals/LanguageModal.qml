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

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // ── State ─────────────────────────────────────────────────────────────
    property string currentLayout: "—"
    property string currentLocale: "—"
    property string activeTab: "keyboard"
    property string layoutSearch: ""
    property string localeSearch: ""

    property bool _keymapsAvailable: true
    property bool _localesAvailable: true

    property var _layoutsRaw: []
    property var _localesRaw: []
    property var _layoutsAll: []
    property var _localesAll: []

    property var tabs: [
        { id: "keyboard", label: "Teclado", icon: "󰌌" },
        { id: "language", label: "Idioma",  icon: "󰗊" }
    ]


    // Listas curadas (fallback)
    property var fallbackLayouts: [
        { label: "Español  (es)",     code: "es"    },
        { label: "English  (us)",     code: "us"    },
        { label: "English UK (gb)",   code: "gb"    },
        { label: "Deutsch  (de)",     code: "de"    },
        { label: "Français  (fr)",    code: "fr"    },
        { label: "Português (pt)",    code: "pt"    },
        { label: "Italiano  (it)",    code: "it"    },
        { label: "日本語    (jp)",    code: "jp"    }
    ]

    property var fallbackLocales: [
        { label: "Español ES  (es_ES.UTF-8)", value: "es_ES.UTF-8" },
        { label: "Español MX  (es_MX.UTF-8)", value: "es_MX.UTF-8" },
        { label: "English US  (en_US.UTF-8)", value: "en_US.UTF-8" },
        { label: "English GB  (en_GB.UTF-8)", value: "en_GB.UTF-8" },
        { label: "Deutsch     (de_DE.UTF-8)", value: "de_DE.UTF-8" },
        { label: "Français    (fr_FR.UTF-8)", value: "fr_FR.UTF-8" }
    ]

    // ── Helpers ───────────────────────────────────────────────────────────
    function _normalize(s) { return (s || "").toLowerCase() }

    function _labelForLayout(code) {
        for (var i = 0; i < root.fallbackLayouts.length; i++) {
            if (root.fallbackLayouts[i].code === code) return root.fallbackLayouts[i].label
        }
        return (code || "").toUpperCase()
    }

    function _labelForLocale(value) {
        for (var i = 0; i < root.fallbackLocales.length; i++) {
            if (root.fallbackLocales[i].value === value) return root.fallbackLocales[i].label
        }
        return value || ""
    }

    function _layoutActive(code) {
        return root._normalize(root.currentLayout).indexOf(root._normalize(code)) >= 0
    }

    function _localeActive(value) {
        var cur = root.currentLocale || ""
        var shortVal = (value || "").split(".")[0]
        return cur.indexOf(value) >= 0 || cur.indexOf(shortVal) >= 0
    }

    function _matchItem(query, item, key) {
        if (!query) return true
        var q = root._normalize(query)
        var label = root._normalize(item.label || "")
        var val = root._normalize(item[key] || "")
        return label.indexOf(q) >= 0 || val.indexOf(q) >= 0
    }

    function rebuildLayoutModels() {
        layoutModel.clear()

        var source = root._layoutsAll.length > 0 ? root._layoutsAll : root.fallbackLayouts

        for (var i = 0; i < source.length; i++) {
            var item = source[i]
            if (root._matchItem(root.layoutSearch, item, "code")) {
                layoutModel.append({ label: item.label, code: item.code })
            }
        }
    }

    function rebuildLocaleModels() {
        localeModel.clear()

        var source = root._localesAll.length > 0 ? root._localesAll : root.fallbackLocales

        for (var i = 0; i < source.length; i++) {
            var item = source[i]
            if (root._matchItem(root.localeSearch, item, "value")) {
                localeModel.append({ label: item.label, value: item.value })
            }
        }
    }

    function loadLayouts() {
        root._layoutsRaw = []
        root._keymapsAvailable = true
        keymapsProc.running = true
    }

    function loadLocales() {
        root._localesRaw = []
        root._localesAvailable = true
        localesProc.running = true
    }

    function setLayout(code) {
        setLayoutProc.command = ["sh", "-c",
            "hyprctl keyword input:kb_layout " + code + " 2>/dev/null" +
            " && sleep 0.4 && hyprctl dispatch switchxkblayout all 0"]
        setLayoutProc.running = true
        Qt.callLater(() => devProc.running = true)
    }

    function setLocale(value) {
        if (!root._localesAvailable) return
        setLocaleProc.command = ["sh", "-c",
            "localectl set-locale LANG=" + value + " 2>/dev/null"]
        setLocaleProc.running = true
        root.currentLocale = value
    }

    // Refresh current info whenever modal opens
    onVisibleChanged: {
        if (visible) {
            activeTab = "keyboard"
            layoutSearch = ""
            localeSearch = ""
            layoutSearchInput.text = ""
            localeSearchInput.text = ""
            devProc.running = true
            localeProc.running = true
            loadLayouts()
            loadLocales()
        }
    }

    // ── Data fetching ─────────────────────────────────────────────────────
    Process {
        id: devProc
        command: ["sh", "-c",
            "hyprctl devices -j 2>/dev/null | " +
            "python3 -c \"import json,sys; d=json.load(sys.stdin); k=d.get('keyboards',[]); kb=next((x for x in k if x.get('main')), k[0] if k else {}); print(kb.get('active_keymap',''))\""]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var v = data.trim()
                if (v) root.currentLayout = v
            }
        }
    }

    Process {
        id: localeProc
        command: ["sh", "-c",
            "localectl status 2>/dev/null | awk -F'LANG=' '/System Locale/{print $2}' | awk '{print $1}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { var v = data.trim(); if (v) root.currentLocale = v }
        }
    }

    Process {
        id: keymapsProc
        command: ["sh", "-c", "timeout 3s localectl list-keymaps 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var v = data.trim()
                if (v) root._layoutsRaw.push(v)
            }
        }
        onExited: function(exitCode) {
            var ok = exitCode === 0 && root._layoutsRaw.length > 0
            root._keymapsAvailable = ok
            if (ok) {
                root._layoutsAll = []
                for (var i = 0; i < root._layoutsRaw.length; i++) {
                    var code = root._layoutsRaw[i]
                    root._layoutsAll.push({ code: code, label: root._labelForLayout(code) })
                }
            } else {
                root._layoutsAll = root.fallbackLayouts
            }
            root.rebuildLayoutModels()
        }
    }

    Process {
        id: localesProc
        command: ["sh", "-c", "timeout 3s localectl list-locales 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var v = data.trim()
                if (v) root._localesRaw.push(v)
            }
        }
        onExited: function(exitCode) {
            var ok = exitCode === 0 && root._localesRaw.length > 0
            root._localesAvailable = ok
            if (ok) {
                root._localesAll = []
                for (var i = 0; i < root._localesRaw.length; i++) {
                    var value = root._localesRaw[i]
                    root._localesAll.push({ value: value, label: root._labelForLocale(value) })
                }
            } else {
                root._localesAll = root.fallbackLocales
            }
            root.rebuildLocaleModels()
        }
    }

    Process { id: setLayoutProc; command: ["sh", "-c", ""] }
    Process { id: setLocaleProc; command: ["sh", "-c", ""] }

    ListModel { id: layoutModel }
    ListModel { id: localeModel }

    // ── Dim backdrop — closes modal on click ──────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // ── Centered card ─────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  440
        implicitHeight: contentCol.implicitHeight + 32
        radius: 14
        color:  Theme.base

        layer.enabled: true
        layer.effect: null

        // Thin accent border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
            border.width: 1
        }

        // Stop backdrop click from passing through
        MouseArea { anchors.fill: parent }

        Column {
            id: contentCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
            }
            spacing: 0

            // ── Header ────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 48
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "󰌌"
                        font.pixelSize: 20
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Teclado e Idioma"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: root.currentLayout + "  ·  " + root.currentLocale
                            font.pixelSize: 11
                            color: Theme.muted1
                        }
                    }
                }

                // Close button
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 26; height: 26; radius: 13
                    color: closeMA.containsMouse ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.pixelSize: 13
                        color: Theme.muted1
                    }

                    MouseArea {
                        id: closeMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            // ── Tabs ──────────────────────────────────────────────────────
            Item {
                id: tabBar
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 4

                    Repeater {
                        model: root.tabs
                        delegate: Rectangle {
                            required property var modelData
                            height: 26
                            width: tabInner.implicitWidth + 20
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 7
                            color: root.activeTab === modelData.id
                                   ? Theme.accentSurface : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                id: tabInner
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.activeTab === modelData.id
                                           ? Theme.accent : Theme.muted3
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    text: modelData.label
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.activeTab === modelData.id
                                           ? Theme.accent : Theme.muted3
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = modelData.id
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    height: 1
                    color: Theme.surface2
                }
            }

            // ── Tab: Teclado ──────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8
                visible: root.activeTab === "keyboard"

                // Buscador
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 8
                    color: Theme.surface2

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.pixelSize: 14
                            color: Theme.muted2
                        }

                        TextInput {
                            id: layoutSearchInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28
                            font.pixelSize: 12
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.text
                            clip: true
                            onTextChanged: {
                                root.layoutSearch = text
                                root.rebuildLayoutModels()
                            }

                            Text {
                                anchors.fill: parent
                                text: "Buscar distribución..."
                                font.pixelSize: 12
                                color: Theme.muted2
                                visible: !parent.text && !parent.activeFocus
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.min(layoutModel.count, 7) * 36 + 8
                    visible: layoutModel.count > 0

                    ListView {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        clip: true
                        model: layoutModel
                        spacing: 4

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4; radius: 2; color: Theme.surface3
                            }
                        }

                        delegate: Rectangle {
                            required property string label
                            required property string code
                            width: ListView.view.width
                            height: 34
                            radius: 8
                            color: layoutAllMA.containsMouse
                                   ? Theme.surface3
                                   : (root._layoutActive(code)
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                        : Theme.surface2)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Rectangle {
                                visible: root._layoutActive(code)
                                width: 3; height: 16; radius: 2
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                color: Theme.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                text: label
                                font.pixelSize: 12
                                color: Theme.text
                            }

                            Rectangle {
                                visible: root._layoutActive(code)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 8
                                height: 18
                                radius: 9
                                color: Theme.accentSurface
                                width: chipTextAll.implicitWidth + 12

                                Text {
                                    id: chipTextAll
                                    anchors.centerIn: parent
                                    text: "Actual"
                                    font.pixelSize: 10
                                    color: Theme.accent
                                }
                            }

                            MouseArea {
                                id: layoutAllMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setLayout(code)
                            }
                        }
                    }
                }

                // Sin resultados
                Item {
                    width: parent.width
                    height: 44
                    visible: layoutModel.count === 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "No encontrado"; font.pixelSize: 12; color: Theme.muted2 }
                        Rectangle {
                            height: 22
                            radius: 11
                            color: Theme.surface2
                            width: clearLayoutText.implicitWidth + 14

                            Text {
                                id: clearLayoutText
                                anchors.centerIn: parent
                                text: "Mostrar todo"
                                font.pixelSize: 11
                                color: Theme.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    layoutSearchInput.text = ""
                                    root.layoutSearch = ""
                                    root.rebuildLayoutModels()
                                }
                            }
                        }
                    }
                }
            }

            // ── Tab: Idioma ───────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8
                visible: root.activeTab === "language"

                // Buscador
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 8
                    color: Theme.surface2

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.pixelSize: 14
                            color: Theme.muted2
                        }

                        TextInput {
                            id: localeSearchInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28
                            font.pixelSize: 12
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.text
                            clip: true
                            onTextChanged: {
                                root.localeSearch = text
                                root.rebuildLocaleModels()
                            }

                            Text {
                                anchors.fill: parent
                                text: "Buscar idioma del sistema..."
                                font.pixelSize: 12
                                color: Theme.muted2
                                visible: !parent.text && !parent.activeFocus
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Text {
                    text: root._localesAvailable ? "" : "localectl no disponible"
                    font.pixelSize: 11
                    color: Theme.warning
                    visible: !root._localesAvailable
                }

                Item {
                    width: parent.width
                    height: Math.min(localeModel.count, 7) * 36 + 8
                    visible: localeModel.count > 0

                    ListView {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        clip: true
                        model: localeModel
                        spacing: 4

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4; radius: 2; color: Theme.surface3
                            }
                        }

                        delegate: Rectangle {
                            required property string label
                            required property string value
                            width: ListView.view.width
                            height: 34
                            radius: 8
                            color: localeAllMA.containsMouse
                                   ? Theme.surface3
                                   : (root._localeActive(value)
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                        : Theme.surface2)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            opacity: root._localesAvailable ? 1 : 0.45

                            Rectangle {
                                visible: root._localeActive(value)
                                width: 3; height: 16; radius: 2
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                color: Theme.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                text: label
                                font.pixelSize: 12
                                color: Theme.text
                            }

                            Rectangle {
                                visible: root._localeActive(value)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 8
                                height: 18
                                radius: 9
                                color: Theme.accentSurface
                                width: localeChipTextAll.implicitWidth + 12

                                Text {
                                    id: localeChipTextAll
                                    anchors.centerIn: parent
                                    text: "Actual"
                                    font.pixelSize: 10
                                    color: Theme.accent
                                }
                            }

                            MouseArea {
                                id: localeAllMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root._localesAvailable ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                enabled: root._localesAvailable
                                onClicked: root.setLocale(value)
                            }
                        }
                    }
                }

                // Sin resultados
                Item {
                    width: parent.width
                    height: 44
                    visible: localeModel.count === 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "No encontrado"; font.pixelSize: 12; color: Theme.muted2 }
                        Rectangle {
                            height: 22
                            radius: 11
                            color: Theme.surface2
                            width: clearLocaleText.implicitWidth + 14

                            Text {
                                id: clearLocaleText
                                anchors.centerIn: parent
                                text: "Mostrar todo"
                                font.pixelSize: 11
                                color: Theme.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    localeSearchInput.text = ""
                                    root.localeSearch = ""
                                    root.rebuildLocaleModels()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

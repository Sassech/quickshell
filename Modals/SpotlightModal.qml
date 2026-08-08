// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // ── Estado ────────────────────────────────────────────────
    property string _searchBuf: ""
    property bool   _searching: false
    property int    selectedIndex: 0
    property string activeTab: "all"

    // Dimensiones de la grilla
    readonly property int _cellSize:   88   // ancho de cada celda
    readonly property int _cellHeight: 96   // alto de cada celda (ícono + label)
    readonly property int _cols:       6    // columnas visibles por fila
    readonly property int _maxRows:    3    // filas máximas antes de scrollear

    readonly property var tabs: [
        { id: "all",  label: "Todo",     icon: "󰍉" },
        { id: "app",  label: "Apps",     icon: "󰣆" },
        { id: "file", label: "Archivos", icon: "󰉋" },
        { id: "cmd",  label: "Comandos", icon: "󰆍" },
        { id: "calc", label: "Calc",     icon: "󰃬" },
    ]

    ListModel { id: filteredModel }

    // Array JS fuente — evita ListModel.get(i) en loop (lento)
    property var _results: []

    function getCurrentTabIndex() {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id === activeTab) return i
        }
        return 0
    }

    function getTypeColor(type) {
        switch(type) {
            case "calc": return Theme.success
            case "app":  return Theme.accent
            case "file": return Theme.yellow
            case "cmd":  return Theme.accent2
            default:     return Theme.muted3
        }
    }

    function getTypeColorSurface(type) {
        switch(type) {
            case "calc": return Theme.successSurface
            case "app":  return Theme.accentSurface
            case "file": return Theme.surface3
            case "cmd":  return Theme.accentDim
            default:     return Theme.cardBg3
        }
    }

    function rebuildFiltered() {
        filteredModel.clear()
        // Iteramos el array JS nativo — más rápido que ListModel.get(i)
        for (var i = 0; i < root._results.length; i++) {
            var item = root._results[i]
            if (activeTab === "all" || item.type === activeTab)
                filteredModel.append(item)
        }
        selectedIndex = Math.min(selectedIndex, Math.max(0, filteredModel.count - 1))
    }

    onActiveTabChanged: rebuildFiltered()

    // ── Búsqueda ──────────────────────────────────────────────
    Process {
        id: searchProc
        property string query: ""
        command: searchProc.query === "--list-apps"
            ? [Paths.scripts + "/qs-helper/qs-helper",
               "spotlight",
               "--list-apps"]
            : [Paths.scripts + "/qs-helper/qs-helper",
               "spotlight",
               searchProc.query]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._searchBuf += data + "\n"
        }
        // qmllint disable signal-handler-parameters
        onExited: {
            root._searching = false
            var items = []
            try { items = JSON.parse(root._searchBuf) } catch(e) {}
            root._results = items
            root.rebuildFiltered()
        }
        // qmllint enable signal-handler-parameters
    }

    // Debounce 150ms
    Timer {
        id: debounce
        interval: 150
        onTriggered: root.runSearch(searchInput.text.trim())
    }

    function runSearch(q) {
        if (searchProc.running) {
            searchProc.running = false
        }
        _searchBuf = ""
        _searching = true
        searchProc.query = q
        searchProc.running = true
    }

    function loadDefaultApps() {
        _searchBuf = ""
        _searching = true
        searchProc.query = "--list-apps"
        searchProc.running = true
    }

    function openSpotlight() {
        root._results = []
        filteredModel.clear()
        searchInput.text = ""
        selectedIndex = 0
        activeTab = "all"
        visible = true
        searchInput.forceActiveFocus()
        loadDefaultApps()
    }

    function closeSpotlight(keepLauncherAlive) {
        visible = false
        searchProc.running = false
        debounce.stop()
        if (keepLauncherAlive !== true) {
            launcher.running = false
        }
    }

    Component.onDestruction: {
        searchProc.running = false
        debounce.stop()
    }

    function launchSelected() {
        if (filteredModel.count === 0) return
        const idx = Math.min(selectedIndex, filteredModel.count - 1)
        const item = filteredModel.get(idx)

        if (item.execArgs && item.execArgs.length > 0) {
            // startDetached: el proceso no muere si Quickshell recarga o se cierra
            launcher.command = item.execArgs
            launcher.startDetached()
            closeSpotlight(true)
            return
        }

        if (!item || !item.exec) return

        // exec legacy: lanzar desatado del proceso principal
        launcher.command = ["bash", "-c", item.exec]
        launcher.startDetached()
        closeSpotlight(true)
    }

    Process {
        id: launcher
        running: false
    }

    onVisibleChanged: {
        if (visible) searchInput.forceActiveFocus()
    }

    // ── UI ────────────────────────────────────────────────────

    // Overlay oscuro — click fuera cierra
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSpotlight()
        }
    }

    // ── Card ──────────────────────────────────────────────────
    Rectangle {
        id: card

        // Ancho = cols × cellSize + márgenes laterales (16px c/u)
        readonly property int gridW: root._cols * root._cellSize + 32

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(80, root.height * 0.18)

        width: gridW
        height: {
            var rows = filteredModel.count > 0
                ? Math.min(Math.ceil(filteredModel.count / root._cols), root._maxRows)
                : 0
            return searchBar.height
                 + tabBar.height
                 + (rows > 0 ? rows * root._cellHeight + 16 : 0)
                 + (filteredModel.count === 0 && !root._searching ? 72 : 0)
                 + 2
        }

        radius: 16
        color: Theme.cardBg3
        border.color: Theme.surface2
        border.width: 1

        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // Sombra
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: -8
            width: parent.width - 32
            height: 20
            radius: 8
            color: "#55000000"
            z: -1
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            // ── Barra de búsqueda ─────────────────────────────
            Item {
                id: searchBar
                width: parent.width
                height: 64

                RowLayout {
                    x: 20
                    width: parent.width - 40
                    height: parent.height
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: -4
                        Layout.rightMargin: -4

                        // Icono lupa / spinner
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root._searching ? "󰔟" : "󰍉"
                            font.pixelSize: 22
                            color: searchInput.text !== "" ? Theme.accent2 : Theme.muted3

                            RotationAnimation on rotation {
                                running: root._searching
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }

                        // Foco visual
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            border.color: searchInput.activeFocus ? Theme.accent : "transparent"
                            border.width: 2
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            leftPadding: 46
                            rightPadding: 12
                            font.pixelSize: 20
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.text
                            clip: true

                            Text {
                                anchors.fill: parent
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Buscar aplicaciones, archivos, comandos..."
                                font.pixelSize: 18
                                color: Theme.surface2
                                visible: !parent.text && !parent.activeFocus
                                verticalAlignment: Text.AlignVCenter
                            }

                            onTextChanged: {
                                root.selectedIndex = 0
                                if (text.trim() === "") {
                                    debounce.stop()
                                    searchProc.running = false
                                    root.loadDefaultApps()
                                } else {
                                    debounce.restart()
                                }
                            }

                            Keys.onEscapePressed: root.closeSpotlight()
                            Keys.onReturnPressed: root.launchSelected()
                            Keys.onEnterPressed:  root.launchSelected()

                            // Navegación grilla: ←→↑↓
                            Keys.onLeftPressed: {
                                if (root.selectedIndex > 0) {
                                    root.selectedIndex--
                                    gridView.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                }
                            }
                            Keys.onRightPressed: {
                                if (root.selectedIndex < filteredModel.count - 1) {
                                    root.selectedIndex++
                                    gridView.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                }
                            }
                            Keys.onUpPressed: {
                                var next = root.selectedIndex - root._cols
                                if (next >= 0) {
                                    root.selectedIndex = next
                                    gridView.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                }
                            }
                            Keys.onDownPressed: {
                                var next = root.selectedIndex + root._cols
                                if (next < filteredModel.count) {
                                    root.selectedIndex = next
                                    gridView.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                }
                            }

                            Keys.onTabPressed: {
                                var cur = root.getCurrentTabIndex()
                                root.activeTab = root.tabs[(cur + 1) % root.tabs.length].id
                            }
                            Keys.onBacktabPressed: {
                                var cur = root.getCurrentTabIndex()
                                root.activeTab = root.tabs[(cur - 1 + root.tabs.length) % root.tabs.length].id
                            }

                            Keys.onPressed: function(event) {
                                if (event.modifiers & Qt.ControlModifier) {
                                    var num = parseInt(event.text)
                                    if (num >= 1 && num <= root.tabs.length) {
                                        root.activeTab = root.tabs[num - 1].id
                                        event.accepted = true
                                    }
                                }
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

            // ── Barra de pestañas ─────────────────────────────
            Item {
                id: tabBar
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 12
                    rightPadding: 12
                    spacing: 4

                    Repeater {
                        model: root.tabs
                        delegate: Rectangle {
                            id: tabDelegate
                            required property var modelData
                            height: 26
                            width: tabInner.implicitWidth + 20
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 7
                            color: root.activeTab === tabDelegate.modelData.id
                                   ? Theme.accentSurface : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                id: tabInner
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: tabDelegate.modelData.icon
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    color: root.activeTab === tabDelegate.modelData.id
                                           ? Theme.accent : Theme.muted3
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    text: tabDelegate.modelData.label
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    color: root.activeTab === tabDelegate.modelData.id
                                           ? Theme.accent : Theme.muted3
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = tabDelegate.modelData.id
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
                    visible: filteredModel.count > 0
                }
            }

            // ── Grilla de resultados ──────────────────────────
            Item {
                width: parent.width
                height: Math.min(Math.ceil(filteredModel.count / root._cols), root._maxRows)
                         * root._cellHeight + 16
                visible: filteredModel.count > 0

                GridView {
                    id: gridView
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    clip: true
                    reuseItems: true

                    model: filteredModel
                    cellWidth:  root._cellSize
                    cellHeight: root._cellHeight

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4; radius: 2; color: Theme.surface3
                        }
                    }

                    delegate: Item {
                        id: gridCell
                        required property var   model
                        required property int   index

                        width:  root._cellSize
                        height: root._cellHeight

                        readonly property bool isSelected: gridCell.index === root.selectedIndex

                        ListView.onPooled:  iconImage.source = ""
                        ListView.onReused:  iconImage.source = (gridCell.model.iconPath !== "")
                                            ? ("file://" + gridCell.model.iconPath) : ""

                        // Fondo hover/selected
                        Rectangle {
                            anchors.centerIn: parent
                            width:  72
                            height: 80
                            radius: 12
                            color: gridCell.isSelected
                                   ? Theme.accentSurface
                                   : (cellHover.containsMouse ? Theme.surface2 : "transparent")
                            Behavior on color { ColorAnimation { duration: 80 } }

                            // Borde de selección
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: gridCell.isSelected ? 2 : 0
                                Behavior on border.width { NumberAnimation { duration: 80 } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                // ── Ícono ─────────────────────
                                Item {
                                    width: 48; height: 48
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Image {
                                        id: iconImage
                                        anchors.fill: parent
                                        source: (gridCell.model.iconPath !== "")
                                                ? ("file://" + gridCell.model.iconPath)
                                                : ""
                                        visible: gridCell.model.iconPath !== ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: gridCell.model.icon
                                        font.pixelSize: 28
                                        visible: gridCell.model.iconPath === ""
                                        color: root.getTypeColor(gridCell.model.type)
                                    }
                                }

                                // ── Nombre ────────────────────
                                Text {
                                    width: 68
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: gridCell.model.name
                                    font.pixelSize: 10
                                    color: gridCell.isSelected ? Theme.accent : Theme.text
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                            }
                        }

                        MouseArea {
                            id: cellHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = gridCell.index
                            onClicked: {
                                root.selectedIndex = gridCell.index
                                root.launchSelected()
                            }
                        }
                    }
                }
            }

            // ── Sin resultados / ayuda ────────────────────────
            Item {
                width: parent.width
                height: 72
                visible: filteredModel.count === 0 && !root._searching

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.activeTab === "calc" && searchInput.text === "")
                              ? "󰃬" : "󰇾"
                        font.pixelSize: 24
                        color: Theme.surface2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 12
                        color: Theme.surface3
                        text: {
                            if (root.activeTab === "calc" && searchInput.text === "")
                                return "Escribe una expresión matemática"
                            if (searchInput.text !== "" && root._results.length > 0)
                                return "Sin resultados en esta categoría"
                            return "Sin resultados"
                        }
                    }
                }
            }
        }
    }
}

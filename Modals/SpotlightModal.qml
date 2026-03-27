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

    readonly property var tabs: [
        { id: "all",  label: "Todo",     icon: "󰍉" },
        { id: "app",  label: "Apps",     icon: "󰣆" },
        { id: "file", label: "Archivos", icon: "󰉋" },
        { id: "cmd",  label: "Comandos", icon: "󰆍" },
        { id: "calc", label: "Calc",     icon: "󰃬" },
    ]

    ListModel { id: resultModel }
    ListModel { id: filteredModel }

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
            default:     return Theme.base
        }
    }

    function rebuildFiltered() {
        filteredModel.clear()
        for (var i = 0; i < resultModel.count; i++) {
            var item = resultModel.get(i)
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
            ? ["python3",
               "/home/sassech/.config/quickshell/scripts/spotlight-search.py",
               "--list-apps"]
            : ["python3",
               "/home/sassech/.config/quickshell/scripts/spotlight-search.py",
               searchProc.query]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._searchBuf += data + "\n"
        }
        onExited: {
            root._searching = false
            var items = []
            try { items = JSON.parse(root._searchBuf) } catch(e) {}
            resultModel.clear()
            for (var i = 0; i < items.length; i++) resultModel.append(items[i])
            root.rebuildFiltered()
        }
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
        resultModel.clear()
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

    function sanitizeExec(exec) {
        if (!exec) return ""
        if (exec.includes(" ") || exec.includes("'") || exec.includes('"')) {
            return exec.replace(/'/g, "'\\''")
        }
        return exec
    }

    function launchSelected() {
        console.log("launchSelected called, count:", filteredModel.count, "selectedIndex:", selectedIndex)
        if (filteredModel.count === 0) return
        var idx = Math.min(selectedIndex, filteredModel.count - 1)
        var item = filteredModel.get(idx)
        console.log("Launching item:", JSON.stringify(item))
        if (!item || !item.exec) {
            console.log("No item or no exec")
            return
        }
        launcher.running = false
        var exec = item.exec
        var cmd
        if (exec.includes(" ") || exec.includes("'") || exec.includes('"')) {
            cmd = "setsid bash -c 'setsid " + exec.replace(/'/g, "'\\''") + "' &>/dev/null &"
        } else {
            cmd = "setsid " + exec + " &>/dev/null &"
        }
        console.log("Executing:", cmd)
        launcher.command = ["bash", "-c", cmd]
        launcher.running = true
        closeSpotlight(true)
    }

    Process {
        id: launcher
        running: false
        onExited: {
            console.log("Launcher exited")
            running = false
        }
    }

    onVisibleChanged: {
        if (visible) searchInput.forceActiveFocus()
    }

    // UI ─────────────────────────────────────────────────────────────────

    // Overlay oscuro — click fuera cierra
    Rectangle {
        anchors.fill: parent
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSpotlight()
        }
    }

    // Card central
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(80, root.height * 0.18)

        width: 660
        height: searchBar.height
                + tabBar.height
                + (filteredModel.count > 0 ? Math.min(filteredModel.count, 8) * 56 + 12 : 0)
                + (filteredModel.count === 0 && !_searching ? 64 : 0)
                + 2
        radius: 16
        color: Theme.base
        border.color: Theme.surface2
        border.width: 1

        // Sombra (bloque relleno más oscuro debajo)
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

        // Stripe superior
        Rectangle {
            width: parent.width; height: 3; radius: 3
            anchors.top: parent.top
            color: Theme.accent2
            Rectangle {
                width: parent.width * 0.4; height: parent.height
                anchors.right: parent.right
                color: Theme.accent
            }
        }

        // Consume clicks dentro del card
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

                    // Contenedor para input + foco visual + icono
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: -4
                        Layout.rightMargin: -4

                        // Icono lupa
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: _searching ? "󰔟" : "󰍉"
                            font.pixelSize: 22
                            color: searchInput.text !== "" ? Theme.accent2 : Theme.muted3

                            RotationAnimation on rotation {
                                running: _searching
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }

                        // Foco visual (fondo del input)
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

                            // Placeholder
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

                        Keys.onUpPressed: {
                            if (root.selectedIndex > 0) root.selectedIndex--
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        }
                        Keys.onDownPressed: {
                            if (root.selectedIndex < filteredModel.count - 1) root.selectedIndex++
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        }
                        Keys.onTabPressed: {
                            var cur = root.getCurrentTabIndex()
                            root.activeTab = root.tabs[(cur + 1) % root.tabs.length].id
                        }
                        Keys.onBacktabPressed: {
                            var cur = root.getCurrentTabIndex()
                            root.activeTab = root.tabs[(cur - 1 + root.tabs.length) % root.tabs.length].id
                        }

                        // Atajos Ctrl+1-5 para tabs
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

                // Separador
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
                                    verticalAlignment: Text.AlignVCenter
                                    color: root.activeTab === modelData.id
                                           ? Theme.accent : Theme.muted3
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    text: modelData.label
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
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
                    visible: filteredModel.count > 0
                }
            }

            // ── Resultados ────────────────────────────────────
            Item {
                width: parent.width
                height: Math.min(filteredModel.count, 8) * 56 + 12
                visible: filteredModel.count > 0

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    clip: true
                    model: filteredModel
                    spacing: 2

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4; radius: 2; color: Theme.surface3
                        }
                    }

                    delegate: Rectangle {
                        id: resultRow
                        width: listView.width - 8
                        height: 52
                        radius: 10
                        color: (index === root.selectedIndex)
                               ? Theme.surface2
                               : (rowHover.containsMouse ? Theme.accentSurface : "transparent")
                        Behavior on color { ColorAnimation { duration: 80 } }

                        required property var   model
                        required property int   index

                        // Indicador de selección (barra izq)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 28; radius: 2
                            color: Theme.accent2
                            visible: resultRow.index === root.selectedIndex
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            // ── Icono ──────────────────────────
                            Item {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter

                                // Imagen real (app icon)
                                Image {
                                    anchors.centerIn: parent
                                    width: 32; height: 32
                                    source: (resultRow.model.iconPath !== "")
                                            ? ("file://" + resultRow.model.iconPath)
                                            : ""
                                    visible: resultRow.model.iconPath !== ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                }

                                // Icono de texto fallback
                                Text {
                                    anchors.centerIn: parent
                                    text: resultRow.model.icon
                                    font.pixelSize: 22
                                    visible: resultRow.model.iconPath === ""
                                    color: root.getTypeColor(resultRow.model.type)
                                }
                            }

                            // ── Nombre + detalle ──────────────
                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: resultRow.model.name
                                    font.pixelSize: 14
                                    font.weight: Font.Normal
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: resultRow.model.detail
                                    font.pixelSize: 11
                                    color: Theme.muted3
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            // ── Badge tipo ────────────────────
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: badgeText.width + 10
                                Layout.preferredHeight: 18
                                radius: 5
                                color: root.getTypeColorSurface(resultRow.model.type)
                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: resultRow.model.type
                                    font.pixelSize: 9
                                    font.weight: Font.Normal
                                    color: root.getTypeColor(resultRow.model.type)
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = resultRow.index
                            onClicked: {
                                console.log("Row clicked, index:", resultRow.index)
                                root.selectedIndex = resultRow.index
                                root.launchSelected()
                            }
                        }
                    }
                }
            }

            // ── Sin resultados / ayuda ────────────────────────
            Item {
                width: parent.width
                height: 64
                visible: filteredModel.count === 0 && !_searching

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
                            if (searchInput.text !== "" && resultModel.count > 0)
                                return "Sin resultados en esta categoría"
                            return "Sin resultados"
                        }
                    }
                }
            }
        }
    }
}

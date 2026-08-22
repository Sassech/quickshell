// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../Components"

QmModalBase {
    id: root

    cardWidth: 780
    cardFixedHeight: 660
    cardHeightFactor: 0.86
    cardRadius: 16
    cardBorderColor: Theme.surface2
    cardClip: true
    hasStripe: true
    focusCard: true

    // ── Estado global ───────────────────────────────────────────
    property string currentWallpaper: ""
    property bool   _loading: false
    property string _errorMsg: ""

    // ── Tabs ────────────────────────────────────────────────────
    // Cada tab: { id, label, path, type }
    // type === "folder" | "search"
    // La tab "search" es siempre la última y no tiene X
    property var _tabs: [
        { id: "folder-0", label: "Imágenes", path: "~/Imágenes", type: "folder" },
        { id: "search",   label: "Buscar online",    path: "",           type: "search"  }
    ]
    property int _activeTab: 0

    // Caché en memoria de items ya cargados por carpeta (path -> items[]).
    // Se llena por el preload masivo (wallpaper-multi --daemon) y por cada
    // carga individual, para que reactivar un tab ya visitado sea instantáneo.
    property var _folderCache: ({})

    // ── Daemon JSON-lines (wallpaper-multi --daemon) ────────────────
    // Cada request lleva id = path de la carpeta; la respuesta replica ese id
    // y escribe directo al _folderCache (sin depender del orden de llegada).
    // El daemon mantiene el listado por carpeta en memoria (invalidación por
    // mtime del directorio) y reutiliza los thumbnails ya generados en disco.
    property bool _daemonReady: false
    property bool _destroying: false

    function _handleDaemonLine(data) {
        var line = (data || "").trim()
        if (line === "") return
        var msg = null
        try { msg = JSON.parse(line) } catch (e) { return }
        if (msg === null || !msg.id) return
        var cache = root._folderCache
        if (msg.error) {
            cache[msg.id] = []
            root._folderCache = cache
            root._loading = false
            loadSafetyTimer.stop()
            root._errorMsg = msg.error
            errorClearTimer.restart()
            return
        }
        cache[msg.id] = Array.isArray(msg.items) ? msg.items : []
        root._folderCache = cache
        // Si corresponde al tab activo, poblar el modelo (idempotente: una
        // carga individual y el preload pueden responder con el mismo id).
        var tab = root._tabs[root._activeTab]
        if (tab && tab.type === "folder" && tab.path === msg.id) {
            root._loading = false
            loadSafetyTimer.stop()
            imageModel.clear()
            for (var i = 0; i < cache[msg.id].length; i++) imageModel.append(cache[msg.id][i])
        }
    }

    // Alias de conveniencia: folder activo (retrocompat con saveFolder/loadImages)
    property string currentFolder: _activeTab < _tabs.length && _tabs[_activeTab].type === "folder"
        ? _tabs[_activeTab].path
        : ""

    // Carpeta destino de descargas Bing: carpeta dedicada, separada de los
    // wallpapers locales (decisión del usuario).
    property string _downloadFolder: "~/Imágenes/Bing"

    signal requestFolderBrowser(string currentPath)

    function receiveFolderResult(path) {
        // Agregar nuevo tab de carpeta con el basename como label
        var label = path.split("/").pop() || path
        var newId = "folder-" + Date.now()
        var newTabs = []
        for (var i = 0; i < _tabs.length; i++) {
            if (_tabs[i].type !== "search") newTabs.push(_tabs[i])
        }
        newTabs.push({ id: newId, label: label, path: path, type: "folder" })
        newTabs.push({ id: "search", label: "Buscar online", path: "", type: "search" })
        _tabs = newTabs
        // Activar el nuevo tab de carpeta (último antes de search)
        _activeTab = _tabs.length - 2
        _saveFolderConfig()
        loadImages()
    }

    ListModel { id: imageModel }

    // ── Lectura de config al inicio ─────────────────────────────
    FileView {
        id: wallpaperConfigFile
        path: Paths.config + "/wallpaper-config.json"
        Component.onCompleted: this.reload()
        onLoaded: {
            try {
                var cfg = JSON.parse(text())
                // Cargar tabs desde folders[] si existe
                if (Array.isArray(cfg.folders) && cfg.folders.length > 0) {
                    var loaded = []
                    for (var i = 0; i < cfg.folders.length; i++) {
                        var p = cfg.folders[i]
                        var lbl = cfg.folderLabels && cfg.folderLabels[p]
                            ? cfg.folderLabels[p]
                            : p.split("/").pop() || p
                        loaded.push({ id: "folder-" + i, label: lbl, path: p, type: "folder" })
                    }
                    loaded.push({ id: "search", label: "Buscar online", path: "", type: "search" })
                    root._tabs = loaded
                    root._activeTab = 0
                } else if (cfg.folder) {
                    // Retrocompat: campo folder único
                    var singleLabel = cfg.folder.split("/").pop() || cfg.folder
                    root._tabs = [
                        { id: "folder-0", label: singleLabel, path: cfg.folder, type: "folder" },
                        { id: "search", label: "Buscar online", path: "", type: "search" }
                    ]
                    root._activeTab = 0
                }
            } catch(e) {}
        }
    }

    FileView {
        id: wallpaperMonitorsFile
        path: Paths.config + "/wallpaper-monitors.json"
        Component.onCompleted: this.reload()
        onLoaded: {
            try {
                var perMonitor = JSON.parse(text())
                var outName = root.screen ? root.screen.name : ""
                if (outName && perMonitor[outName]) root.currentWallpaper = perMonitor[outName]
            } catch(e) {}
        }
    }

    onVisibleChanged: {
        if (visible && _tabs[_activeTab] && _tabs[_activeTab].type === "folder") {
            loadImages()
        }
        if (visible) {
            _preloadAllFolders()
        }
    }

    // ── Precarga masiva: un request por carpeta al daemon persistente, en
    // vez de relanzar `wallpaper-multi <folder1>...` como one-shot al abrir.
    function _preloadAllFolders() {
        var folders = []
        for (var i = 0; i < _tabs.length; i++) {
            if (_tabs[i].type === "folder") folders.push(_tabs[i].path)
        }
        if (folders.length === 0) return
        for (var j = 0; j < folders.length; j++) {
            root._requestFolder(folders[j], false)
        }
    }

    function _requestFolder(path, force) {
        if (!wallDaemon.running || !root._daemonReady) {
            wallDaemon.running = true
            return
        }
        wallDaemon.write(JSON.stringify({ id: path, folder: path, force: !!force }) + "\n")
    }

    // ── Daemon persistente (wallpaper-multi --daemon) ─────────────
    // Mantiene el listado y los thumbnails calientes en memoria por carpeta.
    Process {
        id: wallDaemon
        running: true
        command: [Paths.scripts + "/qs-helper/qs-helper", "wallpaper-multi", "--daemon"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._handleDaemonLine(data)
        }
        onStarted: {
            root._daemonReady = true
            if (root.visible) {
                root.loadImages()
                root._preloadAllFolders()
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: function() {
            root._daemonReady = false
            root._loading = false
            if (!root._destroying) wallDaemon.running = true
        }
        // qmllint enable signal-handler-parameters
    }

    Component.onDestruction: {
        root._destroying = true
        wallDaemon.running = false
        setProc.running = false
        searchProc.running = false
        downloadProc.running = false
        applyProc.running = false
    }

    // ── Safety timer para listado ───────────────────────────────
    Timer {
        id: loadSafetyTimer
        interval: 10000
        onTriggered: {
            root._loading = false
        }
    }

    Timer {
        id: errorClearTimer
        interval: 4000
        onTriggered: root._errorMsg = ""
    }

    // ── Carga imágenes de la carpeta activa ─────────────────────
    function loadImages(force) {
        if (_activeTab >= _tabs.length) return
        var tab = _tabs[_activeTab]
        if (!tab || tab.type !== "folder") return
        _loading = true
        imageModel.clear()
        loadSafetyTimer.restart()
        root._requestFolder(tab.path, force)
    }

    // ── Aplica wallpaper (carpeta) ──────────────────────────────
    Process {
        id: setProc
        property string pending: ""
        running: false
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.currentWallpaper = pending
            } else {
                root._errorMsg = "No se pudo aplicar el fondo de pantalla"
                errorClearTimer.restart()
            }
        }
        // qmllint enable signal-handler-parameters
    }

    function _saveFolderConfig() {
        // Construir folders[] con los tabs tipo "folder"
        var folderPaths = []
        var folderLabels = {}
        for (var i = 0; i < _tabs.length; i++) {
            if (_tabs[i].type === "folder") {
                folderPaths.push(_tabs[i].path)
                folderLabels[_tabs[i].path] = _tabs[i].label
            }
        }
        // El campo folder (retrocompat) es el primero
        var primaryFolder = folderPaths.length > 0 ? folderPaths[0] : "~/Imágenes"
        wallpaperConfigFile.setText(JSON.stringify({
            folder: primaryFolder,
            folders: folderPaths,
            folderLabels: folderLabels
        }))
    }

    // Retrocompat: recibir folder desde FolderBrowser (ya no se usa directamente,
    // receiveFolderResult lo maneja)
    function saveFolder(f) {
        receiveFolderResult(f)
    }

    // ── Estado de búsqueda Bing ─────────────────────────────────
    property bool   _searching: false
    property bool   _loadingMore: false
    property int    _searchFirst: 1         // índice 1-based del primer resultado pedido (paginación)
    property string _searchQuery: ""        // query activa (para las páginas siguientes)
    property string _busyId: ""
    property string _searchBuf: ""
    property string _errBuf: ""
    property string _searchError: ""
    property string _searchStatus: ""
    ListModel { id: resultsModel }

    // ── Bing: buscar ────────────────────────────────────────────
    function search(q) {
        var query = String(q).trim()
        if (query === "") return
        root._searching = true
        root._loadingMore = false
        root._searchFirst = 1
        root._searchQuery = query
        root._searchError = ""
        root._searchBuf = ""
        root._errBuf = ""
        resultsModel.clear()
        searchProc.command = [Paths.scripts + "/qs-helper/qs-helper", "image-search", "--first=1", query]
        searchProc.running = true
    }

    // Appende un item a resultsModel sin duplicar por id (Bing puede repetir
    // resultados entre páginas por el desfase del `first`).
    function _appendUnique(item) {
        for (var i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).id === item.id) return
        }
        resultsModel.append(item)
    }

    // ── Paginación: pide la página siguiente y APPENDE (no limpia) ────────
    function _loadMoreResults() {
        if (root._searching || root._loadingMore) return
        if (root._searchError !== "") return
        if (root._searchFirst >= 2000) return   // tope de seguridad (~57 páginas)
        root._searchFirst += 35
        root._loadingMore = true
        root._searchBuf = ""
        root._errBuf = ""
        searchProc.command = [Paths.scripts + "/qs-helper/qs-helper",
            "image-search", "--first=" + String(root._searchFirst), root._searchQuery]
        searchProc.running = true
    }

    Process {
        id: searchProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => root._searchBuf += d + "\n"
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: d => root._errBuf += d + "\n"
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            root._searching = false
            root._loadingMore = false
            if (exitCode !== 0) {
                root._searchError = root._errBuf.trim() !== ""
                    ? root._errBuf.trim()
                    : "No se pudo buscar (¿hay conexión?)"
                root._errBuf = ""
                return
            }
            var items = []
            try { items = JSON.parse(root._searchBuf) } catch(e) {}
            for (var i = 0; i < items.length; i++) root._appendUnique(items[i])
            // "Sin resultados" solo aplica a la búsqueda inicial; una página
            // posterior vacía simplemente deja de cargar en silencio.
            if (root._searchFirst === 1 && items.length === 0)
                root._searchError = "Sin resultados. Probá otra búsqueda."
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Bing: descargar + aplicar ───────────────────────────────
    function download(item) {
        if (root._busyId !== "") return
        root._busyId = item.id
        root._searchError = ""
        root._searchStatus = "Descargando..."
        // Carpeta destino: siempre la dedicada de Bing (decisión del usuario).
        downloadProc.command = [
            Paths.scripts + "/qs-helper/qs-helper", "image-download",
            String(item.id), String(item.url), root._downloadFolder
        ]
        downloadProc.running = true
    }

    Process {
        id: downloadProc
        property string buf: ""
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => downloadProc.buf += d + "\n"
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root._busyId = ""
                root._searchStatus = ""
                root._searchError = "No se pudo descargar la imagen"
                downloadProc.buf = ""
                return
            }
            var out = {}
            try { out = JSON.parse(downloadProc.buf) } catch(e) {}
            downloadProc.buf = ""
            var path = out.path || ""
            if (path === "") {
                root._busyId = ""
                root._searchStatus = ""
                root._searchError = "No se pudo descargar la imagen"
                return
            }
            applyProc.path = path
            root._searchStatus = "Aplicando..."
            applyProc.command = ["bash", Paths.scripts + "/wallpaper-set.sh", path]
            applyProc.running = true
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: applyProc
        property string path: ""
        running: false
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            root._busyId = ""
            if (exitCode !== 0) {
                root._searchStatus = ""
                root._searchError = "Se descargó pero no se pudo aplicar el fondo"
                return
            }
            root.currentWallpaper = applyProc.path
            root._searchStatus = "Aplicado: " + (applyProc.path ? applyProc.path.split("/").pop() : "")
            searchStatusTimer.restart()
        }
        // qmllint enable signal-handler-parameters
    }

    Timer {
        id: searchStatusTimer
        interval: 2000
        onTriggered: root._searchStatus = ""
    }

    // ── Renombrar tab (estado inline) ───────────────────────────
    property int  _renamingIndex: -1
    property string _renameValue: ""

    function _commitRename() {
        if (_renamingIndex < 0 || _renamingIndex >= _tabs.length) {
            _renamingIndex = -1
            return
        }
        var v = _renameValue.trim()
        if (v !== "") {
            var copy = []
            for (var i = 0; i < _tabs.length; i++) {
                var t = _tabs[i]
                if (i === _renamingIndex) {
                    copy.push({ id: t.id, label: v, path: t.path, type: t.type })
                } else {
                    copy.push(t)
                }
            }
            _tabs = copy
            _saveFolderConfig()
        }
        _renamingIndex = -1
    }

    // ── UI ──────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 20
        spacing: 8

        // ── Header ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰡔"
                font.pixelSize: 18
                color: Theme.accent2
            }
            Text {
                text: "Fondos de pantalla"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                text: root._activeTab < root._tabs.length && root._tabs[root._activeTab].type === "folder"
                    ? "(" + imageModel.count + ")"
                    : ""
                font.pixelSize: 13
                color: Theme.muted3
                visible: !root._loading && root._activeTab < root._tabs.length && root._tabs[root._activeTab].type === "folder"
            }
            Text {
                text: "cargando..."
                font.pixelSize: 12
                color: Theme.muted3
                visible: root._loading
            }
            Text {
                text: root._errorMsg
                font.pixelSize: 12
                color: Theme.error
                visible: root._errorMsg !== ""
            }

            // Refresh manual de la carpeta activa (borra su entrada de caché
            // y fuerza recarga individual — no toca las demás carpetas)
            Rectangle {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 6
                visible: root._activeTab < root._tabs.length && root._tabs[root._activeTab].type === "folder"
                color: refreshMa.containsMouse ? Theme.surface3 : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.pixelSize: 13
                    color: refreshMa.containsMouse ? Theme.accent2 : Theme.muted3
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var path = root.currentFolder
                        if (path !== "") {
                            var cache = root._folderCache
                            delete cache[path]
                            root._folderCache = cache
                        }
                        root.loadImages(true)
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Status de búsqueda/descarga (solo visible en tab search)
            Text {
                text: root._searchStatus
                font.pixelSize: 12
                color: Theme.success
                visible: root._searchStatus !== "" &&
                    root._activeTab < root._tabs.length &&
                    root._tabs[root._activeTab].type === "search"
            }

            // Botón cerrar
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                color: closeMa.containsMouse ? Theme.surface3 : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 13
                    color: closeMa.containsMouse ? Theme.text : Theme.muted3
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        // ── Barra de tabs ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            // Tabs scrollables
            Row {
                spacing: 2

                Repeater {
                    model: root._tabs

                    // Delegate de tab
                    Rectangle {
                        id: tabItem
                        required property var   modelData
                        required property int   index

                        property bool isActive:  index === root._activeTab
                        property bool isSearch:  modelData.type === "search"
                        property bool isHovered: tabItemMa.containsMouse

                        width: tabContentRow.implicitWidth + 20
                        height: 32
                        radius: 8
                        color: isActive
                            ? Theme.surface3
                            : (isHovered ? Theme.surface2 : "transparent")
                        border.color: isActive ? Theme.accent2 : "transparent"
                        border.width: isActive ? 1 : 0
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            id: tabContentRow
                            anchors.centerIn: parent
                            spacing: 4

                            // Ícono lupa para search
                            Text {
                                visible: tabItem.isSearch
                                text: "󰍋"
                                font.pixelSize: 13
                                color: tabItem.isActive ? Theme.accent2 : Theme.muted3
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Label o TextField inline para renombrar
                            Loader {
                                id: labelLoader
                                anchors.verticalCenter: parent.verticalCenter

                                // Modo renombrar: solo para tab de carpeta activa
                                property bool renaming: !tabItem.isSearch &&
                                    tabItem.isActive &&
                                    root._renamingIndex === tabItem.index

                                sourceComponent: renaming ? renameFieldComp : labelComp

                                Component {
                                    id: labelComp
                                    Text {
                                        text: tabItem.modelData.label
                                        font.pixelSize: 12
                                        color: tabItem.isActive ? Theme.text : Theme.muted3
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                }

                                Component {
                                    id: renameFieldComp
                                    TextField {
                                        id: renField
                                        implicitWidth: Math.max(60, contentWidth + 16)
                                        implicitHeight: 22
                                        text: root._renameValue
                                        color: Theme.text
                                        selectionColor: Theme.accent2
                                        font.pixelSize: 12
                                        background: Rectangle {
                                            color: Theme.surface2
                                            radius: 4
                                            border.color: Theme.accent2
                                            border.width: 1
                                        }
                                        Component.onCompleted: {
                                            forceActiveFocus()
                                            selectAll()
                                        }
                                        onTextChanged: root._renameValue = text
                                        onAccepted: root._commitRename()
                                        onActiveFocusChanged: {
                                            if (!activeFocus) root._commitRename()
                                        }
                                    }
                                }
                            }

                            // Botón X (solo en tabs de carpeta, visible en hover)
                            Rectangle {
                                visible: !tabItem.isSearch && tabItem.isHovered && root._tabs.filter(function(t) { return t.type === "folder" }).length > 1
                                width: 16; height: 16; radius: 4
                                color: closeFolderMa.containsMouse ? Theme.error : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 9
                                    color: closeFolderMa.containsMouse ? Theme.cardBg3 : Theme.muted3
                                }
                                MouseArea {
                                    id: closeFolderMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var idx = tabItem.index
                                        var removedPath = root._tabs[idx].path
                                        var newTabs = []
                                        for (var i = 0; i < root._tabs.length; i++) {
                                            if (i !== idx) newTabs.push(root._tabs[i])
                                        }
                                        // Ajustar activeTab
                                        var newActive = root._activeTab
                                        if (newActive >= idx) {
                                            newActive = Math.max(0, newActive - 1)
                                        }
                                        root._tabs = newTabs
                                        // Asegurarse de que el nuevo active sea folder si existe
                                        if (newTabs[newActive] && newTabs[newActive].type === "search") {
                                            newActive = Math.max(0, newActive - 1)
                                        }
                                        root._activeTab = newActive
                                        var cache = root._folderCache
                                        delete cache[removedPath]
                                        root._folderCache = cache
                                        root._saveFolderConfig()
                                        if (newTabs[root._activeTab] && newTabs[root._activeTab].type === "folder") {
                                            root.loadImages()
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Doble clic en tab de carpeta activo → renombrar
                            onDoubleClicked: {
                                if (!tabItem.isSearch && tabItem.isActive && root._renamingIndex < 0) {
                                    root._renameValue = tabItem.modelData.label
                                    root._renamingIndex = tabItem.index
                                }
                            }
                            onClicked: {
                                if (root._renamingIndex >= 0) {
                                    root._commitRename()
                                    return
                                }
                                if (tabItem.index === root._activeTab) return
                                root._activeTab = tabItem.index
                                imageModel.clear()
                                root._loading = false
                                if (tabItem.modelData.type === "folder") {
                                    var cached = root._folderCache[tabItem.modelData.path]
                                    if (cached) {
                                        for (var i = 0; i < cached.length; i++) imageModel.append(cached[i])
                                    } else {
                                        root.loadImages()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Botón + para agregar carpeta
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 7
                color: addTabMa.containsMouse ? Theme.surface2 : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Layout.alignment: Qt.AlignVCenter
                // Margen izquierdo manual con un Item separador
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 16
                    color: addTabMa.containsMouse ? Theme.accent2 : Theme.muted3
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                MouseArea {
                    id: addTabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Abrir FolderBrowser con la carpeta activa o ~/
                        var path = root.currentFolder !== "" ? root.currentFolder : "~/"
                        root.requestFolderBrowser(path)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Separador bajo tabs
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.surface2
        }

        // ── Contenido del tab activo ────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Vista: carpeta ──────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                visible: root._activeTab < root._tabs.length && root._tabs[root._activeTab].type === "folder"

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Sin imágenes
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: imageModel.count === 0 && !root._loading
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰋯"
                            font.pixelSize: 36
                            color: Theme.surface2
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No se encontraron imágenes en esta carpeta"
                            font.pixelSize: 12
                            color: Theme.surface3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Formatos: jpg, png, webp, bmp, gif, mp4, webm, mkv, mov"
                            font.pixelSize: 11
                            color: Theme.surface2
                        }
                    }

                    // Spinner de carga
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: root._loading
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰔟"
                            font.pixelSize: 32
                            color: Theme.accent2
                            RotationAnimation on rotation {
                                running: root._loading
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Generando miniaturas..."
                            font.pixelSize: 12
                            color: Theme.muted3
                        }
                    }

                    GridView {
                        id: gridView
                        anchors.fill: parent
                        visible: imageModel.count > 0
                        model: imageModel
                        clip: true
                        reuseItems: true

                        cellWidth:  Math.floor(gridView.width / 3)
                        cellHeight: 158

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4; radius: 2; color: Theme.surface3
                            }
                        }

                        delegate: Item {
                            id: wpCell
                            width:  GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            required property var   model
                            required property int   index

                            property bool isActive: root.currentWallpaper === wpCell.model.path

                            ListView.onPooled:  { thumb.source = "" }
                            ListView.onReused:  { thumb.source = wpCell.model.thumb !== "" ? ("file://" + wpCell.model.thumb) : "" }

                            Rectangle {
                                id: cellBg
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 10
                                color: cellMa.containsMouse ? Theme.surface2 : Theme.cardBg3
                                border.color: wpCell.isActive ? Theme.accent2 : (cellMa.containsMouse ? Theme.surface3 : Theme.surface2)
                                border.width: wpCell.isActive ? 2 : 1
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                Image {
                                    id: thumb
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 120
                                    source: wpCell.model.thumb !== "" ? ("file://" + wpCell.model.thumb) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.cardBg3
                                        visible: thumb.status !== Image.Ready
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰋯"
                                            font.pixelSize: 28
                                            color: Theme.surface2
                                        }
                                    }
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    anchors.bottomMargin: 4
                                    height: 30
                                    text: wpCell.model.name
                                    font.pixelSize: 10
                                    color: Theme.muted1
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Badge activo
                                Rectangle {
                                    visible: wpCell.isActive
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 22; height: 22; radius: 11
                                    color: Theme.accent2
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰄬"
                                        font.pixelSize: 12
                                        color: Theme.cardBg3
                                    }
                                }

                                // Badge video
                                Rectangle {
                                    visible: wpCell.model.type === "video"
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 22; height: 22; radius: 11
                                    color: Theme.cardBg3
                                    border.color: Theme.accent2
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐊"
                                        font.pixelSize: 11
                                        color: Theme.accent2
                                    }
                                }

                                // Hover overlay
                                Rectangle {
                                    anchors.fill: thumb
                                    color: Theme.hover2
                                    visible: cellMa.containsMouse && !wpCell.isActive
                                    radius: parent.radius
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    setProc.pending = wpCell.model.path
                                    var outName = root.screen ? root.screen.name : ""
                                    var cmd = ["bash", Paths.scripts + "/wallpaper-set.sh", wpCell.model.path]
                                    if (outName) cmd.push(outName)
                                    setProc.command = cmd
                                    setProc.running = true
                                }
                            }
                        }
                    }
                }
            }

            // ── Vista: búsqueda online (Bing) ───────────────────
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                visible: root._activeTab < root._tabs.length && root._tabs[root._activeTab].type === "search"

                // Fila de búsqueda
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Theme.cardBg3
                        border.color: Theme.surface2
                        border.width: 1

                        TextField {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            placeholderText: "Buscar imágenes en Bing..."
                            placeholderTextColor: Theme.muted3
                            color: Theme.text
                            selectionColor: Theme.accent2
                            background: Item {}
                            onAccepted: root.search(searchInput.text)
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10
                        color: searchBtnMa.containsMouse ? Theme.surface3 : Theme.surface2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰍉"
                            font.pixelSize: 16
                            color: searchBtnMa.containsMouse ? Theme.accent : Theme.text
                        }
                        MouseArea {
                            id: searchBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.search(searchInput.text)
                        }
                    }
                }

                // Error de búsqueda
                Text {
                    Layout.fillWidth: true
                    text: root._searchError
                    font.pixelSize: 12
                    color: Theme.error
                    visible: root._searchError !== ""
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                // Grid de resultados Bing
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Spinner
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: root._searching
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰔟"
                            font.pixelSize: 32
                            color: Theme.accent2
                            RotationAnimation on rotation {
                                running: root._searching
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Buscando..."
                            font.pixelSize: 12
                            color: Theme.muted3
                        }
                    }

                    // Vacío
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: resultsModel.count === 0 && !root._searching && root._searchError === ""
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰍋"
                            font.pixelSize: 36
                            color: Theme.surface2
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Buscá imágenes para usar como fondo"
                            font.pixelSize: 12
                            color: Theme.surface3
                        }
                    }

                    GridView {
                        id: searchGrid
                        anchors.fill: parent
                        visible: resultsModel.count > 0
                        model: resultsModel
                        clip: true
                        reuseItems: true

                        // Paginación: al llegar al final pide la página siguiente.
                        // _loadingMore/_searching evitan disparos duplicados.
                        onAtYEndChanged: {
                            if (searchGrid.atYEnd) root._loadMoreResults()
                        }

                        cellWidth: Math.floor(searchGrid.width / 3)
                        cellHeight: Math.floor(searchGrid.width / 3 * 0.72)

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4; radius: 2; color: Theme.surface3
                            }
                        }

                        delegate: Item {
                            id: bingCell
                            width:  GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            required property var model
                            required property int index

                            ListView.onPooled:  { bingThumb.source = "" }
                            ListView.onReused:  { bingThumb.source = bingCell.model.thumb }

                            Rectangle {
                                id: bingCellBg
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 10
                                color: bingCellMa.containsMouse ? Theme.surface2 : Theme.cardBg3
                                border.color: bingCellMa.containsMouse ? Theme.surface3 : Theme.surface2
                                border.width: 1
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                // Thumbnail (hotlink CDN Bing)
                                Image {
                                    id: bingThumb
                                    anchors.fill: parent
                                    source: bingCell.model.thumb
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.cardBg3
                                        visible: bingThumb.status !== Image.Ready
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰉏"
                                            font.pixelSize: 28
                                            color: Theme.surface2
                                        }
                                    }
                                }

                                // Overlay inferior: resolución
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 26
                                    color: Qt.rgba(0, 0, 0, 0.55)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        Text {
                                            Layout.fillWidth: true
                                            text: bingCell.model.width + "x" + bingCell.model.height
                                            font.pixelSize: 10
                                            color: Theme.muted2
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 16
                                            radius: 8
                                            color: bingCell.model.res === "4K" ? Theme.accent : Theme.surface3
                                            Text {
                                                anchors.centerIn: parent
                                                text: bingCell.model.res
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                color: bingCell.model.res === "4K" ? Theme.cardBg3 : Theme.muted2
                                            }
                                        }
                                    }
                                }

                                // Overlay de descarga/aplicación en progreso
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    visible: bingCell.model.id === root._busyId

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "󰔟"
                                            font.pixelSize: 22
                                            color: Theme.accent2
                                            RotationAnimation on rotation {
                                                running: bingCell.model.id === root._busyId
                                                from: 0; to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                            }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: root._searchStatus
                                            font.pixelSize: 10
                                            color: Theme.muted2
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: bingCellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.download(bingCell.model)
                            }
                        }
                    }

                    // Indicador de paginación: se muestra mientras se carga la
                    // página siguiente (sin tapar el grid, abajo al centro).
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        visible: root._loadingMore
                        width: moreLabel.implicitWidth + 22
                        height: 24
                        radius: 12
                        color: Qt.rgba(0, 0, 0, 0.65)
                        Text {
                            id: moreLabel
                            anchors.centerIn: parent
                            text: "Cargando más..."
                            font.pixelSize: 11
                            color: "white"
                        }
                    }
                }
            }
        }
    }
}

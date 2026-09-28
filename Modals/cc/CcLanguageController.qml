// Controlador de idioma — layout de teclado + locale + búsqueda con debounce
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../../Components"

QtObject {
    id: root

    property string _langLayout:        "—"
    property string _langLocale:        "—"
    property var    _langLayouts:       []   // [{label, code}]
    property var    _langLocales:       []
    property string _langSearch:        ""   // valor debounced (el que leen los filtros)
    property string _langSearchPending: ""   // valor inmediato del campo de texto
    property string _langTab:           "keyboard"

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

    // Debounce de búsqueda — aplica 150 ms después de la última tecla
    property var _debounceTimer: Timer {
        id: _langSearchDebounce
        interval: 150
        onTriggered: root._langSearch = root._langSearchPending
    }

    // Semilla del layout ACTIVO desde Hyprland (devices -j, teclado main).
    // getoption input:kb_layout devuelve la LISTA configurada ("us,latam"), no el activo —
    // con un solo layout coinciden y el bug queda enmascarado. Lazy: no corre al nacer —
    // ControlCenter.warmUp() lo dispara en la primera apertura del CC; rawEvent cubre
    // los cambios posteriores. Mismo origen que Widgets/LanguageWidget.qml.
    property var _langCurrentProc: Process {
        id: langCurrentProc
        running: false
        command: ["hyprctl", "devices", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    const obj = JSON.parse(data)
                    const keyboards = obj.keyboards ?? []
                    const main = keyboards.find(k => k.main) ?? keyboards[0]
                    if (main && main.layout) root._langLayout = String(main.layout).trim()
                } catch (e) {}
            }
        }
    }

    // Warm-up perezoso: siembra el layout inicial al abrir el CC
    function warmUp() {
        if (!langCurrentProc.running) langCurrentProc.running = true
    }

    // Cambios en runtime vía rawEvent. Formato documentado: "<device>,<layout>".
    // Se corta en la PRIMERA coma (igual que LanguageWidget): el nombre del device
    // nunca se interpreta como layout aunque contenga comas.
    property var _hyprlandLayoutConn: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const i = event.data.indexOf(",")
                if (i >= 0) {
                    const name = event.data.substring(i + 1).trim()
                    if (name) root._langLayout = name
                }
            }
        }
    }

    // Proceso: locale del sistema
    property var _langLocaleProc: Process {
        id: langLocaleProc
        command: ["sh", "-c",
            "localectl status 2>/dev/null | awk -F'LANG=' '/System Locale/{print $2}' | awk '{print $1}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: d => { var v = d.trim(); if (v) root._langLocale = v }
        }
    }

    // Proceso: layouts disponibles (XKB)
    property var _langLayoutProc: LineProcess {
        id: langLayoutProc
        command: ["sh", "-c", "timeout 3s localectl list-x11-keymap-layouts 2>/dev/null"]
        onLines: lines => {
            var layouts = []
            for (var i = 0; i < lines.length; i++) {
                var code = lines[i].trim()
                if (code.length === 0) continue
                layouts.push({ code: code, label: code })
            }
            if (layouts.length > 0) root._langLayouts = layouts
        }
    }

    // Proceso: aplicar layout vía Hyprland.
    // `hyprctl keyword input:kb_layout` está MUERTO en Hyprland ≥0.55 con parser Lua:
    // responde "keyword can't work with non-legacy parsers. Use eval." (verificado).
    // El reemplazo es `hyprctl eval 'hl.config({ input = { kb_layout = "<code>" } })'`,
    // que con lista de un elemento setea disponible + activo a la vez (verificado con
    // devices -j). La confirmación real llega vía rawEvent "activelayout" + reseed.
    // Cola pending: si llega un 2do click con el proceso aún corriendo, antes se
    // perdía por el guard if(!running); ahora se encola y se drena en onExited.
    property string _langPendingLayout: ""

    property var _langSetProc: Process {
        id: langSetProc
        command: ["hyprctl", "eval", ""]
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (root._langPendingLayout !== "") {
                const next = root._langPendingLayout
                root._langPendingLayout = ""
                root._applyLayout(next)
            } else if (!langCurrentProc.running) {
                langCurrentProc.running = true
            }
        }
        // qmllint enable signal-handler-parameters
    }

    // Proceso: locales disponibles
    property var _langLocaleListProc: LineProcess {
        id: langLocaleListProc
        command: ["sh", "-c", "timeout 3s localectl list-locales 2>/dev/null"]
        onLines: lines => {
            var locales = []
            for (var i = 0; i < lines.length; i++) {
                var value = lines[i].trim()
                if (value.length === 0) continue
                locales.push({ value: value, label: value })
            }
            if (locales.length > 0) root._langLocales = locales
        }
    }

    // Proceso: aplicar locale via localectl
    property var _langSetLocaleProc: Process {
        id: langSetLocaleProc
        command: ["sh", "-c", ""]
        // qmllint disable signal-handler-parameters
        onExited: langLocaleProc.running = true
        // qmllint enable signal-handler-parameters
    }

    function langRefresh() {
        root._langSearchPending = ""
        root._langSearch        = ""
        _langSearchDebounce.stop()
        root._langTab           = "keyboard"
        langLayoutProc.running     = true
        langLocaleProc.running     = true
        langLocaleListProc.running = true
        // langCurrentProc: one-shot se siembra via warmUp() al abrir el CC;
        // rawEvent cubre los cambios futuros.
    }

    function _applyLayout(code) {
        // Códigos de `localectl list-x11-keymap-layouts`: [a-z0-9_+-]. El saneo evita
        // inyección Lua al interpolar en el string de eval (Process array no usa shell,
        // pero el string SÍ lo interpreta Lua dentro del compositor).
        const safe = String(code).replace(/[^A-Za-z0-9_+-]/g, "")
        if (!safe) return
        langSetProc.command = ["hyprctl", "eval",
            "hl.config({ input = { kb_layout = \"" + safe + "\" } })"]
        langSetProc.running = true
    }

    function setLayout(code) {
        root._langLayout = code
        if (langSetProc.running) {
            root._langPendingLayout = code
            return
        }
        _applyLayout(code)
    }

    function setLocale(value) {
        langSetLocaleProc.command = ["sh", "-c",
            "localectl set-locale LANG=" + value + " 2>/dev/null"]
        if (!langSetLocaleProc.running) langSetLocaleProc.running = true
        root._langLocale = value
    }

    function startSearch(q) {
        root._langSearchPending = q
        _langSearchDebounce.restart()
    }

    function stopSearch() {
        root._langSearchPending = ""
        root._langSearch        = ""
        _langSearchDebounce.stop()
    }
}

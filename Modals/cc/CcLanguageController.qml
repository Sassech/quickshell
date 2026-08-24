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

    // One-shot: layout actual desde Hyprland Lazy: no corre al nacer — ControlCenter.warmUp() lo dispara en
    // la primera apertura del CC; rawEvent cubre los cambios posteriores.
    property var _langCurrentProc: Process {
        id: langCurrentProc
        running: false
        command: ["hyprctl", "getoption", "input:kb_layout"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const m = data.match(/str:\s*(\S+)/)
                if (m) root._langLayout = m[1].split(",")[0].trim()
            }
        }
    }

    // Warm-up perezoso: siembra el layout inicial al abrir el CC
    function warmUp() {
        if (!langCurrentProc.running) langCurrentProc.running = true
    }

    // Cambios en runtime vía rawEvent
    property var _hyprlandLayoutConn: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",")
                if (parts.length >= 2) root._langLayout = parts[parts.length - 1].trim()
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

    // Proceso: aplicar layout via Hyprland
    // El cambio se detecta vía rawEvent "activelayout" — no necesita re-run.
    property var _langSetProc: Process {
        id: langSetProc
        command: ["hyprctl", "keyword", "input:kb_layout", ""]
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

    function setLayout(code) {
        langSetProc.command = ["hyprctl", "keyword", "input:kb_layout", code]
        if (!langSetProc.running) langSetProc.running = true
        root._langLayout = code
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

pragma Singleton
import QtQuick
import QtQml
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────────
// OverlaysManager — hub central del subsistema de overlays.
//
// Enfoque data-driven: cada overlay es una entrada OverlayEntry en la lista
// `overlays`. El modal (OverlaysControl) renderiza una fila por entrada y el
// shell instancia los overlays desde el mismo modelo. Agregar un overlay = 1
// entrada nueva aquí; NO se toca OverlaysControl ni shell.qml.
//
// Estructura por secciones (para que el hub no crezca plano):
//   root.overlays  → estado/persistencia de cada overlay
//   root.config    → esqueleto de configuración general (futuro)
//   root.data      → esqueleto de datos/servicios (futuro)
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: root

    // ── Registro de overlays (data-driven) ────────────────────────────────
    property list<QtObject> overlays: [
        OverlayEntry {
            entryId: "watermark"
            name: "Watermark"
            description: "Aviso estilo «Activar Windows»"
            icon: "󰇮"
            source: "../Modals/overlays/Watermark.qml"
        },
        OverlayEntry {
            entryId: "preview"
            name: "Preview"
            description: "GIF animado decorativo"
            icon: "󰍉"
            source: "../Modals/overlays/PreviewOverlay.qml"
        }
    ]

    // ── Secciones del hub (esqueletos para lo que crezca después) ─────────
    property QtObject config: QtObject {}   // configuración general (futuro)
    property QtObject data:   QtObject {}   // datos/servicios (futuro)

    // ── Lookup por entryId (usado por los .qml de cada overlay) ───────────
    function get(id) {
        for (let i = 0; i < root.overlays.length; ++i) {
            if (root.overlays[i].entryId === id) return root.overlays[i]
        }
        return null
    }

    // ── Guard de carga ─────────────────────────────────────────────────────
    // Evita escribir durante la lectura inicial: solo se persiste cuando
    // _loaded == true (la carga falla silenciosamente → se mantienen defaults).
    property bool _loaded: false
    property string _loadBuf: ""

    // ── Persistencia (un solo archivo, formato genérico por entryId) ──────
    function save() {
        if (!root._loaded) return
        let state = { overlays: [] }
        for (let i = 0; i < root.overlays.length; ++i) {
            const e = root.overlays[i]
            state.overlays.push({ id: e.entryId, enabled: e.enabled, onTop: e.onTop })
        }
        saveProc.command = ["bash", "-c",
            "echo '" + JSON.stringify(state) + "' > \"" + Paths.config + "/overlays-state.json\""]
        saveProc.running = true
    }

    // Auto-persistencia: al terminar de cargar, cada cambio de estado de
    // cualquier overlay dispara save(). (Conectado en onCompleted para evitar
    // dependencia circular QML entre el manager y OverlayEntry.)
    Component.onCompleted: {
        for (let i = 0; i < root.overlays.length; ++i) {
            const e = root.overlays[i]
            e.enabledChanged.connect(root.save)
            e.onTopChanged.connect(root.save)
        }
    }

    // Hijos como properties (QtObject no tiene default property — convención
    // establecida en SysData.qml / WeatherProvider.qml).
    property Process saveProc: Process {
        running: false
    }

    // ── Carga inicial ──────────────────────────────────────────────────────
    property Process loadProc: Process {
        running: true
        command: ["bash", "-c",
            "cat \"" + Paths.config + "/overlays-state.json\" 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root._loadBuf += data
                try {
                    const state = JSON.parse(root._loadBuf.trim())
                    if (Array.isArray(state.overlays)) {
                        for (let i = 0; i < state.overlays.length; ++i) {
                            const saved = state.overlays[i]
                            const e = root.get(saved.id)
                            if (e) {
                                if (typeof saved.enabled === "boolean") e.enabled = saved.enabled
                                if (typeof saved.onTop === "boolean")   e.onTop   = saved.onTop
                            }
                        }
                    }
                    root._loadBuf = ""
                } catch (e) {}
                root._loaded = true
            }
        }
        // Fallback: si el proceso termina sin onRead (archivo vacío/borrado),
        // igualmente habilitamos el guard para no bloquear la persistencia.
        onExited: root._loaded = true
    }
}

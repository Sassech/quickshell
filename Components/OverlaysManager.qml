pragma Singleton
import QtQuick
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────────
// OverlaysManager — estado centralizado y persistencia de los overlays
// flotantes (Watermark, futuro REC…). Singleton registrado en Components/qmldir.
// Cada overlay aporta una property booleana aquí + una fila en OverlaysControl;
// los cambios se persisten en config/overlays-state.json.
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: root

    // ── Estado de cada overlay ─────────────────────────────────────────────
    property bool watermarkEnabled: true    // Watermark "Activar Windows"
    property bool recEnabled:       false   // REC overlay (pendiente de implementar)

    // ── Guard de carga ─────────────────────────────────────────────────────
    // Evita escribir durante la lectura inicial: solo se persiste cuando
    // _loaded == true (la carga falla silenciosamente → se mantienen defaults).
    property bool _loaded: false
    property string _loadBuf: ""

    // ── Persistencia ───────────────────────────────────────────────────────
    // Escribe el estado completo al cambiar cualquier flag (single saveProc,
    // mismo patrón de escritura JSON que IdleInhibitor).
    function save() {
        if (!root._loaded) return
        saveProc.command = ["bash", "-c",
            "echo '" + JSON.stringify({ watermark: root.watermarkEnabled, rec: root.recEnabled }) + "' > \"" + Paths.config + "/overlays-state.json\""]
        saveProc.running = true
    }

    onWatermarkEnabledChanged: if (root._loaded) root.save()
    onRecEnabledChanged:       if (root._loaded) root.save()

    // Hijos como properties (QtObject no tiene default property — convención
    // establecida en SysData.qml / WeatherProvider.qml).
    property Process saveProc: Process {
        running: false
    }

    // ── Carga inicial ──────────────────────────────────────────────────────
    // cat + fallback de JSON por defecto (patrón notifications.json de shell.qml).
    property Process loadProc: Process {
        running: true
        command: ["bash", "-c",
            "cat \"" + Paths.config + "/overlays-state.json\" 2>/dev/null || echo '{\"watermark\": true, \"rec\": false}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root._loadBuf += data
                try {
                    const state = JSON.parse(root._loadBuf.trim())
                    if (typeof state.watermark === "boolean") root.watermarkEnabled = state.watermark
                    if (typeof state.rec === "boolean")       root.recEnabled       = state.rec
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

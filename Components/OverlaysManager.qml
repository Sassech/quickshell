pragma Singleton
import QtQuick
import QtQml
import Quickshell.Io

// OverlaysManager — hub data-driven del subsistema de overlays
// Agregar un overlay = 1 entrada en `overlays` + 1 bloque Variants en shell.qml; OverlaysControl no se toca.
QtObject {
    id: root

    // Registro de overlays (data-driven) — tipado como OverlayEntry para qmllint
    property list<OverlayEntry> overlays: [
        OverlayEntry {
            entryId: "watermark"
            name: "Watermark"
            description: "Aviso estilo «Activar Windows»"
            icon: "󰇮"
            source: "../Modals/overlays/Watermark.qml"
            bottomOffset: 0              // posición inicial (puede persistirse en overlays-state.json)
        },
        OverlayEntry {
            entryId: "preview"
            name: "Preview"
            description: "GIF animado decorativo"
            icon: "󰍉"
            source: "../Modals/overlays/PreviewOverlay.qml"
            bottomOffset: 70             // posición inicial (puede persistirse en overlays-state.json)
        },
        OverlayEntry {
            entryId: "musicPlayer"
            name: "Reproductor"
            description: "Mini reproductor de música (MPRIS)"
            icon: "󰝚"
            source: "../Modals/overlays/MusicPlayerOverlay.qml"
        },
        OverlayEntry {
            entryId: "energy"
            name: "Energy"
            description: "Batería y consumo en vivo"
            icon: ""
            source: "../Modals/overlays/EnergyOverlay.qml"
            bottomOffset: 140           // posición inicial (puede persistirse en overlays-state.json)
        },
        OverlayEntry {
            entryId: "climate"
            name: "Climate"
            description: "Clima actual de un vistazo"
            icon: ""
            source: "../Modals/overlays/ClimateOverlay.qml"
            bottomOffset: 240           // posición inicial (puede persistirse en overlays-state.json)
        },
        OverlayEntry {
            entryId: "clock"
            name: "Clock"
            description: "Reloj"
            icon: "󰃭"
            source: "../Modals/overlays/ClockOverlay.qml"
            bottomOffset: 310
        },
        OverlayEntry {
            entryId: "sysstats"
            name: "System Stats"
            description: "CPU/RAM/GPU/Disco/Ventiladores"
            icon: ""
            source: "../Modals/overlays/SystemStatsOverlay.qml"
            bottomOffset: 380
        },

    ]

    // No se persiste: arranca apagado cada sesión y solo habilita el drag
    // de overlays dentro de OverlayWindow mientras está activo.
    property bool editPosition: false

    // Secciones del hub (esqueletos para lo que crezca después)
    property QtObject config: QtObject {}   // configuración general (futuro)
    property QtObject data:   QtObject {}   // datos/servicios (futuro)

    // Lookup por entryId (usado por los .qml de cada overlay) — retorna OverlayEntry tipado para qmllint
    function get(id: string): OverlayEntry {
        for (let i = 0; i < root.overlays.length; ++i) {
            if (root.overlays[i].entryId === id) return root.overlays[i]
        }
        return null
    }

    // Guard de carga Evita escribir durante la lectura inicial: solo se persiste cuando _loaded == true (la
    // carga falla silenciosamente → se mantienen defaults).
    property bool _loaded: false

    // Persistencia (un solo archivo, formato genérico por entryId) FileView reemplaza saveProc (bash echo → shell injection) y loadProc (bash
    // cat). setText() escribe sin shell; onLoaded/onLoadFailed cubren ambas ramas de la carga inicial.
    property FileView _stateFile: FileView {
        id: stateFile
        path: Paths.config + "/overlays-state.json"
        onLoaded: {
            try {
                const state = JSON.parse(text())
                if (Array.isArray(state.overlays)) {
                    for (let i = 0; i < state.overlays.length; ++i) {
                        const saved = state.overlays[i]
                        const e = root.get(saved.id)
                        if (e) {
                            if (typeof saved.enabled === "boolean") e.enabled = saved.enabled
                            if (typeof saved.onTop === "boolean")   e.onTop   = saved.onTop
                            if (typeof saved.topOffset === "number")     e.topOffset     = saved.topOffset
                            if (typeof saved.bottomOffset === "number")  e.bottomOffset  = saved.bottomOffset
                            if (typeof saved.leftOffset === "number")    e.leftOffset    = saved.leftOffset
                            if (typeof saved.rightOffset === "number")   e.rightOffset   = saved.rightOffset
                        }
                    }
                }
            } catch (e) {}
            root._loaded = true
        }
        onLoadFailed: root._loaded = true
    }

    function _buildState() {
        let state = { overlays: [] }
        for (let i = 0; i < root.overlays.length; ++i) {
            const e = root.overlays[i]
            state.overlays.push({ id: e.entryId, enabled: e.enabled, onTop: e.onTop,
                topOffset: e.topOffset, bottomOffset: e.bottomOffset,
                leftOffset: e.leftOffset, rightOffset: e.rightOffset })
        }
        return state
    }

    function save() {
        if (!root._loaded) return
        stateFile.setText(JSON.stringify(root._buildState()))
    }

    // Persistir bajo demanda (p. ej. al soltar un drag de posición). No se conecta offsetChanged a save()
    // para no escribir el archivo por píxel durante el arrastre.
    function persistNow() {
        root.save()
    }

    // Auto-persistencia: al terminar de cargar, cada cambio de estado de cualquier overlay dispara save(). (Conectado en onCompleted para evitar
    // dependencia circular QML entre el manager y OverlayEntry.) La carga inicial se dispara aquí también (stateFile.reload()).
    Component.onCompleted: {
        for (let i = 0; i < root.overlays.length; ++i) {
            const e = root.overlays[i]
            e.enabledChanged.connect(root.save)
            e.onTopChanged.connect(root.save)
        }
        stateFile.reload()
    }
}

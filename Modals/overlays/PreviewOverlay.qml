// qmllint disable uncreatable-type
import QtQuick
import "../../Components"

// ─────────────────────────────────────────────────────────────────────────────
// PreviewOverlay — overlay decorativo con GIF animado (preview.gif).
// Reutiliza OverlayWindow; el contenido aterriza en contentArea (default
// property). La visibilidad la gobierna su OverlayEntry en OverlaysManager.
// ─────────────────────────────────────────────────────────────────────────────
OverlayWindow {
    id: root

    // ── Configuración concreta ────────────────────────────────────────────
    corner:         "bottom-right"
    overlayWidth:   200
    bgColor:        "transparent"           // solo el GIF, sin tarjeta
    showAccent:     false
    restingOpacity: 0.95
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0                       // 0 = siempre visible (loop)
    onTop:          OverlaysManager.get("preview").onTop
    bottomOffset:   70

    visible: false
    Component.onCompleted: {
        if (OverlaysManager.get("preview").enabled) root.show()
    }

    Connections {
        target: OverlaysManager.get("preview")
        function onEnabledChanged() {
            if (OverlaysManager.get("preview").enabled) root.show()
            else root.hide()
        }
    }

    // ── Contenido (slot por defecto → contentArea) ─────────────────────────
    // sourceSize controla el tamaño de decodificación: 200px basta para el
    // render, evita decodificar el GIF completo en RAM. Asset 192x192 (1:1).
    AnimatedImage {
        width: root.overlayWidth
        height: root.overlayWidth            // ratio 1:1 del asset
        source: "assets/preview.gif"
        sourceSize: Qt.size(200, 200)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
}

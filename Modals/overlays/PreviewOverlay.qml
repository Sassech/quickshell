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
    entryId:        "preview"       // OverlayWindow auto-gobierna visibilidad vía OverlaysManager
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
    mouseThrough:   true    // decorativo: los clicks pasan a la ventana de abajo

    // ── Contenido (slot por defecto → contentArea) ─────────────────────────
    // sourceSize controla el tamaño de decodificación: 200px basta para el
    // render, evita decodificar el GIF completo en RAM. Asset 192x192 (1:1).
    AnimatedImage {
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 14
            topMargin: 14
        }
        width: root.overlayWidth
        height: root.overlayWidth            // ratio 1:1 del asset
        source: "assets/preview.gif"
        sourceSize: Qt.size(200, 200)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
}

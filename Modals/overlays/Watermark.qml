// qmllint disable uncreatable-type
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
// Watermark — overlay estilo "Activar Windows" anclado abajo a la derecha.
// Reutiliza OverlayWindow (mismo directorio, se resuelve por nombre) y declara
// su contenido como hijo; el slot por defecto lo coloca en contentArea.
// ─────────────────────────────────────────────────────────────────────────────
OverlayWindow {
    id: root

    // ── Configuración concreta ────────────────────────────────────────────
    entryId:        "watermark"     // OverlayWindow auto-gobierna visibilidad vía OverlaysManager
    corner:         "bottom-right"
    overlayWidth:   300
    bgColor:        "transparent"           // sin tarjeta: solo texto flotante
    showAccent:     false
    restingOpacity: 0.85
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0                       // 0 = siempre visible (estilo Windows)
    bottomOffset:   0                       // capa = la provee OverlayWindow vía _effectiveOnTop
    mouseThrough:   true    // decorativo: los clicks pasan a la ventana de abajo

    // ── Contenido (slot por defecto → contentArea) ─────────────────────────
    Row {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14
            rightMargin: 14
            topMargin: 14
        }
        spacing: 12

        // Ícono (Nerd Font — mismo glifo de acento que el resto del shell)
        Text {
            text: "󰇮"
            font.pixelSize: 26
            font.family: "monospace"
            color: "white"
            style: Text.Outline
            styleColor: "black"
            opacity: 0.8
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - 26 - 12
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "Activar Windows"
                width: parent.width
                elide: Text.ElideRight
                color: "white"
                style: Text.Outline
                styleColor: "black"
                opacity: 0.8
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                text: "Ve a Configuración para activar Windows."
                width: parent.width
                wrapMode: Text.WordWrap
                color: "white"
                style: Text.Outline
                styleColor: "black"
                opacity: 0.65
                font.pixelSize: 12
            }
        }
    }
}

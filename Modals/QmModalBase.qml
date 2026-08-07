// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"

// QmModalBase — plantilla para modales de pantalla completa.
// PanelWindow fullscreen + backdrop scrim + card centrada (o anclada) +
// consumo de clicks + cierre con Escape. El contenido va en el slot
// `default property alias content` (los hijos escriben sus items directo).
// Alturas: cardHeight > 0 → fija; fixedHeight → cardFixedHeight;
//          default → min(cardFixedHeight, screen.height * cardHeightFactor).
PanelWindow {
    id: root

    // ── Tamaño de la card ──────────────────────────────────────────────
    property int cardWidth: 580
    property real cardHeight: 0                       // >0 fuerza altura fija
    property bool fixedHeight: false
    property int cardFixedHeight: 520
    property real cardHeightFactor: 0.65
    property int cardRadius: 14
    property color cardColor: Theme.cardBg3
    property color cardBorderColor: Qt.rgba(1, 1, 1, 0.06)
    property int cardBorderWidth: 1
    property bool cardClip: false

    // ── Anclaje de la card ─────────────────────────────────────────────
    property string cardAnchor: "center"              // center | top | topRight | topCenter
    property int cardTopMargin: 36
    property int cardRightMargin: 12

    // ── Backdrop ───────────────────────────────────────────────────────
    property bool showScrim: true
    property real scrimOpacity: 1.0
    property color scrimColor: Theme.scrim
    property bool closeOnScrimClick: true

    // ── Comportamiento ─────────────────────────────────────────────────
    property bool consumeClicks: true
    property bool escapeEnabled: true
    property bool hasStripe: false
    property bool focusCard: false

    // ── Slot de contenido ──────────────────────────────────────────────
    default property alias content: contentArea.data

    // ── Raíz ───────────────────────────────────────────────────────────
    visible: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true

    // ── Backdrop scrim ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.showScrim
        color: root.scrimColor
        opacity: root.scrimOpacity
        MouseArea {
            anchors.fill: parent
            visible: root.closeOnScrimClick
            onClicked: root.close()
        }
    }

    // ── Card ───────────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: root.cardWidth
        height: root.cardHeight > 0 ? root.cardHeight
              : root.fixedHeight ? root.cardFixedHeight
              : Math.min(root.cardFixedHeight, root.height * root.cardHeightFactor)
        radius: root.cardRadius
        color: root.cardColor
        border.color: root.cardBorderColor
        border.width: root.cardBorderWidth
        clip: root.cardClip
        focus: root.focusCard
        Keys.onEscapePressed: {
            if (root.escapeEnabled) root.close()
        }

        anchors.centerIn: root.cardAnchor === "center" ? parent : undefined
        anchors.horizontalCenter: root.cardAnchor === "top" || root.cardAnchor === "topCenter" ? parent.horizontalCenter : undefined
        anchors.top: root.cardAnchor === "top" || root.cardAnchor === "topCenter" ? parent.top : undefined
        anchors.right: root.cardAnchor === "topRight" ? parent.right : undefined
        anchors.topMargin: root.cardAnchor !== "center" ? root.cardTopMargin : 0
        anchors.rightMargin: root.cardAnchor === "topRight" ? root.cardRightMargin : 0

        // ── Stripe superior ────────────────────────────────────────────
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.hasStripe
            height: 3
            radius: 3
            color: Theme.accent2
            Rectangle {
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: parent.width * 0.45
                color: Theme.accent
            }
        }

        // ── Consumo de clicks (debajo del contenido) ───────────────────
        MouseArea {
            anchors.fill: parent
            visible: root.consumeClicks
            onClicked: {}
        }

        // ── Contenido (encima del consume) ─────────────────────────────
        Item {
            id: contentArea
            anchors.fill: parent
        }
    }

    // ── API ────────────────────────────────────────────────────────────
    function open() {
        root.visible = true
        if (root.focusCard) card.forceActiveFocus()
    }
    function close() {
        root.visible = false
    }
}

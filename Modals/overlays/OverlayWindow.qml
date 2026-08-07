// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Components"

// ─────────────────────────────────────────────────────────────────────────────
// OverlayWindow — plantilla reutilizable para overlays flotantes (fade + slide).
// Un PanelWindow liviano anclado a una esquina, sin exclusión (nunca roba
// espacio), con máscara recortada a la tarjeta. El overlay concreto declara su
// contenido como hijos y aterriza automáticamente en contentArea vía el slot
// por defecto (default property).
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    visible: false
    color: "transparent"

    // ── Config properties (set from shell.qml) ────────────────────────────
    property string corner:         "bottom-right"
    property int    overlayWidth:   320
    property int    overlayHeight:  0
    property color  bgColor:        Theme.cardBg3
    property color  accent:         Theme.accent
    property bool   showAccent:     true        // franja lateral de acento
    property real   restingOpacity: 0.9
    property int    animInMs:       300
    property int    animOutMs:      300
    property int    autoHideMs:     0
    property bool   onTop:          true    // false → detrás de las ventanas (WlrLayer.Bottom)
    property int    topOffset:      0       // px extra en el margen del corner elegido
    property int    bottomOffset:   0
    property int    leftOffset:     0
    property int    rightOffset:    0
    property color  borderColor:    "transparent"  // borde de la tarjeta (transparent = sin borde)
    property bool   mouseThrough:   false   // true → los clicks pasan a la ventana de abajo (overlays decorativos)

    // ── Computed layout ───────────────────────────────────────────────────
    readonly property bool _barOnRight:     corner.endsWith("right")
    readonly property int  _contentMargin:  14
    readonly property int  _slideOffset:    overlayWidth + 16 + 24
    readonly property int  _slideStart:     _barOnRight ? _slideOffset : -_slideOffset

    // Slot por defecto: los hijos declarados dentro del overlay concreto
    // (p. ej. en Watermark.qml) se insertan directamente en contentArea.
    default property alias content: contentArea.data

    // Referencia a la tarjeta para que los hijos puedan anclar contenido
    // directo (p. ej. NotificationPopup usa toda la card, no el slot).
    property alias card: overlayCard

    implicitWidth:  overlayWidth
    implicitHeight: overlayHeight > 0 ? overlayHeight : overlayCard.implicitHeight

    WlrLayershell.layer:         root.onTop ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top:    corner === "top-right"    || corner === "top-left"
        bottom: corner === "bottom-right" || corner === "bottom-left"
        right:  corner === "top-right"    || corner === "bottom-right"
        left:   corner === "top-left"     || corner === "bottom-left"
    }
    // qmllint disable unqualified unresolved-type
    margins {
        top:    corner === "top-right"    || corner === "top-left"    ? 16 + root.topOffset    : 0
        bottom: corner === "bottom-right" || corner === "bottom-left" ? 16 + root.bottomOffset : 0
        right:  corner === "top-right"    || corner === "bottom-right" ? 16 + root.rightOffset  : 0
        left:   corner === "top-left"     || corner === "bottom-left"  ? 16 + root.leftOffset   : 0
    }
    // qmllint enable unqualified unresolved-type

    // Mascara de input: por defecto solo la tarjeta es clickeable; con
    // mouseThrough se anula para que los clics pasen a la ventana de abajo.
    // (No usar Region {} inline en un ternario: QML no instancia objetos
    // dentro de una expresión.) Usamos dos Region nombradas y elegimos una.
    Region { id: _mouseThroughRegion }
    Region { id: _cardRegion; item: overlayCard }
    mask: root.mouseThrough ? _mouseThroughRegion : _cardRegion

    // ── API pública ───────────────────────────────────────────────────────
    function show() {
        root._animateIn()
    }

    // Lógica real de entrada. Separada para que un hijo que sobreescriba
    // show() (con otros argumentos) pueda llamarla vía root._animateIn().
    function _animateIn() {
        hideOutAnim.stop()
        autoHideTimer.stop()

        overlayCard.x       = root._slideStart
        overlayCard.opacity = 0
        root.visible        = true
        showInAnim.start()

        if (root.autoHideMs > 0) autoHideTimer.restart()
    }

    function hide() {
        showInAnim.stop()
        autoHideTimer.stop()
        hideOutAnim.start()
    }

    // ── Auto-hide ─────────────────────────────────────────────────────────
    Timer {
        id: autoHideTimer
        interval: root.autoHideMs
        onTriggered: root.hide()
    }

    // ── Animaciones ───────────────────────────────────────────────────────
    ParallelAnimation {
        id: showInAnim
        NumberAnimation {
            target: overlayCard; property: "x"
            to: 0
            duration: root.animInMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: overlayCard; property: "opacity"
            to: root.restingOpacity
            duration: root.animInMs
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideOutAnim
        NumberAnimation {
            target: overlayCard; property: "x"
            to: root._slideStart
            duration: root.animOutMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: overlayCard; property: "opacity"
            to: 0
            duration: root.animOutMs
            easing.type: Easing.InCubic
        }
        onFinished: root.visible = false
    }

    // ── Tarjeta ───────────────────────────────────────────────────────────
    Rectangle {
        id: overlayCard
        width:  root.overlayWidth
        height: root.overlayHeight > 0 ? root.overlayHeight : implicitHeight
        radius: 12
        color:  root.bgColor
        border.color: root.borderColor
        border.width: 1
        clip:   true

        implicitHeight: contentArea.childrenRect.height + root._contentMargin * 2

        // Franja de acento del lado anclado
        Rectangle {
            visible: root.showAccent
            width: 3
            x:     root._barOnRight ? parent.width - 3 : 0
            radius: 1
            color: root.accent
            anchors {
                top: parent.top
                bottom: parent.bottom
                topMargin: 6
                bottomMargin: 6
            }
        }

        // Área de contenido: llena la tarjeta para que los overlays puedan
        // anclar directo (parent = la card completa, p. ej. NotificationPopup).
        // Los overlays simples posicionan su contenido con margins explícitos.
        Item {
            id: contentArea
            anchors.fill: parent
        }
    }
}

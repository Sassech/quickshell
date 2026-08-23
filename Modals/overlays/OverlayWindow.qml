// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Components"

// ─────────────────────────────────────────────────────────────────────────────
// OverlayWindow — template reutilizable para overlays flotantes (fade + slide).
// PanelWindow anclado a un corner, sin exclusión, con máscara recortada a la
// tarjeta. El overlay concreto declara su contenido como hijos (slot default).
//
// Opciones clave:
//   entryId      → id en OverlaysManager. Si se setea, el template centraliza
//                  visibilidad (arranque + toggle en vivo) y capa (onTop del
//                  entry); si queda vacío, el overlay maneja show()/hide().
//   mouseThrough → true = mascara de input vacia: los clicks pasan a la ventana
//                  de abajo (overlays decorativos como Watermark/Preview).
//   onTop        → capa para overlays NO manejados (entryId vacio): true =
//                  Overlay (sobre ventanas); false = Bottom (detras).
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
    property bool   showAccent:     true
    property real   restingOpacity: 0.9
    property int    animInMs:       300
    property int    animOutMs:      300
    property int    autoHideMs:     0
    property bool   autoHideSuppressed: false  // true → nunca autocierra (p. ej. notificación crítica)
    property bool   onTop:          true    // false → detrás de las ventanas (WlrLayer.Bottom)
    property int    topOffset:      0       // px extra en el margen del corner elegido
    property int    bottomOffset:   0
    property int    leftOffset:     0
    property int    rightOffset:    0
    property color  borderColor:    "transparent"
    property bool   mouseThrough:   false   // true → los clicks pasan a la ventana de abajo (overlays decorativos)
    property string entryId:        ""      // id en OverlayManager; si se setea, la visibilidad la gobierna el manager
    property bool   _dragged:       false   // true tras un arrastre real del modo edición

    // ── Auto-gobierno de visibilidad vía OverlaysManager ──────────────────
    readonly property QtObject _ownEntry:   OverlaysManager.get(root.entryId)
    readonly property bool _managed: root.entryId !== ""

    // Capa efectiva: manejados → sigue al entry (con guard contra entryId
    // inexistente); no manejados → la property onTop declarada.
    // (qmllint disable below: _ownEntry es QtObject genérico; el tipo real es
    // OverlayEntry y el guard de runtime ya valida onTop/enabled.)
    // qmllint disable missing-property
    readonly property bool _effectiveOnTop: root._managed && root._ownEntry
        ? root._ownEntry.onTop
        : root.onTop

    // ── Fix capa: el binding WlrLayershell.layer por sí solo no re-mapea la
    // surface en zwlr_layer_shell (el compositor fija la capa al mapear).
    // Se fuerza hide→show cuando _effectiveOnTop cambia estando visible.
    // Además se defiere el show inicial hasta OverlaysManager._loaded para
    // evitar el fogonazo Overlay→Bottom en el primer frame.
    function _restackForLayer() {
        if (!root.visible) return
        hideOutAnim.stop()
        showInAnim.stop()
        root.visible = false
        Qt.callLater(function() {
            // Re-mostrar solo si sigue debiendo estar visible (respeta enabled y _managed)
            if (root._managed) {
                if (root._ownEntry && root._ownEntry.enabled) root._animateIn()
            } else {
                // Overlay no manejado: respeta su estado visible previo (antes del restack estaba visible)
                root._animateIn()
            }
        })
    }

    Component.onCompleted: {
        if (!root._managed) return
        // Defer hasta que OverlaysManager haya volcado el JSON persistido
        if (!OverlaysManager._loaded) return
        if (root._ownEntry && root._ownEntry.enabled) root.show()
    }

    Connections {
        target: root._managed ? root._ownEntry : null
        function onEnabledChanged() {
            if (root._ownEntry && root._ownEntry.enabled) root.show()
            else root.hide()
        }
    }

    Connections {
        target: OverlaysManager
        function on_LoadedChanged() {
            if (!OverlaysManager._loaded) return
            if (!root._managed || !root._ownEntry) return
            if (root._ownEntry.enabled) {
                if (!root.visible) root.show()
                else root._restackForLayer()
            } else {
                if (root.visible) root.hide()
            }
        }
    }

    // Unico punto de reaplicado de capa: _effectiveOnTop ya observa
    // _ownEntry.onTop (manejados) y root.onTop (no manejados). Evita
    // duplicar onOnTopChanged que dispararia doble restack.
    on_EffectiveOnTopChanged: root._restackForLayer()
    // qmllint enable missing-property

    // ── Computed layout ───────────────────────────────────────────────────
    readonly property bool _barOnRight:     corner.endsWith("right")
    readonly property int  _contentMargin:  14
    readonly property int  _slideOffset:    overlayWidth + 16 + 24
    readonly property int  _slideStart:     _barOnRight ? _slideOffset : -_slideOffset

    // Offsets efectivos: manejados → los del OverlayEntry (persistidos);
    // no manejados → los declarados en el propio .qml.
    // (qmllint disable below: _ownEntry es QtObject genérico; el guard de
    // runtime _managed && _ownEntry ya valida el acceso.)
    // qmllint disable missing-property
    readonly property int _effTopOffset:    root._managed && root._ownEntry ? root._ownEntry.topOffset    : root.topOffset
    readonly property int _effBottomOffset: root._managed && root._ownEntry ? root._ownEntry.bottomOffset : root.bottomOffset
    readonly property int _effLeftOffset:   root._managed && root._ownEntry ? root._ownEntry.leftOffset   : root.leftOffset
    readonly property int _effRightOffset:  root._managed && root._ownEntry ? root._ownEntry.rightOffset  : root.rightOffset
    // qmllint enable missing-property

    // Flujo de tamaño implícito para la card (guía "Item Size and Position" de
    // quickshell): NO usar contentArea.childrenRect.height — la doc lo marca
    // como anti-patrón (binding loop oculto: childrenRect depende de la posición
    // de los hijos, que a su vez pueden depender del tamaño de la card). En su
    // lugar la card se dimensiona con el mayor implicitHeight de su contenido:
    // el hijo del slot declara su propio tamaño implícito y la card lo consume.
    // Los overlays con overlayHeight fijo ni llegan aquí (la card usa ese valor).
    // Iteramos `children` (no `data`): `data` acepta cualquier QObject (incluye
    // Timer/Connections no visuales, sin implicitHeight → Math.max devuelve NaN)
    // y además NO tiene señal NOTIFY en QQuickItem, por lo que un binding que la
    // lee genera el warning "depends on non-bindable properties: QQuickItem::data"
    // en cada reevaluación. `children` sólo trae Items visuales y sí es bindable
    // (childrenChanged), así el binding trackea altas/bajas correctamente.
    readonly property int _contentImplicitHeight: {
        let h = 0
        for (const child of contentArea.children) h = Math.max(h, child.implicitHeight)
        return h
    }

    // Slot por defecto: los hijos declarados dentro del overlay concreto
    // (p. ej. en Watermark.qml) se insertan directamente en contentArea.
    default property alias content: contentArea.data

    // Referencia a la tarjeta para que los hijos puedan anclar contenido
    // directo (p. ej. NotificationPopup usa toda la card, no el slot).
    property alias card: overlayCard

    implicitWidth:  overlayWidth
    implicitHeight: overlayHeight > 0 ? overlayHeight : overlayCard.implicitHeight

    WlrLayershell.layer:         root._effectiveOnTop ? WlrLayer.Overlay : WlrLayer.Bottom
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
        top:    corner === "top-right"    || corner === "top-left"    ? 16 + root._effTopOffset    : 0
        bottom: corner === "bottom-right" || corner === "bottom-left" ? 16 + root._effBottomOffset : 0
        right:  corner === "top-right"    || corner === "bottom-right" ? 16 + root._effRightOffset  : 0
        left:   corner === "top-left"     || corner === "bottom-left"  ? 16 + root._effLeftOffset   : 0
    }
    // qmllint enable unqualified unresolved-type

    // Mascara de input: por defecto solo la tarjeta es clickeable; con
    // mouseThrough se anula para que los clics pasen a la ventana de abajo.
    // En modo edición la tarjeta captura input aunque el overlay sea
    // decorativo (mouseThrough: true) para poder arrastrarlo.
    // (No usar Region {} inline en un ternario: QML no instancia objetos
    // dentro de una expresión.) Usamos dos Region nombradas y elegimos una.
    Region { id: _mouseThroughRegion }
    Region { id: _cardRegion; item: overlayCard }
    mask: (OverlaysManager.editPosition || !root.mouseThrough) ? _cardRegion : _mouseThroughRegion

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

        if (root.autoHideMs > 0 && !root.autoHideSuppressed) autoHideTimer.restart()
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
        onFinished: {
            root.visible = false
        }
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

        implicitHeight: root._contentImplicitHeight + root._contentMargin * 2

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

        // ── Indicador de modo edición ───────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            visible: OverlaysManager.editPosition
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(0.30, 0.80, 1.0, 0.8)
            border.width: 2
        }

        // ── Drag de posición (modo edición) ────────────────────────────────
        // DragHandler (no MouseArea): mantiene el grab del puntero aunque el
        // cursor salga de la tarjeta. Con MouseArea, como el compositor
        // reposiciona la capa con ~1 frame de latencia, el cursor supera a la
        // tarjeta, sale de ella y pierde los eventos → el arrastre se percibía
        // "lento"/atascado. Con el grab global el drag sigue al cursor de forma
        // continua. target: null porque NO queremos que mueva la tarjeta: la
        // posición la gobiernan los offsets del entry (margins de la ventana).
        // Solo los overlays gestionados (entryId) son arrastrables: los no
        // manejados caen al guard _managed.
        DragHandler {
            id: positionDrag
            target: null
            enabled: OverlaysManager.editPosition
            cursorShape: Qt.SizeAllCursor
            acceptedButtons: Qt.LeftButton
            // Tomar y retener el grab del puntero durante el arrastre:
            // permite robar el grab a otros handlers de tipo distinto y evita
            // perder los eventos al salir del área de la tarjeta.
            grabPermissions: DragHandler.CanTakeOverFromHandlersOfDifferentType
                           | DragHandler.ApprovesTakeOverByAnything
            property real pressX: 0
            property real pressY: 0
            property bool _dragged: false
            property int pressTop: 0
            property int pressBottom: 0
            property int pressLeft: 0
            property int pressRight: 0
            onActiveChanged: {
                if (positionDrag.active) {
                    if (!root._managed || !root._ownEntry) return
                    // Referencia RELATIVA al punto de presión (centroid.position
                    // es relativo a la tarjeta). Qt entrega cada evento contra
                    // la posición ACTUAL de la ventana, así que el delta contra
                    // el press ES el delta global real — autocorrige sin
                    // duplicar.
                    pressX = centroid.position.x; pressY = centroid.position.y
                    root._dragged = false
                    // (qmllint disable below: _ownEntry es QtObject genérico;
                    // el guard de runtime _managed && _ownEntry ya valida.)
                    // qmllint disable missing-property
                    const e = root._ownEntry
                    pressTop = e.topOffset; pressBottom = e.bottomOffset
                    pressLeft = e.leftOffset; pressRight = e.rightOffset
                    // qmllint enable missing-property
                } else if (root._dragged) {
                    // Persistir solo si hubo arrastre real. El modo edición NO
                    // se apaga solo: se activa/desactiva desde el botón
                    // "Mover overlays" en OverlaysControl (plan inicial).
                    OverlaysManager.persistNow()
                }
            }
            onCentroidChanged: {
                if (!positionDrag.active || !root._managed || !root._ownEntry) return
                const dx = centroid.position.x - pressX
                const dy = centroid.position.y - pressY
                if (dx !== 0 || dy !== 0) root._dragged = true
                // qmllint disable missing-property
                const e = root._ownEntry
                // Delta contra el offset INICIAL: si se aplicara contra el
                // actual, el movimiento se contaría dos veces cuando el
                // compositor reposiciona con latencia (overshoot, "se vuelve
                // loco"). Contra el press, cada evento corrige al cursor real.
                if (root.corner.endsWith("right"))  e.rightOffset = pressRight - dx
                else                                e.leftOffset  = pressLeft  + dx
                // OJO: corner "bottom-right" endsWith("right") pero NO
                // endsWith("bottom") — para el eje vertical hay que mirar el
                // INICIO del corner (startsWith), no el final.
                if (root.corner.startsWith("bottom")) e.bottomOffset = pressBottom - dy
                else                                  e.topOffset    = pressTop    + dy
                // qmllint enable missing-property
            }
        }
    }
}

// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Components"

// OverlayWindow — template flotante fade+slide (PanelWindow corner, mask a card, slot default). entryId→visibilidad+capa vía OverlaysManager
// (vacío=manual show/hide); mouseThrough→mask vacía (Watermark/Preview); onTop→Overlay/Bottom solo si no manejado.
PanelWindow {
    id: root

    visible: false
    color: "transparent"

    // Config properties (set from shell.qml)
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

    // Auto-gobierno de visibilidad vía OverlaysManager
    readonly property QtObject _ownEntry:   OverlaysManager.get(root.entryId)
    readonly property bool _managed: root.entryId !== ""

    // Capa efectiva: manejados→entry.onTop (guard entryId), no manejados→onTop. (qmllint disable: _ownEntry
    // QtObject genérico; guard valida onTop/enabled) qmllint disable missing-property
    readonly property bool _effectiveOnTop: root._managed && root._ownEntry
        ? root._ownEntry.onTop
        : root.onTop

    // Fix capa: WlrLayershell.layer no re-mapea solo → hide→show en _effectiveOnTop;
    // show inicial diferido a OverlaysManager._loaded (evita flash Overlay→Bottom).
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

    // Único restack: _effectiveOnTop observa ambos; evita doble onOnTopChanged.
    on_EffectiveOnTopChanged: root._restackForLayer()
    // qmllint enable missing-property

    // Computed layout
    readonly property bool _barOnRight:     corner.endsWith("right")
    readonly property int  _contentMargin:  14
    readonly property int  _slideOffset:    overlayWidth + 16 + 24
    readonly property int  _slideStart:     _barOnRight ? _slideOffset : -_slideOffset

    // Offsets: manejados→OverlayEntry, no manejados→qml. (qmllint disable: QtObject; guard _managed validado)
    // qmllint disable missing-property
    readonly property int _effTopOffset:    root._managed && root._ownEntry ? root._ownEntry.topOffset    : root.topOffset
    readonly property int _effBottomOffset: root._managed && root._ownEntry ? root._ownEntry.bottomOffset : root.bottomOffset
    readonly property int _effLeftOffset:   root._managed && root._ownEntry ? root._ownEntry.leftOffset   : root.leftOffset
    readonly property int _effRightOffset:  root._managed && root._ownEntry ? root._ownEntry.rightOffset  : root.rightOffset
    // qmllint enable missing-property

    // Sizing card: no childrenRect (anti-patrón binding loop); max implicitHeight del slot. `data` incluye non-visuals (NaN) y no es bindable
    // (warning QQuickItem::data); `children` solo visuals y bindable (childrenChanged).
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

    // Input mask: solo card clickeable; mouseThrough la anula. Edición captura siempre.
    // No Region{} inline en ternario (no instancia); dos Regions nombradas.
    Region { id: _mouseThroughRegion }
    Region { id: _cardRegion; item: overlayCard }
    mask: (OverlaysManager.editPosition || !root.mouseThrough) ? _cardRegion : _mouseThroughRegion

    function show() {
        root._animateIn()
    }

    // Entrada real: separada para hijos que sobreescriben show() → root._animateIn().
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

    // Auto-hide
    Timer {
        id: autoHideTimer
        interval: root.autoHideMs
        onTriggered: root.hide()
    }

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

    // Tarjeta
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

        // Franja acento lado anclado
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

        // contentArea llena card: overlays anclan a parent completo; simples usan margins.
        Item {
            id: contentArea
            anchors.fill: parent
        }

        // Indicador de modo edición
        Rectangle {
            anchors.fill: parent
            visible: OverlaysManager.editPosition
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(0.30, 0.80, 1.0, 0.8)
            border.width: 2
        }

        // Drag edición: DragHandler mantiene grab con latencia 1 frame (MouseArea lo pierde); target:null mueve offsets, no card. Solo gestionados.
        DragHandler {
            id: positionDrag
            target: null
            enabled: OverlaysManager.editPosition
            cursorShape: Qt.SizeAllCursor
            acceptedButtons: Qt.LeftButton
            // Grab persistente: roba a handlers distintos, evita pérdida al salir de card.
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
                    // centroid relativo a card; delta vs press = delta global (autocorrige latencia, no duplica).
                    pressX = centroid.position.x; pressY = centroid.position.y
                    root._dragged = false
                    // (qmllint disable below: _ownEntry es QtObject genérico; el guard de runtime _managed &&
                    // _ownEntry ya valida.) qmllint disable missing-property
                    const e = root._ownEntry
                    pressTop = e.topOffset; pressBottom = e.bottomOffset
                    pressLeft = e.leftOffset; pressRight = e.rightOffset
                    // qmllint enable missing-property
                } else if (root._dragged) {
                    // Persistir solo si hubo drag real; edición se apaga en OverlaysControl.
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
                // Delta vs offset INICIAL (no actual → evita doble conteo por latencia compositor).
                if (root.corner.endsWith("right"))  e.rightOffset = pressRight - dx
                else                                e.leftOffset  = pressLeft  + dx
                // OJO: vertical usa startsWith("bottom"), no endsWith (bottom-right).
                if (root.corner.startsWith("bottom")) e.bottomOffset = pressBottom - dy
                else                                  e.topOffset    = pressTop    + dy
                // qmllint enable missing-property
            }
        }
    }
}

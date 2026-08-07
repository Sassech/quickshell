// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Components"

// ─────────────────────────────────────────────────────────────────────────────
// OsdBase — plantilla base para OSD transitorios (volumen, brillo).
//
// Encapsula el ciclo de vida completo de un OSD: PanelWindow flotante
// bottom-center, slide-in desde abajo, auto-dismiss con fade-out, tarjeta con
// borde de acento. El OSD concreto hereda, bindea su contenido a las
// properties parametrizadas (value/icon/label/colores) y define su `show()`,
// que termina llamando `showCard()` de la base (QML no tiene super).
//
// Contenido común: fila [icono | barra de progreso | label]. La barra escala
// sobre `max` (el volumen usa 150 para admitir boost >100%); el marcador de
// 100% se muestra solo si `showHundredTick` es true.
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Anchored bottom-center, width/height just fits the card
    anchors.bottom: true
    implicitWidth:  root.cardWidth + 4
    implicitHeight: root.cardHeight + 8
    // qmllint disable unqualified unresolved-type
    margins.bottom: 48
    // qmllint enable unqualified unresolved-type

    mask: Region { item: osdCard }

    // ── Comportamiento (overridable) ──────────────────────────────────────
    property int cardWidth:  280
    property int cardHeight: 52
    property int dismissMs:  2500
    property int animInMs:   200
    property int animOutMs:  200
    property int slideStart: 60

    // ── Contenido (bindea el OSD concreto) ────────────────────────────────
    property int    value:          0
    property int    max:            100
    property string icon:           ""
    property int    iconSize:       18
    property color  iconColor:      Theme.accent
    property string label:          ""
    property color  labelColor:     Theme.text
    property color  barColor:       Theme.accent
    property int    labelWidth:     38
    property bool   showHundredTick: false

    // ── API (rutina base; el OSD concreto define su show() y termina aquí) ──
    function showCard() {
        if (!root.visible) {
            root.visible    = true
            osdCard.opacity = 1
            osdCard.yOffset = root.slideStart
            slideAnim.restart()
        }
        dismissTimer.restart()
    }

    // ── Timers & Animations ────────────────────────────────────────────────
    Timer {
        id: dismissTimer
        interval: root.dismissMs
        onTriggered: dismissFade.restart()
    }

    NumberAnimation {
        id: slideAnim
        target: osdCard; property: "yOffset"
        from: root.slideStart; to: 0
        duration: root.animInMs; easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: dismissFade
        target: osdCard; property: "opacity"
        from: 1; to: 0
        duration: root.animOutMs; easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── OSD Card ────────────────────────────────────────────────────────────
    Rectangle {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: yOffset
        width: root.cardWidth; height: root.cardHeight; radius: 13
        color: Theme.cardBg3

        property real yOffset: 0

        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12

            // Icono (bindea el OSD concreto según sus umbrales)
            Text {
                text: root.icon
                font.pixelSize: root.iconSize
                color: root.iconColor
            }

            // Barra de progreso
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 6

                Rectangle {
                    id: track
                    anchors.fill: parent; radius: 3
                    color: Theme.surface3
                }

                Rectangle {
                    width: (Math.min(root.max, Math.max(0, root.value)) / root.max) * track.width
                    height: track.height; radius: track.radius
                    color: root.barColor
                    Behavior on width  { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on color  { ColorAnimation  { duration: 120 } }
                }

                // Marcador de 100% (solo cuando el rango supera 100, p. ej. volumen)
                Rectangle {
                    visible: root.showHundredTick
                    x: (100 / root.max) * track.width - 1
                    height: 10; width: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                    radius: 1
                }
            }

            // Label
            Text {
                text: root.label
                font.pixelSize: 13; font.weight: Font.Normal
                color: root.labelColor
                Layout.preferredWidth: root.labelWidth
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}

// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Components"

// ── ScreenshotModal — selector de captura de pantalla ────────────────────────
// Posición: top-center   Atajo: SUPER+SHIFT+S
// Opciones: pantalla completa | ventana activa | área seleccionada
PanelWindow {
    id: root

    visible: false
    color:   "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    implicitHeight: screen.height

    // ── Propiedades públicas ──────────────────────────────────────────────
    property string _scriptsPath: Paths.scripts

    // ── Estado interno ────────────────────────────────────────────────────
    property bool _running: false

    // ── Abrir / cerrar ────────────────────────────────────────────────────
    function open() {
        // Limpia cualquier estado previo: si veníamos de un fade-out a medias,
        // matamos animación y timer de seguridad para no pelear por opacity
        fadeOut.stop()
        fadeIn.stop()
        closeSafetyTimer.stop()
        root.visible = true
        root._running = false
        fadeIn.start()
        slideIn.start()
        card.forceActiveFocus()
    }

    function close() {
        fadeIn.stop()
        fadeOut.start()
        closeSafetyTimer.restart()
    }

    // Safety net: garantiza que la ventana SIEMPRE se desmapea aunque el
    // fadeOut se interrumpa o no complete (p. ej. si open() llega a la mitad)
    Timer {
        id: closeSafetyTimer
        interval: 250
        onTriggered: {
            fadeOut.stop()
            root.visible = false
        }
    }

    // ── Proceso de captura ────────────────────────────────────────────────
    Process {
        id: captureProc
        running: false
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            root._running = false
            safetyTimer.stop()
        }
        // qmllint enable signal-handler-parameters
    }

    // Safety net: si grimblast cuelga o falla sin emitir onExited, desbloquea el modal
    Timer {
        id: safetyTimer
        interval: 8000
        onTriggered: root._running = false
    }

    function _capture(mode) {
        // Si el proceso anterior colgó, lo matamos antes de continuar
        if (root._running) {
            captureProc.running = false
            root._running = false
        }
        root._running = true
        root.close()
        delayTimer.mode = mode
        delayTimer.start()
    }

    Timer {
        id: delayTimer
        // Delay generoso: fadeOut dura 100ms + margen para que Wayland desmonte el layer
        interval: 250
        property string mode: "region"
        onTriggered: {
            safetyTimer.restart()
            captureProc.command = ["bash", root._scriptsPath + "/screenshot.sh", mode]
            captureProc.running = true
        }
    }

    // ── Animaciones ───────────────────────────────────────────────────────
    NumberAnimation {
        id: fadeIn
        target: card
        property: "opacity"
        from: 0; to: 1
        duration: 120
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: card
        property: "opacity"
        from: 1; to: 0
        duration: 100
        easing.type: Easing.InCubic
        onFinished: {
            root.visible = false
        }
    }

    NumberAnimation {
        id: slideIn
        target: card
        property: "y"
        from: 20; to: 60
        duration: 140
        easing.type: Easing.OutCubic
    }

    // ── Backdrop — cierra al hacer clic fuera ────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // ── Card centrado ─────────────────────────────────────────────────────
    Rectangle {
        id: card

        // Centrado horizontal, top con margen
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36

        width:  320
        height: column.implicitHeight + 20
        radius: 14

        color:   Theme.surface2
        opacity: 0
        layer.enabled: true

        // Borde sutil
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
        }

        // Intercepta clicks para que no caigan al backdrop
        MouseArea {
            anchors.fill: parent
        }

        Keys.onEscapePressed: root.close()

        ColumnLayout {
            id: column
            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                margins: 10
            }
            spacing: 6

            // ── Encabezado ────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 36

                Text {
                    anchors.centerIn: parent
                    text: "󰹑  Screenshot"
                    color: Theme.muted1
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                }
            }

            // ── Separador ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(1, 1, 1, 0.06)
                Layout.bottomMargin: 2
            }

            // ── Opciones ──────────────────────────────────────────────────
            ScreenshotOption {
                Layout.fillWidth: true
                icon:  "󰍹"
                label: "Full screen"
                hint:  "Capture entire display"
                onActivated: root._capture("fullscreen")
            }

            ScreenshotOption {
                Layout.fillWidth: true
                icon:  "󱂬"
                label: "Active window"
                hint:  "Click a window to capture it"
                onActivated: root._capture("active")
            }

            ScreenshotOption {
                Layout.fillWidth: true
                icon:  "󰩬"
                label: "Region"
                hint:  "Draw a selection area"
                onActivated: root._capture("region")
            }

            Item { implicitHeight: 2 }
        }

        Component.onCompleted: {
            opacity = 0
        }
    }

    // ── Componente interno: botón de opción ───────────────────────────────
    component ScreenshotOption: Rectangle {
        id: optRoot

        signal activated()

        required property string icon
        required property string label
        required property string hint

        implicitHeight: 52
        radius: 10
        color: optArea.containsMouse ? Theme.hover : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        // Borde accent al hover
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: optArea.containsMouse
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                : "transparent"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin:  12
                rightMargin: 12
            }
            spacing: 12

            // Icono
            Rectangle {
                implicitWidth: 36; implicitHeight: 36
                radius: 9
                color: optArea.containsMouse
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    : Qt.rgba(1, 1, 1, 0.06)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: optRoot.icon
                    font.pixelSize: 18
                    color: optArea.containsMouse ? Theme.accent : Theme.muted2
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            // Etiquetas
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: optRoot.label
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Text {
                    text: optRoot.hint
                    color: Theme.muted2
                    font.pixelSize: 11
                }
            }

            // Flecha
            Text {
                text: "›"
                color: optArea.containsMouse ? Theme.accent : Theme.muted3
                font.pixelSize: 18
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: optArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: optRoot.activated()
        }
    }
}

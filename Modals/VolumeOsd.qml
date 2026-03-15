import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode:  ExclusionMode.Ignore

    // Anchored bottom-center, width just fits the card
    anchors.bottom: true
    implicitWidth:  296
    implicitHeight: 60
    margins.bottom: 48

    // Center horizontally on the screen
    // WlrLayershell.anchors: WlrAnchors.Top

    mask: Region { item: osdCard }

    // ── State ─────────────────────────────────────────────────────────────
    property int  volumePct: 0     // 0–150
    property bool muted:     false

    function show(pct, isMuted) {
        volumePct = Math.max(0, Math.min(150, pct))
        muted     = isMuted
        if (!root.visible) {
            root.visible    = true
            osdCard.opacity = 1
            osdCard.yOffset = 60
            slideAnim.restart()
        }
        dismissTimer.restart()
    }

    // ── Timers & Animations ────────────────────────────────────────────────
    Timer {
        id: dismissTimer
        interval: 2500
        onTriggered: dismissFade.restart()
    }

    NumberAnimation {
        id: slideAnim
        target: osdCard; property: "yOffset"
        from: 60; to: 0
        duration: 240; easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: dismissFade
        target: osdCard; property: "opacity"
        from: 1; to: 0
        duration: 220; easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── OSD Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: yOffset
        width: 292; height: 52; radius: 13
        color: Theme.base

        property real yOffset: 0

        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12

            // Volume icon
            Text {
                text: root.muted || root.volumePct === 0 ? "󰝟"
                    : root.volumePct < 33               ? "󰕿"
                    : root.volumePct < 67               ? "󰖀"
                    : "󰕾"
                font.pixelSize: 18
                color: root.muted ? Theme.muted2 : Theme.accent
            }

            // Progress bar + 100% marker
            Item {
                Layout.fillWidth: true; height: 6

                Rectangle {
                    id: track
                    anchors.fill: parent; radius: 3
                    color: Theme.surface3

                    // Filled part
                    Rectangle {
                        width: (Math.min(150, Math.max(0, root.volumePct)) / 150) * track.width
                        height: track.height; radius: track.radius
                        color: root.muted ? Theme.muted2 : Theme.accent
                        Behavior on width  { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 120 } }
                    }

                    // 100% marker tick
                    Rectangle {
                        x: (100 / 150) * track.width - 1
                        height: 10; width: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                        radius: 1
                    }
                }
            }

            // Label
            Text {
                text: root.muted ? "Mudo" : root.volumePct + "%"
                font.pixelSize: 13; font.weight: Font.Normal
                color: root.muted ? Theme.muted2 : Theme.text
                width: 46
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}

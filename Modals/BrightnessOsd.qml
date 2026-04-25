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
    implicitWidth:  276
    implicitHeight: 60
    margins.bottom: 48

    mask: Region { item: osdCard }

    // ── State ─────────────────────────────────────────────────────────────
    property int brightness: 0   // 0–100

    function show(pct) {
        brightness = Math.max(0, Math.min(100, pct))
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
        duration: 200; easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: dismissFade
        target: osdCard; property: "opacity"
        from: 1; to: 0
        duration: 200; easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── OSD Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: yOffset
        width: 272; height: 52; radius: 13
        color: Theme.base

        property real yOffset: 0

        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12

            // Brightness icon — changes at thresholds
            Text {
                text: root.brightness < 15 ? "󰃞"
                    : root.brightness < 50 ? "󰃝"
                    : root.brightness < 85 ? "󰃟"
                    : "󰃠"
                font.pixelSize: 18
                color: Theme.accent
            }

            // Progress bar
            Item {
                Layout.fillWidth: true; height: 6

                Rectangle {
                    id: track
                    anchors.fill: parent; radius: 3
                    color: Theme.surface3
                }

                Rectangle {
                    width: (root.brightness / 100) * track.width
                    height: track.height; radius: track.radius
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                }
            }

            // Percentage label
            Text {
                text: root.brightness + "%"
                font.pixelSize: 13; font.weight: Font.Normal
                color: Theme.text
                width: 38
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}

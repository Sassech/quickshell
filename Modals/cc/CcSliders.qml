pragma ComponentBehavior: Bound

import QtQuick
import "../../Components"

// ── Sliders: volumen master, micrófono, brillo ────────────────────────────────
Column {
    id: root
    spacing: 0

    // ── Required properties ───────────────────────────────────────────────
    required property real masterVolume
    required property bool masterMuted
    required property real micVolume
    required property bool micMuted
    required property int  brightness

    // ── Signals ───────────────────────────────────────────────────────────
    signal setMasterVolume(real v)
    signal toggleMasterMute()
    signal setMicVol(real v)
    signal toggleMicMute()
    signal setBrightness(int v)

    // ── Helper functions ──────────────────────────────────────────────────
    function volIcon(vol, muted) {
        if (muted || vol === 0) return "󰝟"
        if (vol < 0.33) return "󰕿"
        if (vol < 0.67) return "󰖀"
        return "󰕾"
    }
    function brightIcon(pct) {
        if (pct < 15) return "󰃞"
        if (pct < 50) return "󰃝"
        if (pct < 85) return "󰃟"
        return "󰃠"
    }

    // ── Slider volumen master ─────────────────────────────────────────────
    Item {
        width: parent.width; height: 36
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 8
            Rectangle {
                width: 28; height: 28; radius: 8
                color: muteHov.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent
                    text: root.volIcon(root.masterVolume, root.masterMuted)
                    font.pixelSize: 14
                    color: root.masterMuted ? Theme.muted2 : Theme.accent
                }
                MouseArea {
                    id: muteHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMasterMute()
                }
            }
        }

        Item {
            anchors {
                left: parent.left; leftMargin: 44
                right: parent.right; rightMargin: 44
                verticalCenter: parent.verticalCenter
            }
            height: 20
            Rectangle {
                id: volTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2; color: Theme.surface3
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(8, root.masterVolume * volTrack.width)
                height: 4; radius: 2
                color: root.masterMuted ? Theme.muted2 : Theme.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            Rectangle {
                id: volThumb
                x: Math.min(root.masterVolume * volTrack.width - 6, volTrack.width - 12)
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6; color: Theme.accent
                Behavior on x { NumberAnimation { duration: 80 } }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (mouse.buttons & Qt.LeftButton) {
                        var v = Math.max(0, Math.min(1.5, mouse.x / volTrack.width))
                        root.setMasterVolume(v)
                    }
                }
                onClicked: mouse => {
                    var v = Math.max(0, Math.min(1.5, mouse.x / volTrack.width))
                    root.setMasterVolume(v)
                }
            }
        }

        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.masterMuted ? "Muted" : Math.round(root.masterVolume * 100) + "%"
            font.pixelSize: 10; color: root.masterMuted ? Theme.muted2 : Theme.muted1
            width: 36; horizontalAlignment: Text.AlignRight
        }
    }

    // ── Slider micrófono ──────────────────────────────────────────────────
    Item {
        width: parent.width; height: 36
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 8
            Rectangle {
                width: 28; height: 28; radius: 8
                color: micHov.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent
                    text: root.micMuted ? "󰍭" : "󰍬"
                    font.pixelSize: 14
                    color: root.micMuted ? Theme.muted2 : Theme.accent
                }
                MouseArea {
                    id: micHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMicMute()
                }
            }
        }
        Item {
            anchors {
                left: parent.left; leftMargin: 44
                right: parent.right; rightMargin: 44
                verticalCenter: parent.verticalCenter
            }
            height: 20
            Rectangle {
                id: micTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2; color: Theme.surface3
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(8, root.micVolume * micTrack.width)
                height: 4; radius: 2
                color: root.micMuted ? Theme.muted2 : Theme.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            Rectangle {
                x: Math.min(root.micVolume * micTrack.width - 6, micTrack.width - 12)
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6; color: Theme.accent
                Behavior on x { NumberAnimation { duration: 80 } }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (mouse.buttons & Qt.LeftButton) {
                        var v = Math.max(0, Math.min(1.5, mouse.x / micTrack.width))
                        root.setMicVol(v)
                    }
                }
                onClicked: mouse => {
                    var v = Math.max(0, Math.min(1.5, mouse.x / micTrack.width))
                    root.setMicVol(v)
                }
            }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.micMuted ? "Muted" : Math.round(root.micVolume * 100) + "%"
            font.pixelSize: 10; color: root.micMuted ? Theme.muted2 : Theme.muted1
            width: 36; horizontalAlignment: Text.AlignRight
        }
    }

    // ── Slider brillo ─────────────────────────────────────────────────────
    Item {
        width: parent.width; height: 36
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 8
            Rectangle {
                width: 28; height: 28; radius: 8; color: Theme.surface2
                Text {
                    anchors.centerIn: parent
                    text: root.brightIcon(root.brightness)
                    font.pixelSize: 14; color: Theme.accent
                }
            }
        }
        Item {
            anchors {
                left: parent.left; leftMargin: 44
                right: parent.right; rightMargin: 44
                verticalCenter: parent.verticalCenter
            }
            height: 20
            Rectangle {
                id: briTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2; color: Theme.surface3
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(8, (root.brightness / 100) * briTrack.width)
                height: 4; radius: 2; color: Theme.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            Rectangle {
                x: Math.min((root.brightness / 100) * briTrack.width - 6, briTrack.width - 12)
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6; color: Theme.accent
                Behavior on x { NumberAnimation { duration: 80 } }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (mouse.buttons & Qt.LeftButton) {
                        var v = Math.max(1, Math.min(100, Math.round(mouse.x / briTrack.width * 100)))
                        root.setBrightness(v)
                    }
                }
                onClicked: mouse => {
                    var v = Math.max(1, Math.min(100, Math.round(mouse.x / briTrack.width * 100)))
                    root.setBrightness(v)
                }
            }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.brightness + "%"
            font.pixelSize: 10; color: Theme.muted1
            width: 36; horizontalAlignment: Text.AlignRight
        }
    }
}

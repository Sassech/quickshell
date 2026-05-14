import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true

    // ── Active player ──────────────────────────────────────────────────────
    property var player: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    // ── Position tracking ──────────────────────────────────────────────────
    property real trackedPosition: 0
    property int  _syncCounter: 0

    function syncPosition() {
        if (root.player && root.player.position !== undefined)
            root.trackedPosition = root.player.position
    }

    onVisibleChanged: {
        if (visible) {
            root.syncPosition()
            Qt.callLater(function() { card.forceActiveFocus() })
        }
    }

    Connections {
        target: root.player ?? null
        function onTrackTitleChanged() { root.syncPosition(); root._syncCounter = 0 }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.player?.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            root.trackedPosition += 1000
            root._syncCounter++
            if (root._syncCounter >= 10) {
                root._syncCounter = 0
                root.syncPosition()
            }
        }
    }

    // Helpers
    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── Backdrop ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    // ── Card ───────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        focus: true
        anchors.centerIn: parent
        width:  380
        height: 110
        radius: 16
        color:  Theme.cardBg3

        Keys.onEscapePressed: root.visible = false

        // Accent border
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            border.color: Theme.accentSurface
            border.width: 1
        }

        MouseArea { anchors.fill: parent }

        // ── No player state ────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.player === null

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰝚"
                    font.pixelSize: 28
                    color: Theme.muted2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No hay reproductor activo"
                    font.pixelSize: 12
                    color: Theme.muted1
                }
            }
        }

        // ── Player layout ──────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.player !== null

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 14
                    topMargin: 14
                    bottomMargin: 14
                }
                spacing: 14

                // ── Artwork ────────────────────────────────────────────────
                Rectangle {
                    width: 72; height: 72
                    radius: 10
                    color: Theme.surface2
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: artworkImg
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    // Fallback icon
                    Text {
                        anchors.centerIn: parent
                        visible: artworkImg.status !== Image.Ready
                        text: "󰝚"
                        font.pixelSize: 28
                        color: Theme.muted2
                    }
                }

                // ── Info + controls ────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Title + close
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Column {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                width: parent.width
                                text: root.player?.trackTitle ?? "Sin título"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.player?.trackArtist ?? root.player?.identity ?? ""
                                font.pixelSize: 11
                                color: Theme.muted1
                                elide: Text.ElideRight
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 22; height: 22; radius: 6
                            color: closeMA.containsMouse ? Theme.surface3 : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"; font.pixelSize: 11; color: Theme.muted2
                            }
                            MouseArea {
                                id: closeMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.visible = false
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // ── Progress bar ───────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // Seek bar
                        Item {
                            Layout.fillWidth: true
                            height: 4

                            property real progress: {
                                var p = root.player
                                if (!p || !p.trackLength || p.trackLength <= 0) return 0
                                return Math.max(0, Math.min(1, root.trackedPosition / p.trackLength))
                            }

                            // Track background
                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: Theme.surface3
                            }

                            // Fill
                            Rectangle {
                                width: parent.width * parent.progress
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }

                            // Seek on click
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    var p = root.player
                                    if (p && p.trackLength > 0) {
                                        var newPos = (mouse.x / width) * p.trackLength
                                        p.position = newPos
                                        root.trackedPosition = newPos
                                        root._syncCounter = 0
                                    }
                                }
                            }
                        }

                        // Timestamps
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.formatTime(root.trackedPosition)
                                font.pixelSize: 9
                                color: Theme.muted2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.player ? root.formatTime(root.player.trackLength) : "0:00"
                                font.pixelSize: 9
                                color: Theme.muted2
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // ── Controls ───────────────────────────────────────────
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        // Previous
                        Rectangle {
                            width: 30; height: 30; radius: 8
                            color: prevMA.containsMouse ? Theme.surface3 : Theme.surface2
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"; font.pixelSize: 14
                                color: root.player?.canGoPrevious ? Theme.text : Theme.muted2
                            }
                            MouseArea {
                                id: prevMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.player?.canGoPrevious) root.player.previous()
                            }
                        }

                        // Play / Pause
                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: playMA.containsMouse ? Theme.accentSurface : Theme.accent
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                                font.pixelSize: 15
                                color: Theme.base
                            }
                            MouseArea {
                                id: playMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.player?.togglePlaying()
                            }
                        }

                        // Next
                        Rectangle {
                            width: 30; height: 30; radius: 8
                            color: nextMA.containsMouse ? Theme.surface3 : Theme.surface2
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"; font.pixelSize: 14
                                color: root.player?.canGoNext ? Theme.text : Theme.muted2
                            }
                            MouseArea {
                                id: nextMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.player?.canGoNext) root.player.next()
                            }
                        }
                    }
                }
            }
        }


    }
}

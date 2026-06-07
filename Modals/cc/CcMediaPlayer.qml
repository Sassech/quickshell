pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../Components"

// ── Media player strip (MPRIS) ────────────────────────────────────────────────
Column {
    id: root

    // ── Required properties ───────────────────────────────────────────────
    required property var  mprisPlayer   // MprisPlayer | null
    required property real playerPos     // seconds

    // ── Content ───────────────────────────────────────────────────────────
    Item { width: parent.width; height: 10 }

    Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

    Item {
        width: parent.width
        height: innerPlayer.height + 16

        Rectangle {
            id: innerPlayer
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            height: 90; radius: 10; color: Theme.surface2

            // ── Helper: formatear segundos → m:ss ─────────────────────────
            function fmtSec(sec) {
                if (!sec || sec <= 0) return "0:00"
                const s = Math.floor(sec)
                const m = Math.floor(s / 60)
                return m + ":" + String(s % 60).padStart(2, "0")
            }

            RowLayout {
                anchors { fill: parent; margins: 10 }
                spacing: 10

                // ── Artwork ───────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8; color: Theme.surface3; clip: true
                    Image {
                        id: ccArtwork
                        anchors.fill: parent
                        source: root.mprisPlayer?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !ccArtwork.visible
                        text: "󰝚"; font.pixelSize: 22; color: Theme.muted2
                    }
                }

                // ── Info + barra + controles ──────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // Título + ícono de app
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                width: parent.width
                                text: root.mprisPlayer?.trackTitle ?? "Sin reproductor"
                                font.pixelSize: 12; font.weight: Font.DemiBold
                                color: Theme.text; elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.mprisPlayer?.trackArtist ?? ""
                                font.pixelSize: 10; color: Theme.muted1; elide: Text.ElideRight
                            }
                        }
                        Text {
                            text: "󰓇"; font.pixelSize: 14; color: Theme.muted2
                            visible: root.mprisPlayer !== null
                        }
                    }

                    // Barra de progreso (solo visual)
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        property real progress: {
                            const p = root.mprisPlayer
                            if (!p || !p.lengthSupported || p.length <= 0) return 0
                            return Math.max(0, Math.min(1, root.playerPos / p.length))
                        }
                        Rectangle { anchors.fill: parent; radius: 2; color: Theme.surface3 }
                        Rectangle {
                            width: parent.width * parent.progress
                            height: parent.height; radius: 2; color: Theme.accent
                        }
                    }

                    // Tiempo | controles | duración
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: innerPlayer.fmtSec(root.playerPos); font.pixelSize: 9; color: Theme.muted2 }
                        Item { Layout.fillWidth: true }
                        Row {
                            spacing: 2
                            Repeater {
                                model: [
                                    { icon: "󰒮", action: "prev" },
                                    { icon: root.mprisPlayer?.isPlaying ? "󰏤" : "󰐊", action: "play" },
                                    { icon: "󰒭", action: "next" }
                                ]
                                Rectangle {
                                    id: pCtrlBtn
                                    required property var modelData
                                    width: 24; height: 24; radius: 6
                                    color: pCtrlHov.containsMouse ? Theme.surface3 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: pCtrlBtn.modelData.icon; font.pixelSize: 13; color: Theme.text
                                    }
                                    MouseArea {
                                        id: pCtrlHov; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const p = root.mprisPlayer
                                            if (!p) return
                                            if      (pCtrlBtn.modelData.action === "prev") p.previous()
                                            else if (pCtrlBtn.modelData.action === "next") p.next()
                                            else p.togglePlaying()
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: innerPlayer.fmtSec(root.mprisPlayer?.length ?? 0); font.pixelSize: 9; color: Theme.muted2 }
                    }
                }
            }
        }
    }
}

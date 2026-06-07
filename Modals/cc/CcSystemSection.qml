pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../Components"

// ── Métricas del sistema: CPU/RAM/GPU arcos + disco ───────────────────────────
Column {
    id: root
    spacing: 0

    // ── Required properties ───────────────────────────────────────────────────
    required property string activePanel

    required property int diskPct
    required property int diskUsed
    required property int diskTotal
    required property int homePct
    required property int homeUsed
    required property int homeTotal

    // ── Signals ───────────────────────────────────────────────────────────────
    signal togglePanel(string key)

    // ── Leading spacer + separator + label ────────────────────────────────────
    Item { width: parent.width; height: 10 }
    Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
    Item { width: parent.width; height: 8 }

    Text {
        text: "System"
        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.muted1
    }
    Item { width: parent.width; height: 6 }

    // ── Grid CPU / RAM / GPU ──────────────────────────────────────────────────
    Row {
        id: metricsRow
        width: parent.width
        spacing: 6

        Repeater {
            model: [
                { key: "cpu", label: "CPU", icon: "󰻠",
                  value: SysData.cpuPercent, temp: SysData.cpuTemp },
                { key: "ram", label: "RAM", icon: "󰘚",
                  value: SysData.ramPercent, temp: -1 },
                { key: "gpu", label: "GPU", icon: "󰟵",
                  value: SysData.gpuPercent >= 0 ? SysData.gpuPercent : 0,
                  temp: SysData.gpuTemp }
            ]

            Rectangle {
                id: metCard
                required property var modelData
                required property int index
                property bool hov: false
                property bool expanded: root.activePanel === metCard.modelData.key

                width: (metricsRow.width - 12) / 3
                height: 70
                radius: 12
                color: expanded
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    : (hov ? Theme.surface3 : Theme.surface2)
                Behavior on color { ColorAnimation { duration: 100 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    // ── Arc gauge ─────────────────────────────────────────────
                    Item {
                        id: arcItem
                        width: 42; height: 42
                        anchors.horizontalCenter: parent.horizontalCenter

                        property real arcPct: metCard.modelData.value / 100
                        Behavior on arcPct { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        onArcPctChanged: arcCanvas.requestPaint()

                        Canvas {
                            id: arcCanvas
                            anchors.fill: parent

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cx = width / 2, cy = height / 2, r = 16

                                // Track
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI * 0.75, Math.PI * 0.75)
                                ctx.strokeStyle = Theme.surface3.toString()
                                ctx.lineWidth = 3.5
                                ctx.lineCap = "round"
                                ctx.stroke()

                                // Fill
                                if (arcItem.arcPct > 0) {
                                    var end = -Math.PI * 0.75 + Math.PI * 1.5 * Math.min(arcItem.arcPct, 1)
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, -Math.PI * 0.75, end)
                                    ctx.strokeStyle = arcItem.arcPct > 0.85 ? "#ff7b72"
                                                    : arcItem.arcPct > 0.65 ? "#e3b341"
                                                    : Theme.accent.toString()
                                    ctx.lineWidth = 3.5
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }
                            }

                            Component.onCompleted: requestPaint()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: metCard.modelData.icon
                            font.pixelSize: 14
                            color: arcItem.arcPct > 0.85 ? "#ff7b72"
                                 : arcItem.arcPct > 0.65 ? "#e3b341"
                                 : Theme.muted1
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: metCard.modelData.label + " " + Math.round(metCard.modelData.value) + "%"
                        font.pixelSize: 9; font.weight: Font.DemiBold
                        color: metCard.modelData.value > 85 ? "#ff7b72"
                             : metCard.modelData.value > 65 ? "#e3b341"
                             : Theme.text
                    }
                }

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: metCard.hov = true
                    onExited:  metCard.hov = false
                    onClicked: root.togglePanel(metCard.modelData.key)
                }
            }
        }
    }

    // ── Disco: Root + Home ────────────────────────────────────────────────────
    Item { width: parent.width; height: 8 }

    Grid {
        width: parent.width
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: [
                { label: "Root", icon: "󰋊",
                  pct: root.diskPct,  used: root.diskUsed,  total: root.diskTotal },
                { label: "Home", icon: "󰋞",
                  pct: root.homePct, used: root.homeUsed, total: root.homeTotal }
            ]

            Rectangle {
                id: diskCard
                required property var modelData
                width: (parent.width - 6) / 2; height: 52; radius: 10
                color: Theme.surface2

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 8

                    Text {
                        text: diskCard.modelData.icon; font.pixelSize: 18
                        color: diskCard.modelData.pct >= 90 ? "#ff7b72"
                             : diskCard.modelData.pct >= 75 ? "#e3b341"
                             : Theme.muted1
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Row {
                            spacing: 6
                            Text {
                                text: diskCard.modelData.label
                                font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                            }
                            Text {
                                text: diskCard.modelData.pct + "%"
                                font.pixelSize: 10
                                color: diskCard.modelData.pct >= 90 ? "#ff7b72"
                                     : diskCard.modelData.pct >= 75 ? "#e3b341"
                                     : Theme.muted1
                            }
                        }

                        // Barra de uso
                        Item {
                            width: parent.width; height: 4
                            Rectangle { anchors.fill: parent; radius: 2; color: Theme.surface3 }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(4, diskCard.modelData.pct / 100 * parent.width)
                                radius: 2
                                color: diskCard.modelData.pct >= 90 ? "#ff7b72"
                                     : diskCard.modelData.pct >= 75 ? "#e3b341"
                                     : Theme.accent
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }

                        Text {
                            text: diskCard.modelData.used + " / " + diskCard.modelData.total + " GB"
                            font.pixelSize: 9; color: Theme.muted2
                        }
                    }
                }
            }
        }
    }
}

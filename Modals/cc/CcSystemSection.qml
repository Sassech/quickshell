pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    required property bool diskAvailable
    required property double diskReadMbs
    required property double diskWriteMbs

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

                        // Track arc (background)
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: Theme.surface3
                                fillColor: "transparent"
                                strokeWidth: 3.5
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 21; centerY: 21
                                    radiusX: 16; radiusY: 16
                                    startAngle: -225
                                    sweepAngle: 270
                                }
                            }
                        }

                        // Fill arc (value)
                        Shape {
                            anchors.fill: parent
                            visible: arcItem.arcPct > 0
                            ShapePath {
                                strokeColor: arcItem.arcPct > 0.85 ? Theme.error
                                           : arcItem.arcPct > 0.65 ? Theme.warning
                                           : Theme.accent
                                fillColor: "transparent"
                                strokeWidth: 3.5
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 21; centerY: 21
                                    radiusX: 16; radiusY: 16
                                    startAngle: -225
                                    sweepAngle: 270 * Math.min(arcItem.arcPct, 1)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: metCard.modelData.icon
                            font.pixelSize: 14
                            color: arcItem.arcPct > 0.85 ? Theme.error
                                 : arcItem.arcPct > 0.65 ? Theme.warning
                                 : Theme.muted1
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: metCard.modelData.label + " " + Math.round(metCard.modelData.value) + "%"
                        font.pixelSize: 9; font.weight: Font.DemiBold
                        color: metCard.modelData.value > 85 ? Theme.error
                             : metCard.modelData.value > 65 ? Theme.warning
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

    // ── Disco (un solo fs en esta máquina) ───────────────────────────────
    Item { width: parent.width; height: 8 }

    Rectangle {
        id: diskCard
        width: parent.width; height: 76; radius: 10
        color: Theme.surface2

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8

            Text {
                text: "󰋊"; font.pixelSize: 18
                color: root.diskPct >= 90 ? Theme.error
                     : root.diskPct >= 75 ? Theme.warning
                     : Theme.text
            }

            Column {
                Layout.fillWidth: true
                spacing: 4

                Row {
                    spacing: 6
                    Text {
                        text: "Disco"
                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                    }
                    Text {
                        text: root.diskPct + "%"
                        font.pixelSize: 10
                        color: root.diskPct >= 90 ? Theme.error
                             : root.diskPct >= 75 ? Theme.warning
                             : Theme.text
                    }
                }

                // Barra de uso
                Item {
                    width: parent.width; height: 4
                    Rectangle { anchors.fill: parent; radius: 2; color: Theme.surface3 }
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: Math.max(4, root.diskPct / 100 * parent.width)
                        radius: 2
                        color: root.diskPct >= 90 ? Theme.error
                             : root.diskPct >= 75 ? Theme.warning
                             : Theme.accent
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                Text {
                    text: root.diskUsed + " / " + root.diskTotal + " GB"
                    font.pixelSize: 9; color: Theme.text
                }

                Row {
                    spacing: 8

                    Text {
                        text: "↓"
                        font.pixelSize: 9; font.weight: Font.Bold
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.diskAvailable && !isNaN(root.diskReadMbs)
                            ? root.diskReadMbs.toFixed(1) + " MB/s" : "—"
                        font.pixelSize: 9; font.family: "monospace"
                        color: Theme.text
                        width: 52
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "↑"
                        font.pixelSize: 9; font.weight: Font.Bold
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.diskAvailable && !isNaN(root.diskWriteMbs)
                            ? root.diskWriteMbs.toFixed(1) + " MB/s" : "—"
                        font.pixelSize: 9; font.family: "monospace"
                        color: Theme.text
                        width: 52
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}

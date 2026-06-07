import QtQuick
import "../../Components"

// ── CcGpuPanel ───────────────────────────────────────────────────────────────
// Panel de detalle de GPU: uso %, temperatura, barra de VRAM usada/total.
Rectangle {
    id: root
    implicitWidth: 300
    implicitHeight: gpuDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.2); border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property bool   gpuAvailable
    required property int    gpuPercent
    required property int    gpuTemp
    required property string gpuName
    required property int    gpuVramUsedMb
    required property int    gpuVramTotalMb

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Helpers ───────────────────────────────────────────────────────────
    property color _accentColor: {
        if (!root.gpuAvailable) return Theme.muted2
        if (root.gpuTemp >= 85)  return Theme.error
        if (root.gpuTemp >= 70)  return Theme.warning
        return Theme.accent2
    }

    property real _vramPct: root.gpuVramTotalMb > 0
        ? root.gpuVramUsedMb / root.gpuVramTotalMb
        : 0

    property color _vramColor: {
        if (_vramPct >= 0.9) return Theme.error
        if (_vramPct >= 0.7) return Theme.warning
        if (_vramPct >= 0.5) return Theme.yellow
        return Theme.accent2
    }

    Column {
        id: gpuDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 6

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: root.gpuName.length > 0 ? root.gpuName : "GPU"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
                elide: Text.ElideRight
                width: parent.width - 36
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: gpuCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: gpuCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── Uso % ─────────────────────────────────────────────────────────
        Text {
            text: "Shader use"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
        }

        Item {
            width: parent.width; height: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(4, root.gpuPercent / 100 * parent.width)
                radius: 3; color: root._accentColor
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        Row {
            spacing: 16
            Text {
                text: root.gpuPercent + "%"
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                visible: root.gpuTemp > 0
                text: root.gpuTemp + " °C"
                font.pixelSize: 11; color: root._accentColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── VRAM ──────────────────────────────────────────────────────────
        Rectangle { width: parent.width; height: 1; color: Theme.surface3 }

        Text {
            text: "VRAM"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
        }

        // Barra VRAM usada/total
        Item {
            width: parent.width; height: 6
            visible: root.gpuVramTotalMb > 0
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(4, root._vramPct * parent.width)
                radius: 3; color: root._vramColor
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        Row {
            spacing: 16
            visible: root.gpuVramTotalMb > 0
            Text {
                text: {
                    if (root.gpuVramUsedMb >= 1024)
                        return (root.gpuVramUsedMb / 1024).toFixed(1) + " GB"
                    return root.gpuVramUsedMb + " MB"
                }
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
            }
            Text {
                text: {
                    var total = root.gpuVramTotalMb >= 1024
                        ? (root.gpuVramTotalMb / 1024).toFixed(0) + " GB total"
                        : root.gpuVramTotalMb + " MB total"
                    return total + "  (" + Math.round(root._vramPct * 100) + "%)"
                }
                font.pixelSize: 11; color: Theme.muted1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            visible: root.gpuVramTotalMb <= 0
            text: "VRAM data not available"
            font.pixelSize: 10; color: Theme.muted2
        }

        // ── Mini cards ────────────────────────────────────────────────────
        Row {
            width: parent.width; spacing: 6

            Repeater {
                model: [
                    { value: root.gpuPercent + "%",
                      label: "GPU use",
                      color: root._accentColor },
                    { value: root.gpuTemp > 0 ? root.gpuTemp + " °C" : "—",
                      label: "Temp",
                      color: root._accentColor },
                    { value: root.gpuVramTotalMb > 0
                          ? Math.round(root._vramPct * 100) + "%"
                          : "—",
                      label: "VRAM use",
                      color: root._vramColor }
                ]

                Rectangle {
                    id: gpuStatCard
                    required property var modelData
                    width: (parent.width - 12) / 3
                    height: 48; radius: 8; color: Theme.surface3
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: gpuStatCard.modelData.value
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: gpuStatCard.modelData.color
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: gpuStatCard.modelData.label
                            font.pixelSize: 9; color: Theme.muted2
                        }
                    }
                }
            }
        }
    }
}

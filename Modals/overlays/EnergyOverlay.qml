// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import "../../Components"

// EnergyOverlay — read-only current-state power view (Slice 1).
// Battery state reactivo vía SysData/UPower; consumption rows vía pollers
// con gate de visibilidad. Todos los valores degradan a "—" si la fuente
// falta; sin batería muestra estado consumption-only. Material-you (Theme).
OverlayWindow {
    id: root

    entryId:        "energy"        // OverlayWindow auto-gobierna visibilidad vía OverlaysManager
    corner:         "bottom-right"
    overlayWidth:   320
    restingOpacity: 0.95
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0               // 0 = persiste hasta que el usuario lo cierra
    showAccent:     false
    // mouseThrough queda en false: sin botones, pero arrastrable en modo edición.
    // La posición (offsets) la gobierna OverlaysManager vía su OverlayEntry.

    onVisibleChanged: SysData.anyEnergyVisible = visible

    function fmtWatts(w) {
        if (w === undefined || w === null || w < 0) return "—"
        return (Math.round(w * 10) / 10) + " W"
    }

    readonly property string cpuWattsText: SysData.cpuPowerW < 0 ? "—" : "~" + Math.round(SysData.cpuPowerW) + " W · est"
    readonly property string batTimeText: {
        if (!SysData.batAvailable || SysData.batFull) return ""
        const t = SysData.batCharging ? SysData.batTimeFull : SysData.batTimeEmpty
        return Formatters.fmtTime(t)
    }
    readonly property color batPctColor: SysData.batCharging ? Theme.success
        : SysData.batPercent > 50 ? Theme.text
        : SysData.batPercent > 20 ? Theme.yellow
        : Theme.error

    // Contenido (slot por defecto → contentArea)
    Column {
        id: energyCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 16
        }
        spacing: 8

        // Header
        Item {
            width: parent.width
            height: 22
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Energy"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                visible: SysData.batAvailable
                text: SysData.batStatus
                font.pixelSize: 11
                color: Theme.muted1
            }
        }

        // Battery section (solo con batería)
        Column {
            width: parent.width
            spacing: 6
            visible: SysData.batAvailable

            Row {
                spacing: 10
                Text {
                    text: SysData.batPercent + "%"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: root.batPctColor
                }
                Text {
                    visible: root.batTimeText.length > 0
                    text: (SysData.batCharging ? "Full in " : "Empty in ") + root.batTimeText
                    font.pixelSize: 11
                    color: Theme.muted2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                width: parent.width
                height: 6
                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(4, SysData.batPercent / 100 * parent.width)
                    radius: 3
                    color: SysData.batCharging ? Theme.success : Theme.accent
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }

        // No-battery empty state: consumption-only
        Text {
            width: parent.width
            visible: !SysData.batAvailable
            wrapMode: Text.WordWrap
            text: "No battery detected — showing consumption only."
            font.pixelSize: 11
            color: Theme.muted2
        }

        // Divider
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surface3
        }

        // Consumption rows
        Column {
            id: rowsCol
            width: parent.width
            spacing: 2
            Repeater {
                model: [
                    { label: "System", value: root.fmtWatts(SysData.sysPowerW) },
                    { label: "GPU",    value: root.fmtWatts(SysData.gpuPowerW) },
                    { label: "CPU",    value: root.cpuWattsText }
                ]
                delegate: Item {
                    id: rowDelegate
                    required property var modelData
                    width: rowsCol.width
                    height: 20
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: rowDelegate.modelData.label
                        font.pixelSize: 11
                        color: Theme.muted1
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: rowDelegate.modelData.value
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }
            }
        }

        // Full-charge stale-guard caption: explica el "—" en System.
        Text {
            width: parent.width
            visible: SysData.batAvailable && SysData.batFull
            wrapMode: Text.WordWrap
            text: "Full charge — power sensor idle."
            font.pixelSize: 10
            color: Theme.muted2
        }
    }
}

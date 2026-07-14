import QtQuick
import "../../Components"

// ── CcDiskPanel ─────────────────────────────────────────────────────────────
// Panel de detalle de disco: modelo NVMe, firmware, temp, uso de Root/Home
// (2x2 cards de resumen) y tasas de I/O (lectura/escritura) del sampler
// two-shot de /proc/diskstats.
Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: diskCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
        border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property bool   diskAvailable
    required property int    diskPercent
    required property int    diskUsed
    required property int    diskAvail
    required property int    homePercent
    required property int    homeUsed
    required property int    homeAvail
    required property string nvmeModel
    required property string nvmeFw
    required property int    nvmeTemp
    required property real   diskReadMbs
    required property real   diskWriteMbs

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Helpers ──────────────────────────────────────────────────────────
    function tempColor(t) {
        if (t <= 0)  return Theme.muted2
        if (t >= 70) return Theme.error
        if (t >= 60) return Theme.warning
        return Theme.accent
    }

    function usageColor(pct) {
        if (pct >= 90) return Theme.error
        if (pct >= 75) return Theme.warning
        return Theme.accent
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Column {
        id: diskCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Disco"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: diskCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: diskCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── Modelo NVMe + firmware · temp ──────────────────────────────────
        Column {
            width: parent.width
            spacing: 2

            Text {
                text: root.nvmeModel !== "" ? root.nvmeModel : "NVMe SSD"
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
                elide: Text.ElideRight; width: parent.width
            }

            // Sub-línea: "FW: ABG2 · 38°C"
            Text {
                text: {
                    var parts = []
                    if (root.nvmeFw !== "") parts.push("FW: " + root.nvmeFw)
                    if (root.nvmeTemp > 0)  parts.push(root.nvmeTemp + "°C")
                    return parts.join(" · ")
                }
                font.pixelSize: 10; color: root.tempColor(root.nvmeTemp)
            }
        }

        // ── 4 cards resumen: Root % / Home % / Root GB / Home GB ──────────
        Column {
            width: parent.width
            spacing: 6

            Row {
                width: parent.width; spacing: 6

                Repeater {
                    model: [
                        {
                            value: root.diskPercent + "%",
                            label: "Root",
                            color: root.usageColor(root.diskPercent)
                        },
                        {
                            value: root.homePercent + "%",
                            label: "Home",
                            color: root.usageColor(root.homePercent)
                        }
                    ]

                    Rectangle {
                        id: pctCard
                        required property var modelData
                        width: (parent.width - 6) / 2
                        height: 48; radius: 8; color: Theme.surface3
                        Column {
                            anchors.centerIn: parent; spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pctCard.modelData.value
                                font.pixelSize: 13; font.weight: Font.DemiBold
                                color: pctCard.modelData.color
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pctCard.modelData.label
                                font.pixelSize: 9; color: Theme.muted2
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 6

                Repeater {
                    model: [
                        {
                            value: root.diskUsed + "/" + (root.diskUsed + root.diskAvail) + " GB",
                            label: "Root"
                        },
                        {
                            value: root.homeUsed + "/" + (root.homeUsed + root.homeAvail) + " GB",
                            label: "Home"
                        }
                    ]

                    Rectangle {
                        id: gbCard
                        required property var modelData
                        width: (parent.width - 6) / 2
                        height: 48; radius: 8; color: Theme.surface3
                        Column {
                            anchors.centerIn: parent; spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: gbCard.modelData.value
                                font.pixelSize: 12; font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: gbCard.modelData.label
                                font.pixelSize: 9; color: Theme.muted2
                            }
                        }
                    }
                }
            }
        }

        // ── I/O rates ────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 4

            Text {
                text: "I/O"
                font.pixelSize: 10; color: Theme.muted2
            }

            Row {
                width: parent.width; spacing: 6

                Repeater {
                    model: [
                        {
                            icon: "󱦳",
                            label: "Read",
                            value: root.diskAvailable ? root.diskReadMbs.toFixed(1) + " MB/s" : "—"
                        },
                        {
                            icon: "󱦴",
                            label: "Write",
                            value: root.diskAvailable ? root.diskWriteMbs.toFixed(1) + " MB/s" : "—"
                        }
                    ]

                    Rectangle {
                        id: ioCard
                        required property var modelData
                        width: (parent.width - 6) / 2
                        height: 40; radius: 8; color: Theme.surface3

                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text {
                                text: ioCard.modelData.icon
                                font.pixelSize: 13; color: Theme.muted1
                            }
                            Text {
                                text: ioCard.modelData.value
                                font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                            }
                        }
                    }
                }
            }

            Text {
                text: "actualizado al abrir"
                font.pixelSize: 9; color: Theme.muted2
            }
        }

        // ── Placeholder mientras carga ────────────────────────────────────
        Item {
            width: parent.width; height: 32
            visible: !root.diskAvailable

            Text {
                anchors.centerIn: parent
                text: "Cargando…"
                font.pixelSize: 10; color: Theme.muted2
            }
        }
    }
}

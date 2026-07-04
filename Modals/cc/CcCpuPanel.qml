import QtQuick
import "../../Components"

// ── CcCpuPanel ───────────────────────────────────────────────────────────────
// Panel de detalle de CPU: modelo, threads, frecuencia, gobernador,
// 2 cards de resumen (uso + temp) y lista de núcleos con barra + temp.
Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: cpuCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
        border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property bool   cpuAvailable
    required property int    cpuPercent
    required property int    cpuTemp
    required property string cpuModel
    required property int    cpuAvgFreq
    required property string cpuGov
    required property int    cpuNcores
    required property var    cpuCorePcts
    required property var    cpuCoreTemps
    required property bool   cpuLoaded

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Helpers ──────────────────────────────────────────────────────────
    function tempColor(t) {
        if (t <= 0)  return Theme.muted2
        if (t >= 85) return Theme.error
        if (t >= 70) return Theme.warning
        if (t >= 55) return Theme.yellow
        return Theme.accent
    }

    function usageColor(pct) {
        if (pct >= 90) return Theme.error
        if (pct >= 70) return Theme.warning
        return Theme.accent
    }

    // threads = NCORES cuando viene del script; fallback a corePcts.length
    property int _threads: root.cpuNcores > 0
                           ? root.cpuNcores
                           : (root.cpuCorePcts ? root.cpuCorePcts.length : 0)

    property string _freqLabel: root.cpuAvgFreq > 0
                                ? (root.cpuAvgFreq >= 1000
                                   ? (root.cpuAvgFreq / 1000).toFixed(1) + " GHz"
                                   : root.cpuAvgFreq + " MHz")
                                : ""

    property string _govLabel: {
        var g = root.cpuGov
        if (g === "performance")       return "performance"
        if (g === "powersave")         return "powersave"
        if (g === "schedutil")         return "schedutil"
        if (g === "conservative")      return "conservative"
        if (g === "ondemand")          return "ondemand"
        return g
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Column {
        id: cpuCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "CPU"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: cpuCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: cpuCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── Modelo + threads · freq · gov ─────────────────────────────────
        Column {
            width: parent.width
            spacing: 2

            Text {
                text: root.cpuModel !== "" ? root.cpuModel : "CPU"
                font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
                elide: Text.ElideRight; width: parent.width
            }

            // Sub-línea: "8 threads · 4600 MHz · performance"
            Text {
                visible: root._threads > 0 || root._freqLabel !== "" || root._govLabel !== ""
                text: {
                    var parts = []
                    if (root._threads > 0)    parts.push(root._threads + " threads")
                    if (root._freqLabel !== "") parts.push(root._freqLabel)
                    if (root._govLabel !== "")  parts.push(root._govLabel)
                    return parts.join(" · ")
                }
                font.pixelSize: 10; color: Theme.muted2
            }
        }

        // ── 2 cards resumen: Uso + Temp ────────────────────────────────────
        Row {
            width: parent.width; spacing: 6

            Repeater {
                model: [
                    {
                        value: root.cpuPercent + "%",
                        label: "Uso",
                        color: root.usageColor(root.cpuPercent)
                    },
                    {
                        value: root.cpuTemp > 0 ? root.cpuTemp + " °C" : "—",
                        label: "Temp",
                        color: root.tempColor(root.cpuTemp)
                    }
                ]

                Rectangle {
                    id: summaryCard
                    required property var modelData
                    width: (parent.width - 6) / 2
                    height: 48; radius: 8; color: Theme.surface3
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: summaryCard.modelData.value
                            font.pixelSize: 13; font.weight: Font.DemiBold
                            color: summaryCard.modelData.color
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: summaryCard.modelData.label
                            font.pixelSize: 9; color: Theme.muted2
                        }
                    }
                }
            }
        }

        // ── Lista de núcleos ──────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 4
            visible: root.cpuLoaded && root.cpuCorePcts && root.cpuCorePcts.length > 0

            Repeater {
                model: root.cpuCorePcts ? root.cpuCorePcts.length : 0

                Item {
                    id: coreRow
                    required property int index
                    width: cpuCol.width
                    height: 18

                    // Número de núcleo
                    Text {
                        id: coreLabel
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: coreRow.index
                        font.pixelSize: 9; color: Theme.muted2
                        width: 10; horizontalAlignment: Text.AlignRight
                    }

                    // Barra de uso
                    Item {
                        id: coreBarItem
                        anchors {
                            left: coreLabel.right; leftMargin: 6
                            right: coreTempText.left; rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        height: 6

                        property int pct: (root.cpuCorePcts && coreRow.index < root.cpuCorePcts.length)
                                          ? root.cpuCorePcts[coreRow.index] : 0

                        Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: Math.max(3, coreBarItem.pct / 100 * parent.width)
                            radius: 3
                            color: root.usageColor(coreBarItem.pct)
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }

                    // Porcentaje de uso
                    Text {
                        id: corePctText
                        anchors { right: coreTempText.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: {
                            var p = (root.cpuCorePcts && coreRow.index < root.cpuCorePcts.length)
                                    ? root.cpuCorePcts[coreRow.index] : 0
                            return p + "%"
                        }
                        font.pixelSize: 9; color: Theme.text
                        width: 26; horizontalAlignment: Text.AlignRight
                    }

                    // Temperatura del núcleo
                    Text {
                        id: coreTempText
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        property int t: {
                            if (!root.cpuCoreTemps || root.cpuCoreTemps.length === 0) return 0
                            // core id = thread % nCoresFísicos (= CORE_TEMPS.length)
                            // En Intel HT: threads 0-7 y 8-15 mapean a cores 0-7
                            var physIdx = coreRow.index % root.cpuCoreTemps.length
                            return root.cpuCoreTemps[physIdx]
                        }
                        text: t > 0 ? t + "°" : "—"
                        font.pixelSize: 9
                        color: root.tempColor(t)
                        width: 28; horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // ── Placeholder mientras carga ────────────────────────────────────
        Item {
            width: parent.width; height: 32
            visible: !root.cpuLoaded

            Text {
                anchors.centerIn: parent
                text: "Cargando núcleos…"
                font.pixelSize: 10; color: Theme.muted2
            }
        }
    }
}

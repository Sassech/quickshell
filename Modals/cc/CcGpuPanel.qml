import QtQuick
import "../../Components"

pragma ComponentBehavior: Bound

// CcGpuPanel Panel de detalle multi-GPU. Muestra cada GPU detectada por gpu-detail.sh:   - dGPU (NVIDIA/AMD): 2 cards resumen + barras de
// shader/VRAM/freq/power   - iGPU (Intel): fila compacta con freq, rango y estado RC6/throttle
Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: gpuCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.2)
        border.width: 1
    }

    required property var  gpus
    required property bool gpuLoaded

    signal closeRequested()

    function tempColor(t) {
        if (t <= 0)  return Theme.muted2
        if (t >= 85) return Theme.error
        if (t >= 70) return Theme.warning
        if (t >= 55) return Theme.yellow
        return Theme.accent2
    }

    function usageColor(pct) {
        if (pct >= 90) return Theme.error
        if (pct >= 70) return Theme.warning
        return Theme.accent2
    }

    function fmtMhz(mhz) {
        if (mhz <= 0) return "—"
        if (mhz >= 1000) return (mhz / 1000).toFixed(1) + " GHz"
        return mhz + " MHz"
    }

    function fmtMb(mb) {
        if (mb <= 0)   return "—"
        if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB"
        return mb + " MB"
    }

    Column {
        id: gpuCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "GPU"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
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

        Item {
            width: parent.width; height: 32
            visible: !root.gpuLoaded
            Text {
                anchors.centerIn: parent
                text: "Cargando GPUs…"
                font.pixelSize: 10; color: Theme.muted2
            }
        }

        // Lista de GPUs
        Repeater {
            model: (root.gpuLoaded && root.gpus) ? root.gpus.length : 0

            Column {
                id: gpuEntry
                required property int index
                width: gpuCol.width
                spacing: 8

                property var gpu: (root.gpus && index < root.gpus.length) ? root.gpus[index] : null
                property bool isIntel: gpu ? gpu.vendor === "intel" : false
                property bool isActive: gpu ? (gpu.util >= 0) : false

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.surface3
                    visible: gpuEntry.index > 0
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: !gpuEntry.isIntel && gpuEntry.gpu !== null

                    Column {
                        width: parent.width
                        spacing: 2
                        Text {
                            text: gpuEntry.gpu ? gpuEntry.gpu.name : ""
                            font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text
                            elide: Text.ElideRight; width: parent.width
                        }
                        Text {
                            visible: text !== ""
                            text: {
                                if (!gpuEntry.gpu) return ""
                                var parts = []
                                if (gpuEntry.gpu.vendor) parts.push(gpuEntry.gpu.vendor.toUpperCase())
                                if (gpuEntry.gpu.driver) parts.push("driver " + gpuEntry.gpu.driver)
                                return parts.join(" · ")
                            }
                            font.pixelSize: 10; color: Theme.muted2
                        }
                    }

                    Row {
                        width: parent.width; spacing: 6

                        Rectangle {
                            width: (parent.width - 6) / 2; height: 48
                            radius: 8; color: Theme.surface3
                            Column {
                                anchors.centerIn: parent; spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: gpuEntry.gpu ? gpuEntry.gpu.util + "%" : "—"
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                    color: gpuEntry.gpu ? root.usageColor(gpuEntry.gpu.util) : Theme.muted2
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "GPU"; font.pixelSize: 9; color: Theme.muted2
                                }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 6) / 2; height: 48
                            radius: 8; color: Theme.surface3
                            Column {
                                anchors.centerIn: parent; spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: gpuEntry.gpu && gpuEntry.gpu.temp > 0
                                          ? gpuEntry.gpu.temp + " °C" : "—"
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                    color: gpuEntry.gpu ? root.tempColor(gpuEntry.gpu.temp) : Theme.muted2
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Temp"; font.pixelSize: 9; color: Theme.muted2
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width; height: 16
                            Text {
                                id: dShaderLbl
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Shader"; font.pixelSize: 10; color: Theme.muted2; width: 42
                            }
                            Item {
                                id: dShaderBar
                                anchors {
                                    left: dShaderLbl.right; leftMargin: 8
                                    right: dShaderVal.left; rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 5
                                property real pct: gpuEntry.gpu ? gpuEntry.gpu.util / 100 : 0
                                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: Math.max(3, dShaderBar.pct * parent.width)
                                    radius: 3
                                    color: gpuEntry.gpu ? root.usageColor(gpuEntry.gpu.util) : Theme.muted2
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                }
                            }
                            Text {
                                id: dShaderVal
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: gpuEntry.gpu ? gpuEntry.gpu.util + "%" : "—"
                                font.pixelSize: 10; color: Theme.text
                                width: 32; horizontalAlignment: Text.AlignRight
                            }
                        }

                        Item {
                            width: parent.width; height: 16
                            visible: gpuEntry.gpu ? gpuEntry.gpu.vramTotal > 0 : false
                            Text {
                                id: dVramLbl
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "VRAM"; font.pixelSize: 10; color: Theme.muted2; width: 42
                            }
                            Item {
                                id: dVramBar
                                anchors {
                                    left: dVramLbl.right; leftMargin: 8
                                    right: dVramVal.left; rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 5
                                property real pct: gpuEntry.gpu && gpuEntry.gpu.vramTotal > 0
                                                   ? gpuEntry.gpu.vramUsed / gpuEntry.gpu.vramTotal : 0
                                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: Math.max(3, dVramBar.pct * parent.width)
                                    radius: 3
                                    color: dVramBar.pct >= 0.9 ? Theme.error
                                         : dVramBar.pct >= 0.7 ? Theme.warning
                                         : Theme.accent2
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                }
                            }
                            Text {
                                id: dVramVal
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: gpuEntry.gpu
                                      ? root.fmtMb(gpuEntry.gpu.vramUsed) + " / " + root.fmtMb(gpuEntry.gpu.vramTotal)
                                      : "—"
                                font.pixelSize: 10; color: Theme.text
                                width: 90; horizontalAlignment: Text.AlignRight
                            }
                        }

                        Item {
                            width: parent.width; height: 16
                            visible: gpuEntry.gpu ? gpuEntry.gpu.freq > 0 : false
                            Text {
                                id: dFreqLbl
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Freq"; font.pixelSize: 10; color: Theme.muted2; width: 42
                            }
                            Text {
                                anchors { left: dFreqLbl.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                text: {
                                    if (!gpuEntry.gpu) return "—"
                                    var s = root.fmtMhz(gpuEntry.gpu.freq) + " core"
                                    if (gpuEntry.gpu.freqMem > 0)
                                        s += " · " + root.fmtMhz(gpuEntry.gpu.freqMem) + " mem"
                                    return s
                                }
                                font.pixelSize: 10; color: Theme.text
                            }
                        }

                        Item {
                            width: parent.width; height: 16
                            visible: gpuEntry.gpu ? gpuEntry.gpu.power > 0 : false
                            Text {
                                id: dPwrLbl
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Power"; font.pixelSize: 10; color: Theme.muted2; width: 42
                            }
                            Text {
                                anchors { left: dPwrLbl.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                text: {
                                    if (!gpuEntry.gpu) return "—"
                                    var s = gpuEntry.gpu.power.toFixed(1) + " W"
                                    if (gpuEntry.gpu.powerLimit > 0)
                                        s += " / " + gpuEntry.gpu.powerLimit.toFixed(0) + " W"
                                    return s
                                }
                                font.pixelSize: 10; color: Theme.text
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: gpuEntry.isIntel && gpuEntry.gpu !== null

                    Row {
                        spacing: 6
                        Text {
                            text: {
                                if (!gpuEntry.gpu) return "Intel GPU"
                                // Acortar nombre largo
                                var n = gpuEntry.gpu.name
                                n = n.replace("Intel Corporation ", "")
                                n = n.replace(/TigerLake-H\s+\w+\s+/, "")
                                n = n.replace(/\[|\]/g, "")
                                return n.trim()
                            }
                            font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
                        }
                        Text {
                            text: "iGPU"
                            font.pixelSize: 9; color: Theme.muted2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        width: parent.width; height: 16
                        Text {
                            id: iFreqLbl
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "Freq"; font.pixelSize: 10; color: Theme.muted2; width: 42
                        }
                        Item {
                            id: iFreqBar
                            anchors {
                                left: iFreqLbl.right; leftMargin: 8
                                right: iFreqVal.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            height: 5
                            property real pct: (gpuEntry.gpu && gpuEntry.gpu.freqMax > 0)
                                               ? gpuEntry.gpu.freq / gpuEntry.gpu.freqMax : 0
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(iFreqBar.pct > 0 ? 3 : 0, iFreqBar.pct * parent.width)
                                radius: 3; color: Theme.accent2
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            id: iFreqVal
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: gpuEntry.gpu ? root.fmtMhz(gpuEntry.gpu.freq) : "—"
                            font.pixelSize: 10; color: Theme.text
                            width: 55; horizontalAlignment: Text.AlignRight
                        }
                    }

                    Text {
                        visible: gpuEntry.gpu ? gpuEntry.gpu.freqMax > 0 : false
                        text: gpuEntry.gpu
                              ? root.fmtMhz(gpuEntry.gpu.freqMin) + " – " + root.fmtMhz(gpuEntry.gpu.freqMax) + " rango"
                              : ""
                        font.pixelSize: 9; color: Theme.muted2
                    }

                    Row {
                        spacing: 8

                        Row {
                            spacing: 4
                            visible: gpuEntry.gpu !== null
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: (gpuEntry.gpu && gpuEntry.gpu.rc6) ? Theme.accent : Theme.muted2
                            }
                            Text {
                                text: "RC6"
                                font.pixelSize: 9
                                color: (gpuEntry.gpu && gpuEntry.gpu.rc6) ? Theme.accent : Theme.muted2
                            }
                        }

                        Row {
                            spacing: 4
                            visible: gpuEntry.gpu ? gpuEntry.gpu.throttle > 0 : false
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.warning
                            }
                            Text {
                                text: "throttle"; font.pixelSize: 9; color: Theme.warning
                            }
                        }

                        Text {
                            visible: gpuEntry.gpu ? gpuEntry.gpu.powerState !== "" : false
                            text: gpuEntry.gpu ? gpuEntry.gpu.powerState : ""
                            font.pixelSize: 9; color: Theme.muted2
                        }
                    }
                }
            }
        }
    }
}

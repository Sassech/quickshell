// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../Components"

// SystemStatsOverlay — glanceable CPU/RAM/GPU/Disk/Fan readout.
// Ported from CcCpuPanel/CcRamPanel/CcGpuPanel(SysData summary)/CcSystemSection disk
// card/CcPowerPanel fan rows. Single source of truth = SysData singleton; no
// CcGpuController. All missing sensors degrade to "—"; no battery tile (Energy owns it).
// Wired via OverlaysManager entry "sysstats" + shell Variants + TopBar toggle;
// onVisibleChanged drives SysData.anySysStatsVisible (poller gate).
OverlayWindow {
    id: root

    entryId:        "sysstats"
    corner:         "bottom-right"
    overlayWidth:   700
    restingOpacity: 0.95
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0               // 0 = persists until user closes
    borderColor:    Theme.surface2
    showAccent:     false

    onVisibleChanged: {
        SysData.anySysStatsVisible = visible
        if (visible) SysData.refreshSysStatsDetail()
    }

    function usageColor(pct) {
        if (pct >= 90) return Theme.error
        if (pct >= 70) return Theme.warning
        return Theme.accent
    }

    function tempColor(t) {
        if (t <= 0)  return Theme.muted2
        if (t >= 85) return Theme.error
        if (t >= 70) return Theme.warning
        if (t >= 55) return Theme.yellow
        return Theme.accent
    }

    function fmtWatts(w) {
        if (w === undefined || w === null || w < 0) return "—"
        return (Math.round(w * 10) / 10) + " W"
    }

    function fmtMhz(mhz) {
        if (mhz === undefined || mhz === null || mhz <= 0) return "—"
        if (mhz >= 1000) return (mhz / 1000).toFixed(1) + " GHz"
        return mhz + " MHz"
    }

    function fmtMb(mb) {
        if (mb === undefined || mb === null || mb <= 0) return "—"
        if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB"
        return mb + " MB"
    }

    readonly property int _threads: SysData.cpuNcores > 0
        ? SysData.cpuNcores
        : (SysData.cpuCorePcts ? SysData.cpuCorePcts.length : 0)

    readonly property string _freqLabel: SysData.cpuAvgFreqMhz > 0
        ? root.fmtMhz(Math.round(SysData.cpuAvgFreqMhz)) : ""

    readonly property string _govLabel: {
        var g = SysData.cpuGovernor
        if (g === "performance" || g === "powersave" || g === "schedutil"
                || g === "conservative" || g === "ondemand") return g
        return g
    }

    readonly property string _cpuSubline: {
        var parts = []
        if (root._threads > 0) parts.push(root._threads + " threads")
        if (root._freqLabel !== "") parts.push(root._freqLabel)
        if (root._govLabel !== "") parts.push(root._govLabel)
        return parts.join(" · ")
    }

    readonly property string _ramSubline: SysData.ramTotalGb > 0
        ? SysData.ramTotalGb.toFixed(0) + " GB total" : "—"

    readonly property string _gpuVramText: {
        if (!SysData.gpuAvailable) return "—"
        if (SysData.gpuVramTotalMb <= 0) return "—"
        return root.fmtMb(SysData.gpuVramUsedMb) + " / " + root.fmtMb(SysData.gpuVramTotalMb)
    }

    readonly property real _gpuVramPct: {
        if (!SysData.gpuAvailable || SysData.gpuVramTotalMb <= 0) return 0
        return SysData.gpuVramUsedMb / SysData.gpuVramTotalMb
    }

    readonly property string _diskIoText: {
        if (!SysData.diskAvailable) return "—"
        var r = isNaN(SysData.diskReadMbs) ? "—" : SysData.diskReadMbs.toFixed(1) + " MB/s"
        var w = isNaN(SysData.diskWriteMbs) ? "—" : SysData.diskWriteMbs.toFixed(1) + " MB/s"
        return "↓ " + r + " · ↑ " + w
    }

    // X close button (absolute, consistent with ClimateOverlay)
    MouseArea {
        id: closeBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 20; height: 20
        cursorShape: Qt.PointingHandCursor
        z: 10
        onClicked: {
            var e = OverlaysManager.get("sysstats")
            if (e) e.enabled = false
        }
        Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted3; font.pixelSize: 12 }
    }

    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 14

        // Header
        Item {
            width: parent.width; height: 22
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "System Stats"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
                visible: SysData.cpuModel !== ""
                text: SysData.cpuModel
                font.pixelSize: 10
                color: Theme.muted2
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - 160)
                horizontalAlignment: Text.AlignRight
            }
        }

        // Two-column body: left CPU (scrolls), right tiles (fixed)
        Row {
            id: bodyRow
            width: parent.width
            spacing: 12

            // — Left: CPU —
            Column {
                id: cpuCol
                width: (parent.width - 12) / 2
                spacing: 10

                Text {
                    visible: root._cpuSubline !== ""
                    text: root._cpuSubline
                    font.pixelSize: 10
                    color: Theme.muted2
                }

                Row {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: [
                            { value: SysData.cpuAvailable ? SysData.cpuPercent + "%" : "—",
                              label: "Uso", color: root.usageColor(SysData.cpuPercent) },
                            { value: SysData.cpuTemp > 0 ? SysData.cpuTemp + " °C" : "—",
                              label: "Temp", color: root.tempColor(SysData.cpuTemp) }
                        ]
                        Rectangle {
                            id: cpuSummaryCard
                            required property var modelData
                            width: (parent.width - 6) / 2
                            height: 48; radius: 8; color: Theme.surface3
                            Column {
                                anchors.centerIn: parent; spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cpuSummaryCard.modelData.value
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                    color: cpuSummaryCard.modelData.color
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cpuSummaryCard.modelData.label
                                    font.pixelSize: 9; color: Theme.muted2
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "Per-core"
                    font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
                }

                Flickable {
                    id: coreFlick
                    width: parent.width
                    height: Math.min(coreListCol.implicitHeight, 380)
                    contentWidth: width
                    contentHeight: coreListCol.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: (SysData.cpuCorePcts ? SysData.cpuCorePcts.length : 0) > 12
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 3; radius: 2
                            color: Theme.accent
                            opacity: 0.6
                        }
                    }

                    Column {
                        id: coreListCol
                        width: coreFlick.width
                        spacing: 4

                        Repeater {
                            model: SysData.cpuCorePcts ? SysData.cpuCorePcts.length : 0
                            Item {
                                id: coreRow
                                required property int index
                                width: coreListCol.width
                                height: 18

                                Text {
                                    id: coreLabel
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text: coreRow.index
                                    font.pixelSize: 9; color: Theme.muted2
                                    width: 14; horizontalAlignment: Text.AlignRight
                                }

                                Item {
                                    id: coreBarItem
                                    anchors {
                                        left: coreLabel.right; leftMargin: 6
                                        right: coreTempText.left; rightMargin: 6
                                        verticalCenter: parent.verticalCenter
                                    }
                                    height: 6

                                    property int pct: (SysData.cpuCorePcts && coreRow.index < SysData.cpuCorePcts.length)
                                        ? SysData.cpuCorePcts[coreRow.index] : 0

                                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: Math.max(3, coreBarItem.pct / 100 * parent.width)
                                        radius: 3
                                        color: root.usageColor(coreBarItem.pct)
                                        Behavior on width { NumberAnimation { duration: 250 } }
                                    }
                                }

                                Text {
                                    id: corePctText
                                    anchors { right: coreTempText.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                    text: {
                                        var p = (SysData.cpuCorePcts && coreRow.index < SysData.cpuCorePcts.length)
                                            ? SysData.cpuCorePcts[coreRow.index] : 0
                                        return p + "%"
                                    }
                                    font.pixelSize: 9; color: Theme.text
                                    width: 30; horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    id: coreTempText
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    property int t: {
                                        if (!SysData.cpuCoreTemps || SysData.cpuCoreTemps.length === 0) return 0
                                        var physIdx = coreRow.index % SysData.cpuCoreTemps.length
                                        return SysData.cpuCoreTemps[physIdx]
                                    }
                                    text: t > 0 ? t + "°" : "—"
                                    font.pixelSize: 9
                                    color: root.tempColor(t)
                                    width: 28; horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !SysData.cpuCorePcts || SysData.cpuCorePcts.length === 0
                    text: "Cargando núcleos…"
                    font.pixelSize: 10; color: Theme.muted2
                }
            }

            // — Right: RAM / GPU / Disk / Fan —
            Column {
                id: rightCol
                width: (parent.width - 12) / 2
                spacing: 12

                // RAM
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "RAM"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: root._ramSubline; font.pixelSize: 10; color: Theme.muted2 }

                    Row {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [
                                { value: SysData.ramAvailable ? SysData.ramUsedGb.toFixed(1) + " GB" : "—",
                                  label: "Usado", color: root.usageColor(SysData.ramPercent) },
                                { value: SysData.ramAvailable ? SysData.ramAvailGb.toFixed(1) + " GB" : "—",
                                  label: "Libre", color: Theme.accent }
                            ]
                            Rectangle {
                                id: ramSummaryCard
                                required property var modelData
                                width: (parent.width - 6) / 2
                                height: 48; radius: 8; color: Theme.surface3
                                Column {
                                    anchors.centerIn: parent; spacing: 3
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: ramSummaryCard.modelData.value
                                        font.pixelSize: 13; font.weight: Font.DemiBold
                                        color: ramSummaryCard.modelData.color
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: ramSummaryCard.modelData.label
                                        font.pixelSize: 9; color: Theme.muted2
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [
                                { label: "Apps", gb: SysData.ramAppsGb,
                                  pct: SysData.ramTotalGb > 0 ? SysData.ramAppsGb / SysData.ramTotalGb : 0,
                                  color: root.usageColor(SysData.ramPercent) },
                                { label: "Caché", gb: SysData.ramCacheGb,
                                  pct: SysData.ramTotalGb > 0 ? SysData.ramCacheGb / SysData.ramTotalGb : 0,
                                  color: Theme.muted1 },
                                { label: "Libre", gb: SysData.ramAvailGb,
                                  pct: SysData.ramTotalGb > 0 ? SysData.ramAvailGb / SysData.ramTotalGb : 0,
                                  color: Theme.accent }
                            ]
                            Item {
                                id: segRow
                                required property var modelData
                                width: rightCol.width
                                height: 16
                                Text {
                                    id: segLabel
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text: segRow.modelData.label
                                    font.pixelSize: 10; color: Theme.muted2
                                    width: 38
                                }
                                Item {
                                    anchors {
                                        left: segLabel.right; leftMargin: 8
                                        right: segGbText.left; rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    height: 5
                                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: Math.max(3, segRow.modelData.pct * parent.width)
                                        radius: 3
                                        color: segRow.modelData.color
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                    }
                                }
                                Text {
                                    id: segGbText
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text: SysData.ramAvailable ? segRow.modelData.gb.toFixed(1) + " GB" : "—"
                                    font.pixelSize: 10; color: Theme.text
                                    width: 50; horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width; height: 16
                        visible: SysData.swapTotalGb > 0
                        Text {
                            id: swapLabel
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "Swap"
                            font.pixelSize: 10; color: Theme.muted2
                            width: 38
                        }
                        Item {
                            anchors {
                                left: swapLabel.right; leftMargin: 8
                                right: swapGbText.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            height: 5
                            property real pct: SysData.swapTotalGb > 0
                                ? (SysData.swapTotalGb - SysData.swapFreeGb) / SysData.swapTotalGb : 0
                            Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(parent.pct > 0 ? 3 : 0, parent.pct * parent.width)
                                radius: 3
                                color: SysData.swapPercent >= 80 ? Theme.error
                                     : SysData.swapPercent >= 50 ? Theme.yellow
                                     : Theme.muted1
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            id: swapGbText
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: (SysData.swapTotalGb - SysData.swapFreeGb).toFixed(1) + " / " + SysData.swapTotalGb.toFixed(0) + " GB"
                            font.pixelSize: 10; color: Theme.text
                            width: 70; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

                // GPU (SysData summary only)
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "GPU"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        text: SysData.gpuAvailable && SysData.gpuName !== "" ? SysData.gpuName : "GPU"
                        font.pixelSize: 10; color: Theme.muted2
                        elide: Text.ElideRight; width: parent.width
                    }

                    Text {
                        visible: !SysData.gpuAvailable
                        text: "—"
                        font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.muted2
                    }

                    Column {
                        width: parent.width; spacing: 6
                        visible: SysData.gpuAvailable
                        Row {
                            width: parent.width; spacing: 6
                            Rectangle {
                                width: (parent.width - 6) / 2; height: 48
                                radius: 8; color: Theme.surface3
                                Column {
                                    anchors.centerIn: parent; spacing: 3
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: SysData.gpuPercent >= 0 ? SysData.gpuPercent + "%" : "—"
                                        font.pixelSize: 13; font.weight: Font.DemiBold
                                        color: SysData.gpuPercent >= 0 ? root.usageColor(SysData.gpuPercent) : Theme.muted2
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
                                        text: SysData.gpuTemp > 0 ? SysData.gpuTemp + " °C" : "—"
                                        font.pixelSize: 13; font.weight: Font.DemiBold
                                        color: root.tempColor(SysData.gpuTemp)
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Temp"; font.pixelSize: 9; color: Theme.muted2
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width; height: 16
                            Text {
                                id: vramLbl
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "VRAM"; font.pixelSize: 10; color: Theme.muted2; width: 42
                            }
                            Item {
                                id: vramBar
                                anchors {
                                    left: vramLbl.right; leftMargin: 8
                                    right: vramVal.left; rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 5
                                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: Math.max(3, root._gpuVramPct * parent.width)
                                    radius: 3
                                    color: root._gpuVramPct >= 0.9 ? Theme.error
                                         : root._gpuVramPct >= 0.7 ? Theme.warning
                                         : Theme.accent2
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                }
                            }
                            Text {
                                id: vramVal
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: root._gpuVramText
                                font.pixelSize: 10; color: Theme.text
                                width: 96; horizontalAlignment: Text.AlignRight
                            }
                        }

                        Row {
                            width: parent.width; spacing: 12
                            Text {
                                text: "Freq  " + root.fmtMhz(SysData.gpuFreqMhz)
                                font.pixelSize: 10; color: Theme.text
                            }
                            Text {
                                text: "Power  " + root.fmtWatts(SysData.gpuPowerW)
                                font.pixelSize: 10; color: Theme.text
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

                // Disk (sole owner after Energy removal)
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "Disk"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                    Row {
                        spacing: 6
                        Text {
                            text: SysData.diskAvailable ? SysData.diskPercent + "%" : "—"
                            font.pixelSize: 13; font.weight: Font.DemiBold
                            color: SysData.diskPercent >= 90 ? Theme.error
                                 : SysData.diskPercent >= 75 ? Theme.warning
                                 : Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: SysData.diskAvailable
                                ? SysData.diskUsedGb + " / " + (SysData.diskUsedGb + SysData.diskAvailGb) + " GB"
                                : "—"
                            font.pixelSize: 10; color: Theme.muted2
                        }
                    }
                    Item {
                        width: parent.width; height: 5
                        Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: SysData.diskAvailable ? Math.max(4, SysData.diskPercent / 100 * parent.width) : 0
                            radius: 3
                            color: SysData.diskPercent >= 90 ? Theme.error
                                 : SysData.diskPercent >= 75 ? Theme.warning
                                 : Theme.accent
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    Text {
                        text: root._diskIoText
                        font.pixelSize: 10; font.family: "monospace"; color: Theme.text
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

                // Fan (readout only; controls stay in CC CcPowerPanel)
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "Fan"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        visible: !SysData.fanAvailable
                        text: "—"
                        font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.muted2
                    }
                    Column {
                        width: parent.width; spacing: 4
                        visible: SysData.fanAvailable
                        Repeater {
                            model: [
                                { label: "F1", rpm: SysData.fan1Rpm, pct: SysData.fan1Percent, color: Theme.accent },
                                { label: "F2", rpm: SysData.fan2Rpm, pct: SysData.fan2Percent, color: Theme.accent2 }
                            ]
                            Row {
                                id: fanRow
                                required property var modelData
                                width: rightCol.width
                                spacing: 6
                                Text {
                                    text: fanRow.modelData.label; font.pixelSize: 9; color: Theme.muted1
                                    width: 16; anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    width: fanRow.width - 80 - 16 - 6 - 6; height: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: Math.max(4, fanRow.modelData.pct / 100 * parent.width)
                                        radius: 3; color: fanRow.modelData.color
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                    }
                                }
                                Text {
                                    text: fanRow.modelData.rpm > 0 ? fanRow.modelData.rpm + " rpm" : "—"
                                    font.pixelSize: 9; color: Theme.muted2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        Text {
                            text: "Profile  " + (SysData.fanProfile !== "" ? SysData.fanProfile : "—")
                            font.pixelSize: 10; color: Theme.muted1
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 4 }
    }
}

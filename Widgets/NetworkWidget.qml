import QtQuick
import "../Components"

Rectangle {
    id: root

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 24
    radius: 8
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    // ── Icon based on connection type ────────────────────────────────────
    property string networkIcon: {
        if (SysData.netConnectionType === "ethernet") return "󰈀"
        if (!SysData.netRadioOn) return "󰤮"
        if (!SysData.netConnected) return "󰤭"
        if (SysData.netSignal >= 80) return "󰤨"
        if (SysData.netSignal >= 60) return "󰤥"
        if (SysData.netSignal >= 40) return "󰤢"
        return "󰤟"
    }

    property color iconColor: {
        if (SysData.netConnectionType === "ethernet") return Theme.accent
        if (!SysData.netRadioOn) return Theme.muted1
        if (!SysData.netConnected) return Theme.muted2
        if (SysData.netSignal >= 60) return Theme.text
        if (SysData.netSignal >= 40) return Theme.warning
        return Theme.error
    }

    // ── Speed formatting ──────────────────────────────────────────────────
    function fmtSpeed(bps) {
        if (bps < 1024)            return Math.round(bps) + " B/s"
        if (bps < 1024 * 1024)     return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / (1024*1024)).toFixed(1) + " MB/s"
        return (bps / (1024*1024*1024)).toFixed(2) + " GB/s"
    }

    // ── Content Row ──────────────────────────────────────────────────────
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.networkIcon
            font.pixelSize: 13
            color: root.iconColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (SysData.netConnectionType === "ethernet") return "Ethernet"
                if (!SysData.netRadioOn) return "Apagado"
                if (!SysData.netConnected) return "Desc."
                return SysData.netSsid || "WiFi"
            }
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
            elide: Text.ElideRight
            maximumLineCount: 1
            width: 90
        }

        // Download speed
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: SysData.netConnected

            Text {
                text: "↓"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.fmtSpeed(SysData.netDownSpeed)
                font.pixelSize: 10
                font.weight: Font.Normal
                font.family: "monospace"
                color: Theme.text
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
            }
        }

        // Upload speed
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: SysData.netConnected

            Text {
                text: "↑"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.fmtSpeed(SysData.netUpSpeed)
                font.pixelSize: 10
                font.weight: Font.Normal
                font.family: "monospace"
                color: Theme.text
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

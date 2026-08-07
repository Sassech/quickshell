import QtQuick
import "../../Components"

pragma ComponentBehavior: Bound

// ── CcRamPanel ───────────────────────────────────────────────────────────────
// Panel de detalle de RAM: desglose Apps / Caché / Libre + Swap.
Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: ramCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
        border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
    required property bool ramAvailable
    required property int  ramPercent
    required property real ramUsedGb
    required property real ramTotalGb
    required property real ramAvailGb
    required property real ramCacheGb
    required property real ramAppsGb
    required property int  swapPercent
    required property real swapTotalGb
    required property real swapFreeGb

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Helpers ──────────────────────────────────────────────────────────
    function usageColor(pct) {
        if (!root.ramAvailable) return Theme.muted2
        if (pct >= 90) return Theme.error
        if (pct >= 75) return Theme.warning
        if (pct >= 60) return Theme.yellow
        return Theme.accent
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Column {
        id: ramCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "RAM"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: ramCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: ramCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── Sub-línea: total ───────────────────────────────────────────────
        Text {
            text: root.ramTotalGb.toFixed(0) + " GB total"
            font.pixelSize: 10; color: Theme.muted2
        }

        // ── 2 cards: Usado + Libre ─────────────────────────────────────────
        Row {
            width: parent.width; spacing: 6

            Repeater {
                model: [
                    {
                        value: root.ramUsedGb.toFixed(1) + " GB",
                        label: "Usado",
                        color: root.usageColor(root.ramPercent)
                    },
                    {
                        value: root.ramAvailGb.toFixed(1) + " GB",
                        label: "Libre",
                        color: Theme.accent
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

        // ── Desglose Apps / Caché / Libre ─────────────────────────────────
        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    {
                        label: "Apps",
                        gb:    root.ramAppsGb,
                        pct:   root.ramTotalGb > 0 ? root.ramAppsGb / root.ramTotalGb : 0,
                        color: root.usageColor(root.ramPercent)
                    },
                    {
                        label: "Caché",
                        gb:    root.ramCacheGb,
                        pct:   root.ramTotalGb > 0 ? root.ramCacheGb / root.ramTotalGb : 0,
                        color: Theme.muted1
                    },
                    {
                        label: "Libre",
                        gb:    root.ramAvailGb,
                        pct:   root.ramTotalGb > 0 ? root.ramAvailGb / root.ramTotalGb : 0,
                        color: Theme.accent
                    }
                ]

                Item {
                    id: segRow
                    required property var modelData
                    required property int index
                    width: ramCol.width
                    height: 16

                    // Label
                    Text {
                        id: segLabel
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: segRow.modelData.label
                        font.pixelSize: 10; color: Theme.muted2
                        width: 38
                    }

                    // Barra
                    Item {
                        id: segBarItem
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

                    // GB
                    Text {
                        id: segGbText
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: segRow.modelData.gb.toFixed(1) + " GB"
                        font.pixelSize: 10; color: Theme.text
                        width: 50; horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // ── Swap ──────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 16
            visible: root.swapTotalGb > 0

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

                property real pct: root.swapTotalGb > 0
                                   ? (root.swapTotalGb - root.swapFreeGb) / root.swapTotalGb
                                   : 0

                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface3 }
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(parent.pct > 0 ? 3 : 0, parent.pct * parent.width)
                    radius: 3
                    color: root.swapPercent >= 80 ? Theme.error
                         : root.swapPercent >= 50 ? Theme.yellow
                         : Theme.muted1
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }

            Text {
                id: swapGbText
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (root.swapTotalGb - root.swapFreeGb).toFixed(1) + " / " + root.swapTotalGb.toFixed(0) + " GB"
                font.pixelSize: 10; color: Theme.text
                width: 70; horizontalAlignment: Text.AlignRight
            }
        }
    }
}

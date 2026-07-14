pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../Components"

// ── Controles rápidos (grid 2×3) ──────────────────────────────────────────────
// WiFi, Bluetooth, Power & Fans, Audio, Battery, Language
Column {
    id: root
    spacing: 0

    // ── Panel state ───────────────────────────────────────────────────────────
    required property string activePanel

    // ── Bluetooth ─────────────────────────────────────────────────────────────
    required property var    btAdapter
    required property bool   btPowered
    required property int    btConnectedCount
    required property string btFirstConnectedName

    // ── Battery ───────────────────────────────────────────────────────────────
    required property bool   batAvailable
    required property real   batPct
    required property bool   batCharging
    required property bool   batFull
    required property real   batTimeFull
    required property real   batTimeEmpty

    // ── Audio ─────────────────────────────────────────────────────────────────
    required property var    defaultSink

    // ── Language ──────────────────────────────────────────────────────────────
    required property string langLayout
    required property string langLocale

    // ── Power helpers (functions passed as property var) ───────────────────────
    required property var    powerLabelFn
    required property var    powerIconFn
    required property var    fmtTimeFn
    required property var    audioFormatDescFn

    // ── Signals ───────────────────────────────────────────────────────────────
    signal openWifi()
    signal openBluetooth()
    signal openPower()
    signal openAudio()
    signal openBattery()
    signal openLanguage()

    // ── Leading spacer + separator ────────────────────────────────────────────
    Item { width: parent.width; height: 10 }
    Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
    Item { width: parent.width; height: 8 }

    // ── Grid 2×3 ──────────────────────────────────────────────────────────────
    Grid {
        width: parent.width
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        // ── WiFi ──────────────────────────────────────────────────────────────
        Rectangle {
            id: wifiCard
            property bool hov: false
            width: (parent.width - 6) / 2; height: 52; radius: 10
            color: hov ? Theme.surface3
                 : (root.activePanel === "wifi"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : (SysData.netConnected
                               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                               : Theme.surface2))
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                visible: SysData.netConnected || root.activePanel === "wifi"
                width: 3; height: 24; radius: 2
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: (SysData.netConnected || root.activePanel === "wifi") ? 14 : 10
                    rightMargin: 10
                }
                spacing: 8

                Text {
                    text: {
                        if (SysData.netConnectionType === "ethernet") return "󰈀"
                        if (!SysData.netRadioOn)      return "󰤮"
                        if (!SysData.netConnected)    return "󰤭"
                        if (SysData.netSignal >= 80)  return "󰤨"
                        if (SysData.netSignal >= 60)  return "󰤥"
                        if (SysData.netSignal >= 40)  return "󰤢"
                        return "󰤟"
                    }
                    font.pixelSize: 18
                    color: SysData.netConnected ? Theme.accent : Theme.muted2
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "WiFi"
                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                    }
                    Text {
                        width: parent.width
                        text: {
                            if (SysData.netConnectionType === "ethernet") return "Ethernet"
                            if (!SysData.netRadioOn)      return "Radio off"
                            if (!SysData.netConnected)    return "Disconnected"
                            return (SysData.netSsid || "Connected") + " · " + SysData.netSignal + "%"
                        }
                        font.pixelSize: 9
                        color: SysData.netConnected ? Theme.muted1 : Theme.muted2
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: wifiCard.hov = true
                onExited:  wifiCard.hov = false
                onClicked: root.openWifi()
            }
        }

        // ── Bluetooth ─────────────────────────────────────────────────────────
        Rectangle {
            id: btCard
            property bool hov: false
            width: (parent.width - 6) / 2; height: 52; radius: 10
            color: hov ? Theme.surface3
                 : (root.activePanel === "bluetooth"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : (root.btConnectedCount > 0 && root.btPowered
                               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                               : Theme.surface2))
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                visible: (root.btConnectedCount > 0 && root.btPowered) || root.activePanel === "bluetooth"
                width: 3; height: 24; radius: 2
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: ((root.btConnectedCount > 0 && root.btPowered) || root.activePanel === "bluetooth") ? 14 : 10
                    rightMargin: 10
                }
                spacing: 8

                Text {
                    text: root.btConnectedCount > 0 ? "󰂱"
                        : (root.btPowered ? "󰂯" : "󰂲")
                    font.pixelSize: 18
                    color: root.btConnectedCount > 0 ? Theme.accent
                         : (root.btPowered ? Theme.muted1 : Theme.muted2)
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Bluetooth"
                        font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text
                    }
                    Text {
                        width: parent.width
                        text: {
                            if (!root.btAdapter)               return "Not available"
                            if (!root.btPowered)               return "Disabled"
                            if (root.btConnectedCount > 0)     return root.btFirstConnectedName
                            return "No connections"
                        }
                        font.pixelSize: 9
                        color: root.btConnectedCount > 0 ? Theme.muted1 : Theme.muted2
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: btCard.hov = true
                onExited:  btCard.hov = false
                onClicked: root.openBluetooth()
            }
        }

        // ── Power & Fans ──────────────────────────────────────────────────────
        Rectangle {
            id: powerCard
            property bool hov: false
            width: (parent.width - 6) / 2; height: 52; radius: 10
            color: hov ? Theme.surface3
                 : (root.activePanel === "power"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : Theme.surface2)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                visible: root.activePanel === "power"
                width: 3; height: 24; radius: 2
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.activePanel === "power" ? 14 : 10
                    rightMargin: 10
                }
                spacing: 8

                Text {
                    text: root.powerIconFn(PowerProfiles.profile)
                    font.pixelSize: 18
                    color: {
                        if (PowerProfiles.profile === PowerProfile.Performance) return "#ff7b72"
                        if (PowerProfiles.profile === PowerProfile.PowerSaver)  return "#79c0ff"
                        return Theme.accent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Power & Fans"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        width: parent.width
                        text: {
                            var p = root.powerLabelFn(PowerProfiles.profile)
                            if (SysData.fanAvailable && SysData.fan1Rpm > 0)
                                p += " · " + SysData.fan1Rpm + " rpm"
                            return p
                        }
                        font.pixelSize: 9; color: Theme.muted1
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: powerCard.hov = true
                onExited:  powerCard.hov = false
                onClicked: root.openPower()
            }
        }

        // ── Audio ─────────────────────────────────────────────────────────────
        Rectangle {
            id: audioCard
            property bool hov: false
            width: (parent.width - 6) / 2; height: 52; radius: 10
            color: hov ? Theme.surface3
                 : (root.activePanel === "audio"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : Theme.surface2)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                visible: root.activePanel === "audio"
                width: 3; height: 24; radius: 2
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.activePanel === "audio" ? 14 : 10
                    rightMargin: 10
                }
                spacing: 8

                Text { text: "󰕾"; font.pixelSize: 18; color: Theme.accent }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Audio"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        width: parent.width
                        text: {
                            var sink = root.defaultSink
                            if (!sink) return "No output"
                            return root.audioFormatDescFn(sink.description, sink.name ?? "")
                        }
                        font.pixelSize: 9; color: Theme.muted1; elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: audioCard.hov = true
                onExited:  audioCard.hov = false
                onClicked: root.openAudio()
            }
        }

        // ── Battery ───────────────────────────────────────────────────────────
        Rectangle {
            id: batCard
            property bool hov: false
            width: (parent.width - 6) / 2; height: 52; radius: 10
            color: hov ? Theme.surface3
                 : (root.activePanel === "battery"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : Theme.surface2)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                visible: root.activePanel === "battery"
                width: 3; height: 24; radius: 2
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.activePanel === "battery" ? 14 : 10
                    rightMargin: 10
                }
                spacing: 8

                Text {
                    text: {
                        if (!root.batAvailable) return "󰂑"
                        if (root.batFull)        return "󰁹"
                        if (root.batCharging)    return "󰂄"
                        var p = root.batPct
                        if (p > 80) return "󰁹"
                        if (p > 60) return "󰂁"
                        if (p > 40) return "󰁿"
                        if (p > 20) return "󰁽"
                        return "󰂃"
                    }
                    font.pixelSize: 18
                    color: {
                        if (!root.batAvailable)                   return Theme.muted2
                        if (root.batCharging || root.batFull)     return Theme.success
                        if (root.batPct > 50)                     return Theme.accent
                        if (root.batPct > 20)                     return Theme.yellow
                        return Theme.error
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Battery"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        text: {
                            if (!root.batAvailable) return "Not available"
                            var pct = Math.round(root.batPct) + "%"
                            if (root.batFull)     return "Full"
                            if (root.batCharging) {
                                var tf = root.fmtTimeFn(root.batTimeFull)
                                return pct + " · Charging" + (tf ? " · " + tf : "")
                            }
                            var te = root.fmtTimeFn(root.batTimeEmpty)
                            return pct + (te ? " · " + te : "")
                        }
                        font.pixelSize: 9
                        color: root.batPct <= 20 && !root.batCharging ? Theme.error : Theme.muted1
                        elide: Text.ElideRight; width: parent.width
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: batCard.hov = true
                onExited:  batCard.hov = false
                onClicked: root.openBattery()
            }
        }

        // ── Language ──────────────────────────────────────────────────────────
        Rectangle {
            id: langCard
            property bool hov: false
            width: (parent.width - 6) / 2; height: 52; radius: 10
            color: hov ? Theme.surface3
                 : (root.activePanel === "language"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : Theme.surface2)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                visible: root.activePanel === "language"
                width: 3; height: 24; radius: 2
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.activePanel === "language" ? 14 : 10
                    rightMargin: 10
                }
                spacing: 8

                Text { text: "󰌌"; font.pixelSize: 18; color: Theme.accent }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Language"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        text: root.langLayout !== "—" ? root.langLayout + " · " + root.langLocale : "Loading…"
                        font.pixelSize: 9; color: Theme.muted1
                        elide: Text.ElideRight; width: parent.width
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: langCard.hov = true
                onExited:  langCard.hov = false
                onClicked: root.openLanguage()
            }
        }
    }
}

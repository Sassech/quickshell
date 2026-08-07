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
        CcToggleCard {
            active: SysData.netConnected || root.activePanel === "wifi"
            icon: {
                if (SysData.netConnectionType === "ethernet") return "󰈀"
                if (!SysData.netRadioOn)      return "󰤮"
                if (!SysData.netConnected)    return "󰤭"
                if (SysData.netSignal >= 80)  return "󰤨"
                if (SysData.netSignal >= 60)  return "󰤥"
                if (SysData.netSignal >= 40)  return "󰤢"
                return "󰤟"
            }
            iconColor: SysData.netConnected ? Theme.accent : Theme.muted2
            title: "WiFi"
            subtitle: {
                if (SysData.netConnectionType === "ethernet") return "Ethernet"
                if (!SysData.netRadioOn)      return "Radio off"
                if (!SysData.netConnected)    return "Disconnected"
                return (SysData.netSsid || "Connected") + " · " + SysData.netSignal + "%"
            }
            subtitleColor: SysData.netConnected ? Theme.muted1 : Theme.muted2
            onClicked: () => root.openWifi()
        }

        // ── Bluetooth ─────────────────────────────────────────────────────────
        CcToggleCard {
            active: (root.btConnectedCount > 0 && root.btPowered) || root.activePanel === "bluetooth"
            icon: root.btConnectedCount > 0 ? "󰂱"
                : (root.btPowered ? "󰂯" : "󰂲")
            iconColor: root.btConnectedCount > 0 ? Theme.accent
                 : (root.btPowered ? Theme.muted1 : Theme.muted2)
            title: "Bluetooth"
            subtitle: {
                if (!root.btAdapter)               return "Not available"
                if (!root.btPowered)               return "Disabled"
                if (root.btConnectedCount > 0)     return root.btFirstConnectedName
                return "No connections"
            }
            subtitleColor: root.btConnectedCount > 0 ? Theme.muted1 : Theme.muted2
            onClicked: () => root.openBluetooth()
        }

        // ── Power & Fans ──────────────────────────────────────────────────────
        CcToggleCard {
            active: root.activePanel === "power"
            icon: root.powerIconFn(PowerProfiles.profile)
            iconColor: {
                if (PowerProfiles.profile === PowerProfile.Performance) return "#ff7b72"
                if (PowerProfiles.profile === PowerProfile.PowerSaver)  return "#79c0ff"
                return Theme.accent
            }
            title: "Power & Fans"
            subtitle: {
                var p = root.powerLabelFn(PowerProfiles.profile)
                if (SysData.fanAvailable && SysData.fan1Rpm > 0)
                    p += " · " + SysData.fan1Rpm + " rpm"
                return p
            }
            onClicked: () => root.openPower()
        }

        // ── Audio ─────────────────────────────────────────────────────────────
        CcToggleCard {
            active: root.activePanel === "audio"
            icon: "󰕾"
            title: "Audio"
            subtitle: {
                var sink = root.defaultSink
                if (!sink) return "No output"
                return root.audioFormatDescFn(sink.description, sink.name ?? "")
            }
            onClicked: () => root.openAudio()
        }

        // ── Battery ───────────────────────────────────────────────────────────
        CcToggleCard {
            active: root.activePanel === "battery"
            icon: {
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
            iconColor: {
                if (!root.batAvailable)                   return Theme.muted2
                if (root.batCharging || root.batFull)     return Theme.success
                if (root.batPct > 50)                     return Theme.accent
                if (root.batPct > 20)                     return Theme.yellow
                return Theme.error
            }
            title: "Battery"
            subtitle: {
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
            subtitleColor: root.batPct <= 20 && !root.batCharging ? Theme.error : Theme.muted1
            onClicked: () => root.openBattery()
        }

        // ── Language ──────────────────────────────────────────────────────────
        CcToggleCard {
            active: root.activePanel === "language"
            icon: "󰌌"
            title: "Language"
            subtitle: root.langLayout !== "—" ? root.langLayout + " · " + root.langLocale : "Loading…"
            onClicked: () => root.openLanguage()
        }
    }
}

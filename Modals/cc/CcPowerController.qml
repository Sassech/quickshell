// Controlador de power/fans — perfiles de energía + fan profiles + helpers de formato
import QtQuick
import Quickshell.Services.UPower
import "../../Components"

QtObject {
    id: root

    // Estado público
    property var _fanProfiles: []   // [{id, label, icon}] leído de fan-control.sh

    // Proceso de fan profiles
    property var _fanProfilesProc: LineProcess {
        id: fanProfilesProc
        command: ["bash", Paths.scripts + "/fan-control.sh", "list_profiles"]
        onLines: lines => {
            var profiles = []
            for (var i = 0; i < lines.length; i++) {
                var id = lines[i].trim()
                if (id.length === 0) continue
                var icon = "󰈐"
                var label = id.charAt(0).toUpperCase() + id.slice(1)
                if (id === "cool" || id === "turbo_cool") { icon = "󰆏"; label = "Cool" }
                else if (id === "quiet")       { icon = "󰒲"; label = "Quiet" }
                else if (id === "balanced")    { icon = "󱐌"; label = "Balanced" }
                else if (id === "performance") { icon = "󰓅"; label = "Performance" }
                profiles.push({ id: id, label: label, icon: icon })
            }
            if (profiles.length > 0) root._fanProfiles = profiles
        }
    }

    // Funciones de perfil de energía
    function _powerLabel(profile) {
        if (profile === PowerProfile.Performance) return "Performance"
        if (profile === PowerProfile.PowerSaver)  return "Power saver"
        return "Balanced"
    }

    function _powerIcon(profile) {
        if (profile === PowerProfile.Performance) return "󰓅"
        if (profile === PowerProfile.PowerSaver)  return "󰁹"
        return "󱐌"
    }

    function setPower(profile) {
        PowerProfiles.profile = profile
        SysData.refreshCpuDetail()
    }

    // Funciones de formato de tiempo y velocidad
    function _fmtSpeed(bps) {
        if (!bps || bps < 1024)         return Math.round(bps || 0) + " B/s"
        if (bps < 1024 * 1024)          return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024)   return (bps / (1024 * 1024)).toFixed(1) + " MB/s"
        return (bps / (1024 * 1024 * 1024)).toFixed(2) + " GB/s"
    }

    function formatDuration(ms) {
        if (!ms || isNaN(ms)) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        var sec = s % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }
}

pragma Singleton
import QtQuick
import Quickshell.Services.UPower

// ─────────────────────────────────────────────────────────────────────────────
// SysData — Centralized system data provider
// CPU/RAM/GPU/Disk/Net/Fan populated by Python backend via shell.qml.
// Battery populated reactively from UPower (no polling).
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: data

    // ── UPower battery (reactive, replaces backend polling) ────────────────
    property var _upDev: UPower.displayDevice

    // ── CPU ────────────────────────────────────────────────────────────────
    property int cpuPercent: 0
    property int cpuTemp: 0
    property bool cpuAvailable: false

    // ── RAM ────────────────────────────────────────────────────────────────
    property int ramPercent: 0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0
    property real ramAvailGb: 0.0
    property int  swapPercent:  0
    property real ramCacheGb:   0.0
    property real ramAppsGb:    0.0
    property real swapTotalGb:  0.0
    property real swapFreeGb:   0.0
    property bool ramAvailable: false

    // ── GPU ────────────────────────────────────────────────────────────────
    property int gpuPercent: -1
    property int gpuTemp: 0
    property string gpuName: ""
    property bool gpuAvailable: false
    property int gpuVramUsedMb: 0
    property int gpuVramTotalMb: 0

    // ── Disk ───────────────────────────────────────────────────────────────
    property int diskUsedGb: 0
    property int diskAvailGb: 0
    property int diskPercent: 0
    property bool diskAvailable: false

    // ── Network ────────────────────────────────────────────────────────────
    property bool netRadioOn: true
    property bool netConnected: false
    property string netConnectionType: "none"
    property string netSsid: ""
    property int netSignal: 0
    property real netDownSpeed: 0.0
    property real netUpSpeed: 0.0

    // ── Fan ────────────────────────────────────────────────────────────────
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan1Percent: 0
    property int fan2Percent: 0
    property int fanCpuTemp: 0
    property int fanGpuTemp: 0
    property string fanProfile: ""
    property bool fanAvailable: false

    // ── Battery — reactivo via UPower ─────────────────────────────────────
    property int    batPercent:   _upDev ? Math.round(_upDev.percentage * 100) : 0
    property bool   batAvailable: _upDev ? _upDev.isPresent && _upDev.isLaptopBattery : false
    property bool   batCharging:  _upDev ? (_upDev.state === UPowerDeviceState.Charging ||
                                             _upDev.state === UPowerDeviceState.PendingCharge) : false
    property string batStatus: {
        if (!_upDev) return "Unknown"
        var s = _upDev.state
        if (s === UPowerDeviceState.Charging)         return "Charging"
        if (s === UPowerDeviceState.FullyCharged)     return "Full"
        if (s === UPowerDeviceState.Discharging)      return "Discharging"
        if (s === UPowerDeviceState.PendingCharge)    return "Charging"
        if (s === UPowerDeviceState.PendingDischarge) return "Discharging"
        if (s === UPowerDeviceState.Empty)            return "Empty"
        return "Unknown"
    }

    // ── Dispatch — called from shell.qml backend parser ───────────────────
    function dispatch(msg) {
        if (!msg) return
        switch (msg.t) {
        case "cpu":
            data.cpuPercent = msg.u
            data.cpuTemp = msg.tmp
            data.cpuAvailable = true
            break
        case "ram":
            data.ramPercent  = msg.p
            data.ramUsedGb   = msg.ug
            data.ramTotalGb  = msg.tg
            data.ramAvailGb  = msg.ag
            data.swapPercent = msg.sp
            data.ramCacheGb  = msg.cg  || 0.0
            data.ramAppsGb   = msg.xg  || 0.0
            data.swapTotalGb = msg.stg || 0.0
            data.swapFreeGb  = msg.sfg || 0.0
            data.ramAvailable = true
            break
        case "gpu":
            data.gpuPercent = msg.u
            data.gpuTemp = msg.tmp
            data.gpuName = msg.n
            data.gpuAvailable = msg.u >= 0
            data.gpuVramUsedMb  = msg.vu || 0
            data.gpuVramTotalMb = msg.vt || 0
            break
        case "disk":
            data.diskUsedGb = msg.ug
            data.diskAvailGb = msg.ag
            data.diskPercent = msg.p
            data.diskAvailable = true
            break
        case "net":
            data.netRadioOn = msg.r
            data.netConnected = msg.c
            data.netConnectionType = msg.ct
            data.netSsid = msg.s
            data.netSignal = msg.sg
            data.netDownSpeed = msg.ds
            data.netUpSpeed = msg.us
            break
        case "fan":
            data.fan1Rpm = msg.r1
            data.fan2Rpm = msg.r2
            data.fan1Percent = msg.p1
            data.fan2Percent = msg.p2
            data.fanCpuTemp = msg.t1
            data.fanGpuTemp = msg.t2
            data.fanProfile = msg.pr
            data.fanAvailable = msg.a
            break
        }
        // Note: "bat" case removed — battery is now reactive via UPower in SysData directly
    }
}

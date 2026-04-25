pragma Singleton
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
// SysData — Centralized system data provider
// Populated by the Python backend running via shell.qml's backendProcess.
// Widgets read from here instead of spawning individual shell processes.
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: data

    // ── CPU ────────────────────────────────────────────────────────────────
    property int cpuPercent: 0
    property int cpuTemp: 0
    property bool cpuAvailable: false

    // ── RAM ────────────────────────────────────────────────────────────────
    property int ramPercent: 0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0
    property real ramAvailGb: 0.0
    property int swapPercent: 0
    property bool ramAvailable: false

    // ── GPU ────────────────────────────────────────────────────────────────
    property int gpuPercent: -1
    property int gpuTemp: 0
    property string gpuName: ""
    property bool gpuAvailable: false

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

    // ── Battery ───────────────────────────────────────────────────────────
    property int batPercent: 0
    property string batStatus: "Unknown"
    property bool batCharging: false
    property bool batAvailable: false

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
            data.ramPercent = msg.p
            data.ramUsedGb = msg.ug
            data.ramTotalGb = msg.tg
            data.ramAvailGb = msg.ag
            data.swapPercent = msg.sp
            data.ramAvailable = true
            break
        case "gpu":
            data.gpuPercent = msg.u
            data.gpuTemp = msg.tmp
            data.gpuName = msg.n
            data.gpuAvailable = msg.u >= 0
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
        case "bat":
            data.batAvailable = msg.a
            data.batPercent = msg.p
            data.batStatus = msg.s
            data.batCharging = (msg.s === "Charging")
            break
        }
    }
}

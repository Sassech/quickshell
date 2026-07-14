pragma Singleton
import QtQuick
import Quickshell.Io
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

    // ═══════════════════════════════════════════════════════════════════════
    // Phase 1 (backend-migration) — Foundation: discovery cache + detail data
    // Purely additive. The Python backend above still owns cpuPercent/
    // ramPercent/etc via dispatch() until Phase 3 cutover. Nothing below is
    // consumed by any widget yet — pollers land in Phase 2, ControlCenter
    // rewiring lands in Phase 3.
    // ═══════════════════════════════════════════════════════════════════════

    // ── Discovery cache (set once at startup by shell.qml) ─────────────────
    property string _hwmonSmm:      ""   // dell_smm path
    property string _hwmonAwcc:     ""   // awcc/alienware_wmi path
    property string _hwmonCpu:      ""   // coretemp or k10temp path
    property string _hwmonNvme:     ""   // nvme hwmon path
    property string _gpuCardPath:   ""   // /sys/class/drm/cardX/ path
    property string _rootDevice:    ""   // e.g. "nvme0n1"
    property string _netIface:      ""   // default network interface
    property var    _coreTempPaths: []   // list of temp*_input paths for per-core temps
    property bool   pollersReady:   false

    // ── Extended CPU detail (previously from cpu-detail.sh local vars) ──────
    property string cpuModel:       ""
    property int    cpuNcores:      0
    property var    cpuCorePcts:    []
    property real   cpuAvgFreqMhz:  0
    property int    cpuMaxFreqMhz:  0
    property string cpuGovernor:    ""
    property string cpuEpp:         ""
    property var    cpuCoreTemps:   []

    // ── Extended disk detail (previously from disk-detail.sh local vars) ───
    property string diskNvmeModel:  ""
    property string diskNvmeFw:     ""
    property int    diskNvmeTemp:   0
    property real   diskReadMbs:    0.0
    property real   diskWriteMbs:   0.0
    property int    homeUsedGb:     0
    property int    homeAvailGb:    0
    property int    homePercent:    0

    // ── Delta state (used by Phase 2 pollers) ───────────────────────────────
    property var    _prevCpuStat:   null
    property var    _prevCoreStat:  []
    property real   _prevRxBytes:   -1
    property real   _prevTxBytes:   -1
    property var    _diskSectors1:  null

    // ── Discovery parsers (called from shell.qml startup chain) ────────────
    function parseHwmonDiscovery(text) {
        const lines = text.trim().split('\n')
        for (const line of lines) {
            if (!line) continue
            const idx = line.indexOf(':')
            if (idx === -1) continue
            const name = line.substring(0, idx).trim()
            const path = line.substring(idx + 1).trim()
            switch (name) {
            case "dell_smm":      data._hwmonSmm  = path; break
            case "awcc":
            case "alienware_wmi": data._hwmonAwcc = path; break
            case "coretemp":
            case "k10temp":       data._hwmonCpu  = path; break
            case "nvme":          data._hwmonNvme = path; break
            }
        }
    }

    function parseCoreTempDiscovery(text) {
        const lines = text.trim().split('\n')
        const paths = []
        for (const line of lines) {
            if (!line) continue
            const idx = line.indexOf(':')
            if (idx === -1) continue
            const label = line.substring(0, idx).trim()
            const path  = line.substring(idx + 1).trim()
            if (/^Core/.test(label) || /^Tccd/.test(label)) paths.push(path)
        }
        data._coreTempPaths = paths
    }

    function parseCpuInfo(text) {
        const lines = text.trim().split('\n')
        data.cpuModel  = (lines[0] || "").trim()
        data.cpuNcores = parseInt(lines[1]) || 0
    }

    // ── CPU delta helpers (consumed by Phase 2 pollers) ─────────────────────
    function parseCpuStatLine(parts) {
        // parts: array of strings from splitting a /proc/stat cpu line
        // returns {total, work}
        const user    = parseInt(parts[1]) || 0
        const nice    = parseInt(parts[2]) || 0
        const system  = parseInt(parts[3]) || 0
        const idle    = parseInt(parts[4]) || 0
        const iowait  = parseInt(parts[5]) || 0
        const irq     = parseInt(parts[6]) || 0
        const softirq = parseInt(parts[7]) || 0
        const steal   = parseInt(parts[8]) || 0
        const total   = user + nice + system + idle + iowait + irq + softirq + steal
        const work    = total - idle - iowait
        return { total, work }
    }

    function cpuDelta(prev, curr) {
        // returns usage % [0-100]
        if (!prev) return 0
        const dt = curr.total - prev.total
        const dw = curr.work  - prev.work
        if (dt <= 0) return 0
        return Math.max(0, Math.min(100, Math.round(dw / dt * 100)))
    }

    function parseDiskstats(text, device) {
        // returns {read: sectors, write: sectors} or null
        const lines = text.split('\n')
        for (const line of lines) {
            const parts = line.trim().split(/\s+/)
            if (parts.length >= 10 && parts[2] === device) {
                return { read: parseInt(parts[5]) || 0, write: parseInt(parts[9]) || 0 }
            }
        }
        return null
    }

    // ── Children (QtObject has no default property — must declare explicitly,
    //    matching the established WeatherProvider.qml convention) ───────────

    // cpuMaxFreqMhz / cpuGovernor / cpuEpp — static sysfs, cpu0 only.
    // Reloaded once discovery completes; refreshed again on panel open (Phase 3).
    property FileView _cpuMaxFreqFile: FileView {
        id: cpuMaxFreqFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
        onLoaded: data.cpuMaxFreqMhz = Math.round((parseInt(text().trim()) || 0) / 1000)
    }

    property FileView _cpuGovFile: FileView {
        id: cpuGovFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        onLoaded: data.cpuGovernor = text().trim()
    }

    property FileView _cpuEppFile: FileView {
        id: cpuEppFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
        onLoaded: data.cpuEpp = text().trim()
    }

    // Per-core temps — one Process refresh (not one fork per core).
    property Process _coreTempProc: Process {
        id: coreTempProc
        command: {
            if (!data._coreTempPaths || data._coreTempPaths.length === 0) return []
            const files = data._coreTempPaths.join(" ")
            return ["sh", "-c", "for f in " + files + "; do cat \"$f\" 2>/dev/null || echo 0; done"]
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n')
                data.cpuCoreTemps = lines.map(l => Math.round((parseInt(l.trim()) || 0) / 1000))
            }
        }
    }

    property Timer _coreTempTimer: Timer {
        id: coreTempTimer
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: data.pollersReady && data._coreTempPaths.length > 0
        onTriggered: coreTempProc.running = true
    }

    // NVMe detail.
    property FileView _nvmeModelFile: FileView {
        id: nvmeModelFile
        path: "/sys/class/nvme/nvme0/model"
        onLoaded: {
            const m = text().trim()
            data.diskNvmeModel = m.length > 0 ? m : "NVMe SSD"
        }
        onLoadFailed: data.diskNvmeModel = "NVMe SSD"
    }

    property FileView _nvmeFwFile: FileView {
        id: nvmeFwFile
        path: "/sys/class/nvme/nvme0/firmware_rev"
        onLoaded: {
            const fw = text().trim().replace(/\s+/g, "")
            data.diskNvmeFw = fw.length > 0 ? fw : "N/A"
        }
        onLoadFailed: data.diskNvmeFw = "N/A"
    }

    property FileView _nvmeTempFile: FileView {
        id: nvmeTempFile
        // Gated on discovery: empty path until _hwmonNvme is resolved.
        path: data._hwmonNvme ? (data._hwmonNvme + "temp1_input") : ""
        onLoaded: data.diskNvmeTemp = Math.round((parseInt(text().trim()) || 0) / 1000)
    }

    onPollersReadyChanged: {
        if (pollersReady) {
            cpuMaxFreqFile.reload()
            cpuGovFile.reload()
            cpuEppFile.reload()
            nvmeModelFile.reload()
            nvmeFwFile.reload()
        }
    }

    // Disk I/O two-shot sampler.
    property FileView _diskStatsFile1: FileView {
        id: diskStatsFile1
        path: "/proc/diskstats"
        preload: false
        onLoaded: {
            if (!data._rootDevice) return
            data._diskSectors1 = data.parseDiskstats(text(), data._rootDevice)
            if (data._diskSectors1) diskIoSampler.start()
        }
    }

    property Timer _diskIoSampler: Timer {
        id: diskIoSampler
        interval: 400
        repeat: false
        onTriggered: diskStatsFile2.reload()
    }

    property FileView _diskStatsFile2: FileView {
        id: diskStatsFile2
        path: "/proc/diskstats"
        preload: false
        onLoaded: {
            if (!data._rootDevice || !data._diskSectors1) return
            const s2 = data.parseDiskstats(text(), data._rootDevice)
            if (s2) {
                const dr = (s2.read  - data._diskSectors1.read)  * 512 / 1048576 / 0.4
                const dw = (s2.write - data._diskSectors1.write) * 512 / 1048576 / 0.4
                data.diskReadMbs  = Math.max(0, parseFloat(dr.toFixed(1)))
                data.diskWriteMbs = Math.max(0, parseFloat(dw.toFixed(1)))
            }
            data._diskSectors1 = null
        }
    }

    // Public trigger — called from ControlCenter on disk panel open (Phase 3)
    function triggerDiskIoSample() {
        if (data._rootDevice && !diskIoSampler.running) {
            diskStatsFile1.reload()
        }
    }
}

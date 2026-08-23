pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower

// ─────────────────────────────────────────────────────────────────────────────
// SysData — Centralized system data provider.
// CPU/RAM/GPU/Disk/Net/Fan via native QML pollers; Battery reactivo via UPower.
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: data

    // ── UPower battery (reactive) ─────────────────────────────────────────
    readonly property var _upDev: UPower.displayDevice

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
    // Radio / connection state — reactive via Quickshell.Networking
    readonly property var _wifiDev: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        return null
    }
    readonly property var _wifiConnectedNet: {
        if (!_wifiDev) return null
        var nets = _wifiDev.networks.values
        for (var i = 0; i < nets.length; i++)
            if (nets[i].connected) return nets[i]
        return null
    }
    readonly property var _ethDev: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wired) return devs[i]
        return null
    }

    readonly property bool   netRadioOn:        Networking.wifiEnabled
    readonly property bool   netConnected:       (_ethDev && _ethDev.connected) || (_wifiDev && _wifiDev.connected) || false
    readonly property string netConnectionType:  {
        if (_ethDev && _ethDev.connected) return "ethernet"
        if (_wifiDev && _wifiDev.connected) return "wifi"
        return "none"
    }
    readonly property string netSsid:   _wifiConnectedNet ? _wifiConnectedNet.name : ""
    readonly property int    netSignal: _wifiConnectedNet ? Math.round(_wifiConnectedNet.signalStrength * 100) : 0
    // Speed — still from /proc/net/dev (Networking API has no byte counters)
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

    // ── Discovery cache (set once at startup by shell.qml) ─────────────────
    property string _hwmonSmm:      ""   // dell_smm path
    property string _hwmonAwcc:     ""   // awcc/alienware_wmi path
    property string _hwmonCpu:      ""   // coretemp or k10temp path
    property string _hwmonNvme:     ""   // nvme hwmon path
    property string _gpuCardPath:   ""   // /sys/class/drm/cardX/ path
    property string _rootDevice:    ""   // e.g. "nvme0n1"
    property string _netIface:      ""   // default network interface
    property list<string> _coreTempPaths: []   // list of temp*_input paths for per-core temps
    property var    _cpuFreqPaths:  []   // list of scaling_cur_freq paths (one per core)
    property bool   pollersReady:   false

    // ── CC visibility gate — set by ControlCenter when it opens/closes ─────
    // Pollers that are only needed while the ControlCenter is visible (fan,
    // GPU) gate on this flag so they stop when the panel is hidden.
    property bool anyCcVisible: false

    // ── Extended CPU detail ─────────────────────────────────────────────────
    property string cpuModel:       ""
    property int    cpuNcores:      0
    property var    cpuCorePcts:    []
    property real   cpuAvgFreqMhz:  0
    property int    cpuMaxFreqMhz:  0
    property string cpuGovernor:    ""
    property string cpuEpp:         ""
    property var    cpuCoreTemps:   []

    // ── Extended disk detail ────────────────────────────────────────────────
    property string diskNvmeModel:  ""
    property string diskNvmeFw:     ""
    property int    diskNvmeTemp:   0
    property real   diskReadMbs:    0.0
    property real   diskWriteMbs:   0.0
    property int    homeUsedGb:     0
    property int    homeAvailGb:    0
    property int    homePercent:    0

    // ── Delta state (consumido por los pollers) ─────────────────────────────
    property var    _prevCpuStat:   null
    property var    _prevCoreStat:  []
    property real   _prevRxBytes:   -1
    property real   _prevTxBytes:   -1
    property var    _prevDiskSectors: null   // previous diskstats sectors for I/O delta

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
        // Reset el array a la misma longitud — los FileView del Instantiator
        // llenan cada índice en su onLoaded (los 0 muestran "—" en el panel).
        data.cpuCoreTemps   = new Array(paths.length).fill(0)
    }

    function parseCpuInfo(text) {
        const lines = text.trim().split('\n')
        data.cpuModel  = (lines[0] || "").trim()
        data.cpuNcores = parseInt(lines[1]) || 0
    }

    // ── CPU delta helpers ───────────────────────────────────────────────────
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

    // Per-core temps — one FileView per path, no shell process per poll.
    // Each delegate watches its sysfs file; reloads are ALSO driven by the 4s
    // _cpuTimer as a safety net because hwmon sysfs files don't reliably emit
    // inotify events (value is computed on read, not pushed by the kernel).
    property Instantiator _coreTempInstantiator: Instantiator {
        id: coreTempInstantiator
        model: data._coreTempPaths
        delegate: FileView {
            required property string modelData
            required property int index
            path: modelData
            watchChanges: true
            onFileChanged: this.reload()
            onLoaded: {
                const v = parseInt(text().trim())
                if (isNaN(v)) return
                const arr = (data.cpuCoreTemps || []).slice()
                arr[index] = Math.round(v / 1000)
                data.cpuCoreTemps = arr
            }
        }
    }

    // Helper: reload all per-core temp FileViews (called by _cpuTimer).
    function _reloadCoreTemps() {
        if (data._coreTempPaths.length === 0) return
        for (let i = 0; i < coreTempInstantiator.count; ++i) {
            const fv = coreTempInstantiator.objectAt(i)
            if (fv) fv.reload()
        }
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

    // Disk I/O sampler — single FileView + periodic reload, delta vs previous
    // read. Same pattern as the RAM poller: /proc/diskstats is monotonic, so
    // the delta over the 2s interval gives MB/s. Quickshell v0.3.0 skips
    // reload() when file content is unchanged, so a two-shot sampler would
    // stall on idle disks — this variant keeps the last known values instead.
    property FileView _diskStatsFile: FileView {
        id: diskStatsFile
        path: "/proc/diskstats"
        preload: false
        onLoaded: {
            if (!data._rootDevice) return
            const s = data.parseDiskstats(text(), data._rootDevice)
            if (!s) return
            if (data._prevDiskSectors) {
                const dr = (s.read  - data._prevDiskSectors.read)  * 512 / 1048576 / 2
                const dw = (s.write - data._prevDiskSectors.write) * 512 / 1048576 / 2
                data.diskReadMbs  = Math.max(0, parseFloat(dr.toFixed(1)))
                data.diskWriteMbs = Math.max(0, parseFloat(dw.toFixed(1)))
            }
            data._prevDiskSectors = s
        }
    }

    // Continuous I/O sampling while CC is visible — single FileView + reload.
    property Timer _diskIoTimer: Timer {
        id: diskIoTimer
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: data.pollersReady && data.anyCcVisible
        onTriggered: diskStatsFile.reload()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Pollers nativos QML — los Timers de abajo gatean en pollersReady
    // (chain de descubrimiento de shell.qml).
    // ═══════════════════════════════════════════════════════════════════════

    // ── 2.1 RAM poller (FileView /proc/meminfo, 4s) ─────────────────────────
    function parseMeminfo(text) {
        const lines = text.split('\n')
        let memTotal = 0, memFree = 0, memAvail = 0
        let buffers = 0, cached = 0, shmem = 0, sReclaimable = 0
        let swapTotal = 0, swapFree = 0
        for (const line of lines) {
            const parts = line.trim().split(/\s+/)
            if (parts.length < 2) continue
            const key = parts[0]
            const val = parseInt(parts[1]) || 0
            if      (key.startsWith("MemTotal:"))     memTotal     = val
            else if (key.startsWith("MemFree:"))      memFree      = val
            else if (key.startsWith("MemAvailable:")) memAvail     = val
            else if (key.startsWith("Buffers:"))      buffers      = val
            else if (key.startsWith("Cached:"))        cached       = val
            else if (key.startsWith("Shmem:"))         shmem        = val
            else if (key.startsWith("SReclaimable:"))  sReclaimable = val
            else if (key.startsWith("SwapTotal:"))     swapTotal    = val
            else if (key.startsWith("SwapFree:"))      swapFree     = val
        }
        if (memTotal <= 0 || memAvail <= 0) return

        const cacheKb = buffers + cached + sReclaimable - shmem
        let   appsKb  = memTotal - memFree - buffers - cached - sReclaimable + shmem
        appsKb = Math.max(0, appsKb)
        const used = memTotal - memAvail
        const GB = 1048576

        data.ramPercent  = Math.round(used * 100 / memTotal)
        data.ramUsedGb   = Math.round(used     / GB * 10) / 10
        data.ramTotalGb  = Math.round(memTotal / GB * 10) / 10
        data.ramAvailGb  = Math.round(memAvail / GB * 10) / 10
        data.ramCacheGb  = Math.round(cacheKb  / GB * 10) / 10
        data.ramAppsGb   = Math.round(appsKb   / GB * 10) / 10
        data.swapPercent = swapTotal > 0 ? Math.round((swapTotal - swapFree) * 100 / swapTotal) : 0
        data.swapTotalGb = Math.round(swapTotal / GB * 10) / 10
        data.swapFreeGb  = Math.round(swapFree  / GB * 10) / 10
        data.ramAvailable = true
    }

    property FileView _memInfoFile: FileView {
        id: memInfoFile
        path: "/proc/meminfo"
        // Carga inicial inmediata — no esperar al timer ni a pollersReady.
        // /proc/meminfo siempre existe; una lectura temprana no hace daño
        // y garantiza que el widget de RAM muestra datos desde el arranque.
        Component.onCompleted: this.reload()
        onLoaded: data.parseMeminfo(text())
    }

    property Timer _ramTimer: Timer {
        id: ramTimer
        interval: 4000
        repeat: true
        running: data.pollersReady
        triggeredOnStart: true
        onTriggered: memInfoFile.reload()
    }

    // ── 2.2 CPU usage poller (FileView /proc/stat, 4s) ──────────────────────
    function parseCpuStat(text) {
        const lines = text.split('\n').filter(l => l.startsWith('cpu'))
        if (lines.length === 0) return

        const pkgParts = lines[0].trim().split(/\s+/)
        const pkgCurr  = data.parseCpuStatLine(pkgParts)
        data.cpuPercent   = data.cpuDelta(data._prevCpuStat, pkgCurr)
        data._prevCpuStat = pkgCurr

        const coreLines    = lines.filter(l => /^cpu\d/.test(l))
        const newCorePcts  = []
        const newPrevCore  = []
        for (let i = 0; i < coreLines.length; i++) {
            const parts = coreLines[i].trim().split(/\s+/)
            const curr  = data.parseCpuStatLine(parts)
            const prev  = data._prevCoreStat[i] || null
            newCorePcts.push(data.cpuDelta(prev, curr))
            newPrevCore.push(curr)
        }
        data.cpuCorePcts   = newCorePcts
        data._prevCoreStat = newPrevCore
        data.cpuAvailable  = true
    }

    property FileView _cpuStatFile: FileView {
        id: cpuStatFile
        path: "/proc/stat"
        onLoaded: data.parseCpuStat(text())
    }

    // CPU package temperature — hwmon coretemp/k10temp temp1_input ÷ 1000.
    property FileView _cpuTempFile: FileView {
        id: cpuTempFile
        path: data._hwmonCpu ? (data._hwmonCpu + "temp1_input") : ""
        onLoaded: data.cpuTemp = Math.round((parseInt(text().trim()) || 0) / 1000)
    }

    // Average scaling_cur_freq across all cores (REQ-02 "MUST average").
    // Strategy: one-shot Process at startup discovers all cpu*/cpufreq/scaling_cur_freq
    // paths and stores them in _cpuFreqPaths; then an Instantiator creates one
    // FileView per path (no shell process per poll tick).
    property Process _cpuFreqDiscoveryProc: Process {
        id: cpuFreqDiscoveryProc
        command: ["sh", "-c",
            "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do [ -f \"$f\" ] && echo \"$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n').filter(l => l.length > 0)
                data._cpuFreqPaths = lines
            }
        }
    }

    // Trigger discovery once pollersReady fires.
    property Connections _cpuFreqDiscoveryTrigger: Connections {
        target: data
        function onPollersReadyChanged() {
            if (data.pollersReady && !cpuFreqDiscoveryProc.running)
                cpuFreqDiscoveryProc.running = true
        }
    }

    // Accumulator — reset each poll cycle before the Instantiator reloads all FileViews.
    property var _cpuFreqRawValues: []

    // One FileView per core path. Each reload() reads the sysfs file with no fork.
    property Instantiator _cpuFreqInstantiator: Instantiator {
        id: cpuFreqInstantiator
        model: data._cpuFreqPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            onLoaded: {
                const khz = parseInt(text().trim()) || 0
                const acc = data._cpuFreqRawValues
                if (!Array.isArray(acc)) return   // guard: skip if array not yet ready
                if (khz > 0) acc.push(khz)
                // Last file loaded → compute average
                if (acc.length === data._cpuFreqPaths.length) {
                    const sum = acc.reduce((a, b) => a + b, 0)
                    data.cpuAvgFreqMhz = Math.round((sum / acc.length) / 1000)
                    acc.splice(0)   // vaciar sin reasignar — evita undefined en delegates concurrentes
                }
            }
        }
    }

    // Helper: trigger a full freq refresh (reloads all per-core FileViews).
    function _reloadCpuFreqs() {
        if (data._cpuFreqPaths.length === 0) return
        data._cpuFreqRawValues.splice(0)   // vaciar sin reasignar
        for (let i = 0; i < cpuFreqInstantiator.count; ++i) {
            const fv = cpuFreqInstantiator.objectAt(i)
            if (fv) fv.reload()
        }
    }

    property Timer _cpuTimer: Timer {
        id: cpuTimer
        interval: 4000
        repeat: true
        running: data.pollersReady
        triggeredOnStart: true
        onTriggered: {
            cpuStatFile.reload()
            cpuTempFile.reload()
            data._reloadCpuFreqs()
            data._reloadCoreTemps()
        }
    }

    // Public trigger — refresco inmediato de todos los detalles de CPU
    // (usado por el panel CPU del ControlCenter).
    function refreshCpuDetail() {
        cpuStatFile.reload()
        cpuTempFile.reload()
        data._reloadCpuFreqs()
        data._reloadCoreTemps()
        cpuGovFile.reload()
        cpuEppFile.reload()
        cpuMaxFreqFile.reload()
    }

    // ── 2.3 Fan poller (FileView hwmon sysfs, 5s) ────────────────────────────
    property int _fanMax1: 3700
    property int _fanMax2: 4000

    property Timer _fanTimer: Timer {
        id: fanTimer
        interval: 5000
        repeat: true
        running: data.pollersReady && data.anyCcVisible
        triggeredOnStart: true
        onTriggered: {
            if (data._hwmonSmm) {
                fanRpm1File.reload()
                fanRpm2File.reload()
                fanMax1File.reload()
                fanMax2File.reload()
            }
            if (data._hwmonAwcc) {
                awccTemp1File.reload()
                awccTemp2File.reload()
            }
            platformProfileFile.reload()
        }
    }

    property FileView _fanRpm1File: FileView {
        id: fanRpm1File
        path: data._hwmonSmm ? (data._hwmonSmm + "fan1_input") : ""
        onLoaded: {
            const r = parseInt(text().trim()) || 0
            data.fan1Rpm = r
            data.fan1Percent = (r > 0 && data._fanMax1 > 0) ? Math.round(r * 100 / data._fanMax1) : 0
            data.fanAvailable = (data.fan1Rpm > 0 || data.fan2Rpm > 0)
        }
    }

    property FileView _fanRpm2File: FileView {
        id: fanRpm2File
        path: data._hwmonSmm ? (data._hwmonSmm + "fan2_input") : ""
        onLoaded: {
            const r = parseInt(text().trim()) || 0
            data.fan2Rpm = r
            data.fan2Percent = (r > 0 && data._fanMax2 > 0) ? Math.round(r * 100 / data._fanMax2) : 0
            data.fanAvailable = (data.fan1Rpm > 0 || data.fan2Rpm > 0)
        }
    }

    property FileView _fanMax1File: FileView {
        id: fanMax1File
        path: data._hwmonSmm ? (data._hwmonSmm + "fan1_max") : ""
        onLoaded: {
            const m = parseInt(text().trim()) || 0
            if (m > 0) data._fanMax1 = m
        }
    }

    property FileView _fanMax2File: FileView {
        id: fanMax2File
        path: data._hwmonSmm ? (data._hwmonSmm + "fan2_max") : ""
        onLoaded: {
            const m = parseInt(text().trim()) || 0
            if (m > 0) data._fanMax2 = m
        }
    }

    property FileView _awccTemp1File: FileView {
        id: awccTemp1File
        path: data._hwmonAwcc ? (data._hwmonAwcc + "temp1_input") : ""
        onLoaded: data.fanCpuTemp = Math.round((parseInt(text().trim()) || 0) / 1000)
    }

    property FileView _awccTemp2File: FileView {
        id: awccTemp2File
        path: data._hwmonAwcc ? (data._hwmonAwcc + "temp2_input") : ""
        onLoaded: data.fanGpuTemp = Math.round((parseInt(text().trim()) || 0) / 1000)
    }

    property FileView _platformProfileFile: FileView {
        id: platformProfileFile
        path: "/sys/class/platform-profile/platform-profile-0/profile"
        onLoaded: data.fanProfile = text().trim()
    }

    // ── 2.4 Network speed + state poller (FileView /proc/net/dev, 3s) ───────
    function parseNetDev(text) {
        if (!data._netIface) return
        const lines = text.split('\n')
        for (const line of lines) {
            if (line.trim().startsWith(data._netIface + ":")) {
                const parts = line.trim().split(/\s+/)
                // parts[0] = "iface:", parts[1] = rx_bytes, parts[9] = tx_bytes
                if (parts.length >= 10) {
                    const rx = parseFloat(parts[1]) || 0
                    const tx = parseFloat(parts[9]) || 0
                    if (data._prevRxBytes >= 0) {
                        data.netDownSpeed = Math.max(0, Math.round((rx - data._prevRxBytes) * 10) / 10)
                        data.netUpSpeed   = Math.max(0, Math.round((tx - data._prevTxBytes) * 10) / 10)
                    }
                    data._prevRxBytes = rx
                    data._prevTxBytes = tx
                }
                break
            }
        }
    }

    property FileView _netDevFile: FileView {
        id: netDevFile
        path: "/proc/net/dev"
        onLoaded: data.parseNetDev(text())
    }

    property Timer _netTimer: Timer {
        id: netTimer
        interval: 3000
        repeat: true
        running: data.pollersReady
        triggeredOnStart: false // first poll only seeds _prevRxBytes, no delta yet
        onTriggered: netDevFile.reload()
    }

    // ── 2.5 GPU poller (Process nvidia-smi, 4s, sysfs fallback) ─────────────
    function parseNvidiaSmi(text) {
        const out = text.trim()
        if (!out || out.toLowerCase().indexOf("failed") !== -1) {
            data.fetchGpuSysfs()
            return
        }
        const parts = out.split(", ")
        if (parts.length < 2) {
            data.fetchGpuSysfs()
            return
        }
        const pctRaw = parseInt(parts[0].trim())
        const pct    = isNaN(pctRaw) ? -1 : pctRaw
        const tmp    = parseInt(parts[1].trim()) || 0
        let   name   = parts.length > 2 ? parts[2].trim() : "NVIDIA"
        name = name.replace("NVIDIA GeForce ", "").replace("GeForce ", "")
        const vramUsed  = parts.length > 3 ? (parseInt(parts[3].trim()) || 0) : 0
        const vramTotal = parts.length > 4 ? (parseInt(parts[4].trim()) || 0) : 0

        data.gpuPercent     = pct
        data.gpuTemp        = tmp
        data.gpuName        = name
        data.gpuVramUsedMb  = vramUsed
        data.gpuVramTotalMb = vramTotal
        data.gpuAvailable   = pct >= 0
    }

    function fetchGpuSysfs() {
        if (!data._gpuCardPath) {
            data.gpuPercent = -1
            data.gpuAvailable = false
            return
        }
        if (!gpuSysfsProc.running) gpuSysfsProc.running = true
    }

    function parseGpuSysfs(text) {
        const lines = text.split('\n')
        const vendor        = (lines[0] || "").trim()
        const busy          = (lines[1] || "").trim()
        const vramUsedRaw   = (lines[2] || "").trim()
        const vramTotalRaw  = (lines[3] || "").trim()

        let name = "GPU"
        if      (vendor.indexOf("10de") !== -1) name = "NVIDIA"
        else if (vendor.indexOf("8086") !== -1) name = "Intel"
        else if (vendor.indexOf("1002") !== -1) name = "AMD"

        let pct = -1
        if (busy) {
            const digits = busy.replace(/[^0-9]/g, "")
            if (digits) pct = parseInt(digits)
        }

        const vramUsed  = vramUsedRaw  ? Math.round(parseInt(vramUsedRaw)  / 1048576) : 0
        const vramTotal = vramTotalRaw ? Math.round(parseInt(vramTotalRaw) / 1048576) : 0

        data.gpuPercent     = pct
        data.gpuTemp        = 0
        data.gpuName        = name
        data.gpuVramUsedMb  = vramUsed
        data.gpuVramTotalMb = vramTotal
        data.gpuAvailable   = pct >= 0
    }

    property Process _nvidiaSmiProc: Process {
        id: nvidiaSmiProc
        running: data.pollersReady && data.anyCcVisible   // paused when CC is not visible
        command: ["nvidia-smi", "--loop=4",
                  "--query-gpu=utilization.gpu,temperature.gpu,name,memory.used,memory.total",
                  "--format=csv,noheader,nounits"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const t = line.trim()
                if (t.length > 0) data.parseNvidiaSmi(t)
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // nvidia-smi --loop only exits if there is no GPU or an error occurs
            if (exitCode !== 0) data.fetchGpuSysfs()
        }
        // qmllint enable signal-handler-parameters
    }

    // Sysfs fallback — only exercised when nvidia-smi is absent/fails.
    // Vendor/busy%/VRAM only (no freq-based % fallback): design.md marks the
    // full AMD/Intel sysfs path as dead code on this NVIDIA-only Alienware hw.
    property Process _gpuSysfsProc: Process {
        id: gpuSysfsProc
        command: {
            const c = data._gpuCardPath
            if (!c) return []
            return ["sh", "-c",
                "cat " + c + "device/vendor 2>/dev/null; echo; " +
                "cat " + c + "device/gpu_busy_percent 2>/dev/null; echo; " +
                "cat " + c + "device/mem_info_vram_used 2>/dev/null; echo; " +
                "cat " + c + "device/mem_info_vram_total 2>/dev/null; echo"]
        }
        stdout: StdioCollector {
            onStreamFinished: data.parseGpuSysfs(text)
        }
    }

    // ── 2.6 Disk usage poller (Process df, 30s) ─────────────────────────────
    function parseDf(text) {
        const lines = text.trim().split('\n')
        if (lines.length < 2) return

        function parseRow(line) {
            const parts = line.trim().split(/\s+/)
            if (parts.length < 4) return null
            return {
                used:  parseInt(parts[1].replace('G', '')) || 0,
                avail: parseInt(parts[2].replace('G', '')) || 0,
                pct:   parseInt(parts[3].replace('%', '')) || 0,
            }
        }

        const rootRow = parseRow(lines[1])
        if (rootRow) {
            data.diskUsedGb  = rootRow.used
            data.diskAvailGb = rootRow.avail
            data.diskPercent = rootRow.pct
        }

        // If /home is not a separate mount, df repeats the "/" row here —
        // homePercent equals diskPercent in that case (acceptable, REQ-06).
        if (lines.length >= 3) {
            const homeRow = parseRow(lines[2])
            if (homeRow) {
                data.homeUsedGb  = homeRow.used
                data.homeAvailGb = homeRow.avail
                data.homePercent = homeRow.pct
            }
        }
        data.diskAvailable = true
    }

    property Process _dfProc: Process {
        id: dfProc
        command: ["df", "-BG", "--output=size,used,avail,pcent", "/", "/home"]
        stdout: StdioCollector {
            onStreamFinished: data.parseDf(text)
        }
    }

    property Timer _diskTimer: Timer {
        id: diskTimer
        interval: 30000
        repeat: true
        running: data.pollersReady
        triggeredOnStart: true
        onTriggered: {
            if (!dfProc.running) dfProc.running = true
        }
    }
}

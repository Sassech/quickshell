// Controlador de GPU — parser multi-vendor + timer de polling
import QtQuick
import "../../Components"

QtObject {
    id: root

    // ── Prop requerida: activo cuando el panel GPU está visible ──────────
    required property bool active

    // ── Estado público ────────────────────────────────────────────────────
    property bool _gpuLoaded: false
    property var  _gpus:      []   // [{vendor,name,util,temp,...}]

    // ── Proceso de detalle GPU — multi-vendor ─────────────────────────────
    property var _gpuDetailProc: LineProcess {
        id: gpuDetailProc
        command: ["bash", Paths.scripts + "/gpu-detail.sh"]
        onLines: lines => {
            var kv = {}
            lines.forEach(function(line) {
                var idx = line.indexOf(":")
                if (idx > 0) kv[line.substring(0, idx)] = line.substring(idx + 1)
            })

            var count = parseInt(kv["GPU_COUNT"]) || 0
            var list = []
            for (var i = 1; i <= count; i++) {
                var p = "GPU" + i + "_"
                var vendor = (kv[p + "VENDOR"] || "").toLowerCase()
                // Para Intel: freq activa puede ser 0 (idle) → usar cur como fallback
                var freqAct = parseInt(kv[p + "FREQ"]) || 0
                var freqCur = parseInt(kv[p + "FREQ_CUR"]) || 0
                var obj = {
                    vendor:      vendor,
                    name:        kv[p + "NAME"]   || "",
                    status:      kv[p + "STATUS"] || "active",
                    util:        parseInt(kv[p + "UTIL"])        || 0,
                    temp:        parseInt(kv[p + "TEMP"])        || parseInt(kv[p + "TEMP_EDGE"]) || 0,
                    tempJun:     parseInt(kv[p + "TEMP_JUN"])    || 0,
                    freq:        freqAct > 0 ? freqAct : freqCur,
                    freqMem:     parseInt(kv[p + "FREQ_MEM"])    || 0,
                    freqMax:     parseInt(kv[p + "FREQ_MAX"])    || 0,
                    freqMin:     parseInt(kv[p + "FREQ_MIN"])    || 0,
                    power:       parseFloat(kv[p + "POWER"])     || 0,
                    powerLimit:  parseFloat(kv[p + "POWER_LIMIT"]) || 0,
                    vramUsed:    parseInt(kv[p + "VRAM_USED"])   || 0,
                    vramTotal:   parseInt(kv[p + "VRAM_TOTAL"])  || 0,
                    driver:      kv[p + "DRIVER"]       || "",
                    rc6:         parseInt(kv[p + "RC6"]) || 0,
                    throttle:    parseInt(kv[p + "THROTTLE"]) || 0,
                    powerState:  kv[p + "POWER_STATE"]  || ""
                }
                list.push(obj)
            }
            root._gpus = list
            root._gpuLoaded = true
        }
    }

    // ── Timer de polling mientras el panel GPU está abierto ───────────────
    property var _gpuTimer: Timer {
        interval: 1500; repeat: true
        running: root.active
        onTriggered: gpuDetailProc.running = true
        onRunningChanged: { if (running) gpuDetailProc.running = true }
    }
}

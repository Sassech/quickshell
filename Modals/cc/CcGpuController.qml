// Controlador de GPU — parser multi-vendor + proceso persistente NVIDIA
import QtQuick
import Quickshell.Io
import "../../Components"

QtObject {
    id: root

    // Prop requerida: activo cuando el panel GPU está visible
    required property bool active

    // Estado público
    property bool _gpuLoaded: false
    property var  _gpus:      []   // [{vendor,name,util,temp,...}]

    // Helper: parsea el mapa KV del script multi-vendor
    function _parseKV(kv) {
        var count = parseInt(kv["GPU_COUNT"]) || 0
        var list = []
        for (var i = 1; i <= count; i++) {
            var p = "GPU" + i + "_"
            var vendor = (kv[p + "VENDOR"] || "").toLowerCase()
            var freqAct = parseInt(kv[p + "FREQ"]) || 0
            var freqCur = parseInt(kv[p + "FREQ_CUR"]) || 0
            list.push({
                vendor:      vendor,
                name:        kv[p + "NAME"]   || "",
                status:      kv[p + "STATUS"] || "active",
                util:        parseInt(kv[p + "UTIL"])          || 0,
                temp:        parseInt(kv[p + "TEMP"])          || parseInt(kv[p + "TEMP_EDGE"]) || 0,
                tempJun:     parseInt(kv[p + "TEMP_JUN"])      || 0,
                freq:        freqAct > 0 ? freqAct : freqCur,
                freqMem:     parseInt(kv[p + "FREQ_MEM"])      || 0,
                freqMax:     parseInt(kv[p + "FREQ_MAX"])      || 0,
                freqMin:     parseInt(kv[p + "FREQ_MIN"])      || 0,
                power:       parseFloat(kv[p + "POWER"])       || 0,
                powerLimit:  parseFloat(kv[p + "POWER_LIMIT"]) || 0,
                vramUsed:    parseInt(kv[p + "VRAM_USED"])     || 0,
                vramTotal:   parseInt(kv[p + "VRAM_TOTAL"])    || 0,
                driver:      kv[p + "DRIVER"]       || "",
                rc6:         parseInt(kv[p + "RC6"]) || 0,
                throttle:    parseInt(kv[p + "THROTTLE"]) || 0,
                powerState:  kv[p + "POWER_STATE"]  || ""
            })
        }
        return list
    }

    // Proceso persistente NVIDIA — nvidia-smi --loop=3
    // Corre solo cuando el panel está activo; --loop=3 elimina el overhead de
    // fork (~100ms/arranque) comparado con relanzar el proceso cada 1.5s.
    property Process _gpuDetailProc: Process {
        id: gpuDetailProc
        running: root.active
        command: [
            "nvidia-smi", "--loop=3",
            "--query-gpu=name,utilization.gpu,temperature.gpu,power.draw,power.limit,memory.used,memory.total,clocks.current.graphics,clocks.current.memory,driver_version",
            "--format=csv,noheader,nounits"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const t = line.trim()
                if (!t || t.length === 0) return
                root._parseGpuLine(t)
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.active) {
                // nvidia-smi no disponible — activar fallback multi-vendor
                fallbackProc.running = true
            }
        }
        // qmllint enable signal-handler-parameters
    }

    // Parser de línea CSV de nvidia-smi
    function _parseGpuLine(line) {
        var parts = line.split(", ")
        if (parts.length < 10) return
        var obj = {
            vendor:     "nvidia",
            name:       (parts[0] || "").trim(),
            status:     "active",
            util:       parseInt(parts[1]) || 0,
            temp:       parseInt(parts[2]) || 0,
            tempJun:    0,
            power:      parseFloat(parts[3]) || 0,
            powerLimit: parseFloat(parts[4]) || 0,
            vramUsed:   parseInt(parts[5]) || 0,
            vramTotal:  parseInt(parts[6]) || 0,
            freq:       parseInt(parts[7]) || 0,
            freqMem:    parseInt(parts[8]) || 0,
            freqMax:    0,
            freqMin:    0,
            driver:     (parts[9] || "").trim(),
            rc6:        0,
            throttle:   0,
            powerState: ""
        }
        root._gpus = [obj]
        root._gpuLoaded = true
    }

    // Fallback multi-vendor (Intel/AMD/NVIDIA sin --loop)
    // Solo se activa si nvidia-smi falla (AMD, Intel, o NVIDIA sin driver).
    // Timer a 3s (vs 1.5s original) — sysfs reads son baratos, sin fork overhead.
    property LineProcess _fallbackProc: LineProcess {
        id: fallbackProc
        running: false
        command: ["bash", Paths.scripts + "/gpu-detail.sh"]
        onLines: lines => {
            var kv = {}
            lines.forEach(function(line) {
                var idx = line.indexOf(":")
                if (idx > 0) kv[line.substring(0, idx)] = line.substring(idx + 1)
            })
            var list = root._parseKV(kv)
            if (list.length > 0) {
                root._gpus = list
                root._gpuLoaded = true
            }
        }
    }

    property Timer _fallbackTimer: Timer {
        interval: 3000; repeat: true
        running: fallbackProc.running && root.active
        onTriggered: fallbackProc.running = true
        onRunningChanged: { if (running) fallbackProc.running = true }
    }
}

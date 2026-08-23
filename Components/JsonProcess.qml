pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// ── JsonProcess — Process con stdout JSON parseado ─────────────────────────────
// Captura stdout línea a línea en un buffer; en onExited hace trim + JSON.parse
// y emite parsed(data). SIEMPRE limpia el buffer (incluso si el parse falla,
// catch silencioso, igual que los bloques originales de ControlCenter) y emite
// finished() al final — permite a los consumidores correr lógica post-exit
// incondicional (p.ej. re-encolar la siguiente query) aunque el parse falle.
// `parsed` usa `var` a propósito: JSON.parse no tiene tipo estático y los
// consumidores difieren — pactl --format=json produce ARRAYs (CcAudioController:
// _audioSinkAvailProc/_audioSourceAvailProc/_audioCardsProc recorren data.length)
// mientras el codec de CcBluetoothController espera un OBJETO. No existe un
// tipo único determinable sin romper alguno de los dos.
Process {
    id: root
    property string buffer: ""
    signal parsed(var data)
    signal finished()
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: d => root.buffer += d + "\n"
    }
    // qmllint disable signal-handler-parameters
    onExited: {
        const s = root.buffer.trim()
        root.buffer = ""
        try {
            root.parsed(JSON.parse(s))
        } catch (e) {}
        root.finished()
    }
    // qmllint enable signal-handler-parameters
}

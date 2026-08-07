pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// ── LineProcess — Process con stdout línea a línea ─────────────────────────────
// Captura stdout en un buffer; en onExited limpia el buffer y emite lines(arr)
// con el split("\n") del contenido capturado. El handler decide la transformación.
Process {
    id: root
    property string buffer: ""
    signal lines(var arr)
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: d => root.buffer += d + "\n"
    }
    onExited: {
        const s = root.buffer.trim()
        root.buffer = ""
        root.lines(s.length ? s.split("\n") : [])
    }
}

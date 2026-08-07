import QtQuick
import Quickshell.Io

// FifoChannel — lector de FIFO reutilizable.
// Crea el FIFO con bash (si `command` no se da) o ejecuta un comando custom,
// y emite cada línea leída como señal `line`. Se reconecta solo si el proceso
// muere y se apaga automáticamente al destruirse el componente.
Item {
    id: root

    property string path: ""              // ruta del FIFO (solo si no se da command)
    property var command                  // comando custom (ej. script que crea su propio FIFO)

    signal line(string text)              // se emite por cada línea leída

    Process {
        id: fifoProc
        running: true
        command: root.command !== undefined ? root.command : root.mkFifoCmd(root.path)
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: text => root.line(text)
        }
        onRunningChanged: if (!running) running = true
    }

    Component.onDestruction: fifoProc.running = false

    // Genera un comando bash que recrea el FIFO y lee líneas.
    // (Movido desde shell.qml — el shell ya no lo necesita.)
    function mkFifoCmd(fifoPath) {
        const rawPath = String(fifoPath ?? "")
        const safePath = rawPath.replace(/'/g, "'\"'\"'")
        return [
            "bash", "-c",
            "rm -f '" + safePath + "'; mkfifo '" + safePath + "'; " +
            "exec 3<>'" + safePath + "'; " +
            "while IFS= read -r line <&3; do printf '%s\\n' \"$line\"; done"
        ]
    }
}

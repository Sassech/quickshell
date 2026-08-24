// Controlador de brillo — lectura desde sysfs (FileView reactivo) + escritura via brightnessctl
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int  brightness:       50
    property bool _brightnessReady: false

    // Path sysfs (detectado por backlightPathProc)
    property string _backlightPath: ""
    property int    _maxBrightness: 100

    // Detectar path del backlight Lazy: no corre al nacer — ControlCenter.refresh() lo dispara en la primera
    // apertura del CC (el path se cachea en _backlightPath).
    property var _backlightPathProc: Process {
        id: backlightPathProc
        running: false
        command: ["bash", "-c", "ls /sys/class/backlight/ 2>/dev/null | head -1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                var v = d.trim()
                if (v) {
                    root._backlightPath = "/sys/class/backlight/" + v
                    maxBrightnessFile.reload()
                }
            }
        }
    }

    // Leer max_brightness (one-shot)
    property var _maxBrightnessFile: FileView {
        id: maxBrightnessFile
        path: root._backlightPath !== "" ? root._backlightPath + "/max_brightness" : ""
        onLoaded: {
            var v = parseInt(text().trim())
            if (!isNaN(v) && v > 0) {
                root._maxBrightness = v
                brightnessFile.reload()
            }
        }
    }

    // Leer brillo actual (reactivo a cambios en sysfs)
    property var _brightnessFile: FileView {
        id: brightnessFile
        path: root._backlightPath !== "" ? root._backlightPath + "/brightness" : ""
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            var v = parseInt(text().trim())
            if (!isNaN(v)) {
                root.brightness = Math.round(v / root._maxBrightness * 100)
                root._brightnessReady = true
            }
        }
    }

    function refresh() {
        if (root._backlightPath === "") {
            // Aún no se descubrió el path: arrancar el one-shot de detección. Una vez cacheado, la cadena
            // onRead → maxBrightness → brightness rellena todo; en las siguientes aperturas solo se reload().
            if (!backlightPathProc.running) backlightPathProc.running = true
        } else {
            brightnessFile.reload()
        }
    }

    // Escritura de brillo DECISIÓN (AUDIT Sección 5/8): la escritura NO migra a FileView.setText() porque el sysfs es `root:root rw-r--r--` y el usuario no está en el grupo `video` (ni hay
    // regla udev aplicada en el sistema) — la escritura directa fallaría silenciosamente. Se mantiene `brightnessctl set`, que escala permisos de escritura vía logind/D-Bus de la sesión y funciona sin root.
    property Process _setBrightnessProc: Process {
        id: setBrightnessProc
        running: false
        command: ["brightnessctl", "set", ""]
    }

    function setBrightness(pct) {
        root.brightness = pct
        const raw = Math.round(pct / 100 * root._maxBrightness)
        setBrightnessProc.command = ["brightnessctl", "set", String(raw)]
        if (!setBrightnessProc.running) setBrightnessProc.running = true
    }
}

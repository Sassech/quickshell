// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../Components"

// ClockOverlay — glanceable compact clock (Approach B ~400px).
// SystemClock reactivo (Seconds), 12/24h unificado vía clock-prefs.json key use24h (compartido con Widgets/Clock).
// Muestra hora con segundos, fecha, UTC, semana/día del año, timezone y NTP. Sin notificaciones.
OverlayWindow {
    id: root

    entryId:        "clock"
    corner:         "bottom-right"
    overlayWidth:   280
    restingOpacity: 0.95
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0
    borderColor:    Theme.surface2
    showAccent:     false

    // — Reloj nativo reactivo —
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // — Estado 12/24h unificado (misma key que Widgets/Clock) —
    property bool use24h: true

    FileView {
        id: prefsFile
        path: Paths.config + "/clock-prefs.json"
        // qmllint disable signal-handler-parameters
        onLoaded: {
            try {
                const prefs = JSON.parse(text())
                // Clave única "use24h" — evita carrera dual use24h vs use24hFormat
                if (typeof prefs.use24h === "boolean") root.use24h = prefs.use24h
            } catch(e) {}
        }
        // qmllint enable signal-handler-parameters
        Component.onCompleted: reload()
    }

    function setFormat(is24h: bool) {
        root.use24h = is24h
        prefsFile.setText(JSON.stringify({ use24h: is24h }))
    }

    // — Timezone + NTP (timedatectl) —
    property string timezone: ""
    property bool ntpSynced: true

    Process {
        id: timeProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            // qmllint disable signal-handler-parameters
            onRead: line => {
                const t = line.trim()
                if (t.startsWith("Timezone=")) {
                    root.timezone = t.substring("Timezone=".length) || "Unknown"
                } else if (t.startsWith("NTPSynchronized=")) {
                    root.ntpSynced = t.endsWith("yes")
                }
            }
            // qmllint enable signal-handler-parameters
        }
        // qmllint disable signal-handler-parameters
        onExited: {
            if (root.timezone === "") root.timezone = "Unknown"
        }
        // qmllint enable signal-handler-parameters
    }

    function loadTimeAndNtp() {
        timeProc.command = ["timedatectl", "show", "-p", "Timezone", "-p", "NTPSynchronized"]
        timeProc.running = true
    }

    // — Helpers fecha —
    function _calcWeekOfYear(now) {
        const d = new Date(now)
        const start = new Date(d.getFullYear(), 0, 1)
        return Math.ceil(((d - start) + start.getDay() * 86400000) / 604800000)
    }
    function _calcDayOfYear(now) {
        const d = new Date(now)
        const start = new Date(d.getFullYear(), 0, 1)
        return Math.ceil((d - start) / 86400000)
    }
    function _calcDaysRemaining(now) {
        const d = new Date(now)
        const end = new Date(d.getFullYear(), 11, 31)
        return Math.ceil((end - d) / 86400000)
    }

    // — Computed bindings sobre sysClock —
    readonly property string _timeStr: {
        const h = sysClock.hours
        const m = sysClock.minutes
        if (root.use24h)
            return h.toString().padStart(2, "0") + ":" + m.toString().padStart(2, "0")
        const h12 = h % 12 || 12
        return h12 + ":" + m.toString().padStart(2, "0")
    }
    readonly property string _secsStr: {
        const s = sysClock.seconds
        if (root.use24h)
            return ":" + s.toString().padStart(2, "0")
        const ampm = sysClock.hours >= 12 ? " pm" : " am"
        return ":" + s.toString().padStart(2, "0") + ampm
    }
    readonly property string _dateStr: Qt.formatDateTime(sysClock.date, "dddd, d 'de' MMMM 'de' yyyy")
    readonly property string _shortDate: Qt.formatDateTime(sysClock.date, "ddd dd MMM yyyy")
    readonly property string _utcStr: {
        const d = new Date(sysClock.date)
        // UTC aproximado desde offset local
        const utcH = d.getUTCHours().toString().padStart(2, "0")
        const utcM = d.getUTCMinutes().toString().padStart(2, "0")
        return utcH + ":" + utcM
    }
    readonly property int _weekOfYear: _calcWeekOfYear(sysClock.date)
    readonly property int _dayOfYear: _calcDayOfYear(sysClock.date)
    readonly property int _daysRemaining: _calcDaysRemaining(sysClock.date)

    onVisibleChanged: {
        if (visible) {
            prefsFile.reload()
            loadTimeAndNtp()
        }
    }
    Component.onCompleted: {
        // carga diferida ya en onVisible; también precarga por si overlay arranca visible (estado persistido)
        if (OverlaysManager.get("clock") && OverlaysManager.get("clock").enabled) {
            loadTimeAndNtp()
        }
    }

    // — Contenido (slot → contentArea) —
    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 10

        // Header
        Item {
            width: parent.width
            height: 22

            Text {
                id: shortDateText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 60)
                text: root._shortDate
                font.pixelSize: 11
                color: Theme.muted2
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: closeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    const e = OverlaysManager.get("clock")
                    if (e) e.enabled = false
                }
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeBtn.containsMouse ? Theme.text : Theme.muted3
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }

        // Hora
        Item {
            width: parent.width
            height: timeRow.implicitHeight
            Row {
                id: timeRow
                anchors.centerIn: parent
                spacing: 0
                Text {
                    id: timeText
                    text: root._timeStr
                    color: Theme.text
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: secsText
                    text: root._secsStr
                    color: Theme.muted2
                    font.pixelSize: 20
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root._dateStr
            font.pixelSize: 12
            color: Theme.muted1
            wrapMode: Text.WordWrap
        }

        // UTC badge + timezone inline
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Rectangle {
                width: utcText.implicitWidth + 10
                height: 16
                radius: 4
                color: Theme.surface3

                Text {
                    id: utcText
                    anchors.centerIn: parent
                    text: "UTC " + root._utcStr
                    color: Theme.muted2
                    font.pixelSize: 9
                    font.family: "monospace"
                }
            }

            Text {
                text: root.timezone
                color: Theme.muted2
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 140)
            }

            Text {
                text: "·"
                color: Theme.muted3
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.ntpSynced ? "NTP ✓" : "NTP ✕"
                color: root.ntpSynced ? Theme.success : Theme.error
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

        // Detalles: semana / día del año / restantes — centrados, juntos
        GridLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 3
            rowSpacing: 6
            columnSpacing: 12

            // Semana
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: 1
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Semana"; font.pixelSize: 9; color: Theme.muted3 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root._weekOfYear); font.pixelSize: 12; font.bold: true; color: Theme.text }
            }
            // Día del año
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: 1
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Día del año"; font.pixelSize: 9; color: Theme.muted3 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root._dayOfYear); font.pixelSize: 12; font.bold: true; color: Theme.text }
            }
            // Días restantes
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: 1
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Restantes"; font.pixelSize: 9; color: Theme.muted3 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(root._daysRemaining); font.pixelSize: 12; font.bold: true; color: Theme.text }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

        // Toggle 12/24h unificado — centrado
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                text: "Formato:"
                font.pixelSize: 11
                color: Theme.muted2
            }

            Rectangle {
                implicitWidth: 44; implicitHeight: 26; radius: 7; color: Theme.surface2
                border.color: Theme.accent
                border.width: root.use24h ? 2 : 0

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setFormat(true)
                }
                Text { anchors.centerIn: parent; text: "24h"; font.pixelSize: 11; color: Theme.text }
            }

            Rectangle {
                implicitWidth: 44; implicitHeight: 26; radius: 7; color: Theme.surface2
                border.color: Theme.accent
                border.width: root.use24h ? 0 : 2

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setFormat(false)
                }
                Text { anchors.centerIn: parent; text: "12h"; font.pixelSize: 11; color: Theme.text }
            }
        }
    }
}

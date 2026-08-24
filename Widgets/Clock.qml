import QtQuick
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root
    radius: 8
    color: Theme.surface2
    implicitWidth: 210
    implicitHeight: 28

    signal clicked()

    property bool use24h: true
    property string timezone: ""
    property bool ntpSynced: true

    // Reloj nativo (SystemClock — reactivo, sin Timer ni setters)
    // precision Seconds → dateChanged cada segundo.
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // Computed properties — texto del reloj (bindings sobre sysClock)
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

    readonly property string _dateStr: Qt.formatDateTime(sysClock.date, "ddd dd MMM")

    readonly property string _utcStr: {
        const d = new Date(sysClock.date)
        const utc = new Date(d.getTime() + (d.getTimezoneOffset() * -60000))
        return utc.toLocaleTimeString(Qt.locale(), Locale.ShortFormat).slice(0, 5)
    }

    // Valores del tooltip — derivados de sysClock.date (recomputan solos)
    readonly property string _tooltipDate: Qt.formatDateTime(sysClock.date, "dddd, d 'de' MMMM 'de' yyyy")
    readonly property int  _weekOfYear:    _calcWeekOfYear(sysClock.date)
    readonly property int  _dayOfYear:     _calcDayOfYear(sysClock.date)
    readonly property int  _daysRemaining: _calcDaysRemaining(sysClock.date)

    Component.onCompleted: {
        prefsFile.reload()
        loadTimeAndNtp()
    }

    // Fix 1: FileView reemplaza loadPrefsProc
    FileView {
        id: prefsFile
        path: Paths.config + "/clock-prefs.json"
        onLoaded: {
            try {
                const prefs = JSON.parse(text())
                root.use24h = prefs.use24h !== false
            } catch(e) {}
        }
    }

    // Reload prefs only when explicitly requested (no timer)
    function requestPrefsReload() {
        prefsFile.reload()
    }

    function savePrefs() {
        prefsFile.setText(JSON.stringify({use24h: root.use24h}))
    }

    // Timezone + NTP (timedatectl — sin alternativa nativa en v0.3.0) Un solo proceso: `timedatectl show`
    // admite varias propiedades por llamada, eliminando el segundo Process + el pipe a grep del NTP check.
    Process {
        id: timeProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const t = line.trim()
                if (t.startsWith("Timezone=")) {
                    root.timezone = t.substring("Timezone=".length) || "Unknown"
                } else if (t.startsWith("NTPSynchronized=")) {
                    root.ntpSynced = t.endsWith("yes")
                }
            }
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

    // Helpers tooltip (reciben sysClock.date — el tipo QML `date` es Date-compatible en JS, por eso new
    // Date(now) replica el comportamiento original con el instante del SystemClock)
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

    Row {
        id: innerRow
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 6

        Row {
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: timeText
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                font.family: "monospace"
                anchors.verticalCenter: parent.verticalCenter
                text: root._timeStr
            }

            Text {
                id: secsText
                color: Theme.muted2
                font.pixelSize: 14
                font.family: "monospace"
                anchors.verticalCenter: parent.verticalCenter
                text: root._secsStr
            }
        }

        Rectangle {
            width: 3
            height: 3
            radius: 2
            color: Theme.muted3
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: dateText
            color: Theme.muted1
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            text: root._dateStr
        }

        Rectangle {
            width: utcText.implicitWidth + 6
            height: 14
            radius: 3
            color: Theme.surface3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: utcText
                text: "UTC " + root._utcStr
                color: Theme.muted2
                font.pixelSize: 8
                font.family: "monospace"
                anchors.centerIn: parent
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Rectangle {
        id: tooltip
        visible: mouseArea.containsMouse
        width: 160
        height: 95
        radius: 6
        color: Theme.cardBg3
        border.color: Theme.surface2
        border.width: 1
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 6
        z: 100

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: root._tooltipDate
                color: Theme.text
                font.pixelSize: 11
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface2
            }

            Text {
                text: "Semana: " + root._weekOfYear
                color: Theme.muted1
                font.pixelSize: 9
            }

            Text {
                text: "Día del año: " + root._dayOfYear
                color: Theme.muted1
                font.pixelSize: 9
            }

            Text {
                text: "Días restantes: " + root._daysRemaining
                color: Theme.muted1
                font.pixelSize: 9
            }

            Text {
                text: "Zona horaria: " + root.timezone
                color: Theme.muted2
                font.pixelSize: 8
            }

            Text {
                text: "NTP: " + (root.ntpSynced ? "Sincronizado" : "No sincronizado")
                color: root.ntpSynced ? Theme.accent : Theme.error
                font.pixelSize: 8
            }
        }
    }

}

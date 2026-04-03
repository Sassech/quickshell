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
    property string utcTime: "--:--"
    property bool ntpSynced: true

    // ── Load preferences ───────────────────────────────────────────────────
    Component.onCompleted: {
        loadPrefs();
        loadTimezone();
        checkNtp();
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: loadPrefs()
    }

    Process {
        id: tzProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.timezone = data.trim()
        }
    }

    function loadTimezone() {
        tzProc.command = ["bash", "-c", "timedatectl show -p Timezone --value 2>/dev/null || echo 'Unknown'"];
        tzProc.running = true;
    }

    Process {
        id: loadPrefsProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const prefs = JSON.parse(data);
                    root.use24h = prefs.use24h !== false;
                    updateTime();
                } catch(e) {}
            }
        }
    }

    function loadPrefs() {
        loadPrefsProc.command = ["bash", "-c", "cat /home/sassech/.config/quickshell/config/clock-prefs.json 2>/dev/null || echo '{}'"];
        loadPrefsProc.running = true;
    }

    function savePrefs() {
        savePrefsProc.command = ["bash", "-c", "echo '" + JSON.stringify({use24h: root.use24h}) + "' > /home/sassech/.config/quickshell/config/clock-prefs.json"];
        savePrefsProc.running = true;
    }

    Process {
        id: savePrefsProc
        running: false
    }

    // ── NTP check ──────────────────────────────────────────────────────────
    Process {
        id: ntpProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.ntpSynced = data.trim().indexOf("yes") !== -1;
            }
        }
    }

    function checkNtp() {
        ntpProc.command = ["bash", "-c", "timedatectl status 2>/dev/null | grep -oP 'System clock synchronized: \\K\\w+' || echo 'no'"];
        ntpProc.running = true;
    }

    // ── UTC time monitor ───────────────────────────────────────────────────
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            const utc = new Date(now.getTime() + (now.getTimezoneOffset() * -60000));
            root.utcTime = utc.toLocaleTimeString(Qt.locale(), Locale.ShortFormat).slice(0,5);
            
            const prevSec = secsText.text;
            const newSec = Qt.formatDateTime(now, ":ss");
            if (prevSec !== newSec) {
                updateTime();
            }
        }
    }

    function updateTime() {
        const now = new Date();
        const hours = now.getHours();
        const minutes = now.getMinutes();
        const seconds = now.getSeconds();
        
        if (root.use24h) {
            timeText.text = `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}`;
            secsText.text = `:${seconds.toString().padStart(2, "0")}`;
        } else {
            const ampm = hours >= 12 ? "pm" : "am";
            const h = hours % 12 || 12;
            timeText.text = `${h}:${minutes.toString().padStart(2, "0")}`;
            secsText.text = `:${seconds.toString().padStart(2, "0")} ${ampm}`;
        }
        dateText.text = Qt.formatDateTime(now, "ddd dd MMM");
    }

    Row {
        id: innerRow
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 6

        // Time section: HH:mm + seconds
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
                text: Qt.formatDateTime(new Date(), "HH:mm")
            }

            Text {
                id: secsText
                color: Theme.muted2
                font.pixelSize: 14
                font.family: "monospace"
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(), ":ss")
            }
        }

        // Separator dot
        Rectangle {
            width: 3
            height: 3
            radius: 2
            color: Theme.muted3
            anchors.verticalCenter: parent.verticalCenter
        }

        // Date section
        Text {
            id: dateText
            color: Theme.muted1
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(new Date(), "ddd dd MMM")
        }

        // UTC indicator
        Rectangle {
            width: utcText.implicitWidth + 6
            height: 14
            radius: 3
            color: Theme.surface3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: utcText
                text: "UTC " + root.utcTime
                color: Theme.muted2
                font.pixelSize: 8
                font.family: "monospace"
                anchors.centerIn: parent
            }
        }
    }

    // ── Click handler ──────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // ── Enriched Tooltip ───────────────────────────────────────────────────
    Rectangle {
        id: tooltip
        visible: mouseArea.containsMouse
        width: 160
        height: 95
        radius: 6
        color: Theme.base
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
                text: Qt.formatDateTime(new Date(), "dddd, d 'de' MMMM 'de' yyyy")
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
                text: "Semana: " + getWeekOfYear()
                color: Theme.muted1
                font.pixelSize: 9
            }

            Text {
                text: "Día del año: " + getDayOfYear()
                color: Theme.muted1
                font.pixelSize: 9
            }

            Text {
                text: "Días restantes: " + getDaysRemaining()
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

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    function getWeekOfYear() {
        const now = new Date();
        const start = new Date(now.getFullYear(), 0, 1);
        const diff = now - start;
        const oneWeek = 604800000;
        return Math.ceil((diff + start.getDay() * 86400000) / oneWeek);
    }

    function getDayOfYear() {
        const now = new Date();
        const start = new Date(now.getFullYear(), 0, 1);
        return Math.ceil((now - start) / 86400000);
    }

    function getDaysRemaining() {
        const now = new Date();
        const end = new Date(now.getFullYear(), 11, 31);
        return Math.ceil((end - now) / 86400000);
    }
}

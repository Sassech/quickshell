import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    property var screen: null
    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()

    onVisibleChanged: {
        if (visible) {
            updateCalendar();
            Qt.callLater(function() { card.forceActiveFocus() })
        }
    }

    function updateCalendar() {
        calendarGrid.model = getDaysInMonth(currentYear, currentMonth);
    }

    function getDaysInMonth(year, month) {
        const days = [];
        const firstDay = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const prevMonthDays = new Date(year, month, 0).getDate();

        for (let i = firstDay - 1; i >= 0; i--) {
            days.push({ day: prevMonthDays - i, otherMonth: true });
        }

        const today = new Date();
        for (let i = 1; i <= daysInMonth; i++) {
            days.push({
                day: i,
                isToday: i === today.getDate() && month === today.getMonth() && year === today.getFullYear(),
                otherMonth: false
            });
        }

        while (days.length % 7 !== 0) {
            days.push({ day: days.length - firstDay - daysInMonth + 1, otherMonth: true });
        }

        return days;
    }

    // Overlay oscuro
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // Card principal con altura fija
    Rectangle {
        id: card
        focus: true
        anchors.centerIn: parent
        width: 380
        height: 380
        radius: 16
        color: Theme.cardBg3
        border.color: Theme.surface2
        border.width: 1

        Keys.onEscapePressed: root.visible = false

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: column
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 16
                bottomMargin: 16
            }
            leftPadding: 20
            rightPadding: 20
            topPadding: 16
            spacing: 10

            // Navegación del calendario
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.surface3
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (currentMonth === 0) { currentMonth = 11; currentYear--; }
                            else { currentMonth--; }
                            updateCalendar();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        font.pixelSize: 18
                        color: Theme.text
                    }
                }

                Text {
                    text: Qt.formatDateTime(new Date(currentYear, currentMonth, 1), "MMMM yyyy")
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.surface3
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (currentMonth === 11) { currentMonth = 0; currentYear++; }
                            else { currentMonth++; }
                            updateCalendar();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 18
                        color: Theme.text
                    }
                }

                Rectangle {
                    width: 50
                    height: 32
                    radius: 8
                    color: Theme.surface3
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentMonth = new Date().getMonth();
                            currentYear = new Date().getFullYear();
                            updateCalendar();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Hoy"
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }
            }

            // Días de la semana
            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter

                ListModel {
                    id: weekDays
                    ListElement { day: "Dom" }
                    ListElement { day: "Lun" }
                    ListElement { day: "Mar" }
                    ListElement { day: "Mié" }
                    ListElement { day: "Jue" }
                    ListElement { day: "Vie" }
                    ListElement { day: "Sáb" }
                }

                Repeater {
                    model: weekDays
                    Text {
                        width: 40
                        text: model.day
                        color: Theme.muted2
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Grid del calendario con altura fija
            Column {
                spacing: 4
                anchors.horizontalCenter: parent.horizontalCenter

                property int cellHeight: 32
                property int cellSpacing: 4
                property int rows: 6

                height: rows * cellHeight + (rows - 1) * cellSpacing

                Grid {
                    id: calendarGrid
                    columns: 7
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter

                    property var model: []

                    Repeater {
                        model: calendarGrid.model
                        Rectangle {
                            width: 40
                            height: 32
                            radius: 6
                            color: {
                                if (modelData.isToday) return Theme.accent;
                                if (modelData.otherMonth) return "transparent";
                                return Theme.surface3;
                            }
                            opacity: modelData.otherMonth ? 0.4 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.pixelSize: 13
                                color: {
                                    if (modelData.isToday) return Theme.cardBg3;
                                    if (modelData.otherMonth) return Theme.muted3;
                                    return Theme.text;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // Selector de formato
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: "Formato:"
                    font.pixelSize: 12
                    color: Theme.muted1
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    id: btn24h
                    width: 50
                    height: 30
                    radius: 8
                    color: Theme.surface2
                    border.color: Theme.accent
                    border.width: use24hFormat ? 2 : 0
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: setFormat(true)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "24h"
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }

                Rectangle {
                    id: btn12h
                    width: 50
                    height: 30
                    radius: 8
                    color: Theme.surface2
                    border.color: Theme.accent
                    border.width: use24hFormat ? 0 : 2
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: setFormat(false)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "12h"
                        font.pixelSize: 12
                        color: Theme.text
                    }
                }
            }
        }
    }

    property bool use24hFormat: true

    Component.onCompleted: {
        loadFormatPref()
    }

    function loadFormatPref() {
        loadFormatProc.running = true;
    }

    property string _formatBuf: ""
    Process {
        id: loadFormatProc
        running: false
        command: ["bash", "-c", "cat \"" + Paths.config + "/clock-prefs.json\" 2>/dev/null || echo '{\"use24h\":true}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const prefs = JSON.parse(data.trim());
                    root.use24hFormat = prefs.use24h !== false;
                } catch(e) {}
            }
        }
    }

    function setFormat(is24h) {
        root.use24hFormat = is24h;
        saveFormatProc.command = ["bash", "-c", "echo '{\"use24h\":" + is24h + "}' > \"" + Paths.config + "/clock-prefs.json\""];
        saveFormatProc.running = true;
    }

    Process {
        id: saveFormatProc
        running: false
    }
}

// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    property var targetScreen: null   // renombrado para evitar conflicto con WindowInterface.screen
    property var notifModel: null
    property int currentMonth: 0
    property int currentYear: 0
    property bool use24hFormat: true
    property string _dateText: ""

    // ── Timer para actualizar la hora en tiempo real ──────────────────────
    Timer {
        id: clockTimer
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: clockText.updateTime()
    }

    onVisibleChanged: {
        if (visible) {
            const now = new Date()
            currentMonth = now.getMonth()
            currentYear  = now.getFullYear()
            updateCalendar()
            clockText.updateTime()
            Qt.callLater(function() { card.forceActiveFocus() })
        }
    }

    function updateCalendar() {
        calendarGrid.model = getDaysInMonth(root.currentYear, root.currentMonth)
    }

    function getDaysInMonth(year, month) {
        const days = []
        const firstDay = new Date(year, month, 1).getDay()
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const prevMonthDays = new Date(year, month, 0).getDate()

        for (let i = firstDay - 1; i >= 0; i--) {
            days.push({ day: prevMonthDays - i, otherMonth: true })
        }

        const today = new Date()
        for (let i = 1; i <= daysInMonth; i++) {
            days.push({
                day: i,
                isToday: i === today.getDate() && month === today.getMonth() && year === today.getFullYear(),
                otherMonth: false
            })
        }

        while (days.length % 7 !== 0) {
            days.push({ day: days.length - firstDay - daysInMonth + 1, otherMonth: true })
        }

        return days
    }



    // ── Overlay oscuro ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.55

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // ── Card principal ────────────────────────────────────────────────────
    Rectangle {
        id: card
        focus: true
        anchors.centerIn: parent
        width: 800
        height: 450
        radius: 16
        color: Theme.cardBg3
        border.color: Theme.surface2
        border.width: 1

        Keys.onEscapePressed: root.visible = false
        MouseArea { anchors.fill: parent; onClicked: {} }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── Columna izquierda: Notificaciones ─────────────────────────
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: 360

                // Borde derecho separador
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 16
                    anchors.bottomMargin: 16
                    width: 1
                    color: Theme.surface2
                }

                ColumnLayout {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 16
                    anchors.bottomMargin: 16
                    spacing: 10

                    // ── Header ────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Notificaciones"
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.text
                            Layout.fillWidth: true
                        }

                        // Botón limpiar todo
                        Rectangle {
                            implicitWidth: 82
                             implicitHeight: 28
                             radius: 8
                             color: clearAllArea.containsMouse ? Theme.surface4 : Theme.surface3
                             visible: root.notifModel && root.notifModel.count > 0

                            Behavior on color { ColorAnimation { duration: 100 } }

                            MouseArea {
                                id: clearAllArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    if (root.notifModel) root.notifModel.clear()
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "󰩹"
                                    font.pixelSize: 13
                                    color: clearAllArea.containsMouse ? Theme.error : Theme.muted2
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    text: "Limpiar"
                                    font.pixelSize: 11
                                    color: clearAllArea.containsMouse ? Theme.text : Theme.muted1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }
                        }
                    }

                    // ── Área de contenido (vacío o lista) ────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Estado vacío
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: !root.notifModel || root.notifModel.count === 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰂚"
                                font.pixelSize: 36
                                color: Theme.muted3
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Sin notificaciones"
                                font.pixelSize: 12
                                color: Theme.muted2
                            }
                        }

                        // Lista con scroll
                        Flickable {
                            id: notifFlick
                            anchors.fill: parent
                            visible: root.notifModel && root.notifModel.count > 0
                            clip: true
                            contentHeight: notifColumn.implicitHeight
                        flickableDirection: Flickable.VerticalFlick

                        // Scroll suave con rueda
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: notifColumn
                            width: notifFlick.width - 8
                            spacing: 6

                            Repeater {
                                model: root.notifModel ? root.notifModel : []

                                delegate: Rectangle {
                                    id: notifItem
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    implicitHeight: notifRow.implicitHeight + 20
                                    radius: 10
                                    color: Theme.surface2
                                    clip: true

                                    // Franja accent izquierda
                                    Rectangle {
                                        width: 3
                                        height: parent.height
                                        radius: 2
                                        color: notifItem.modelData.notifUrgent
                                               ? Theme.error : Theme.accent
                                    }

                                    Row {
                                        id: notifRow
                                        anchors {
                                            left: parent.left
                                            leftMargin: 12
                                            right: parent.right
                                            rightMargin: 28
                                            verticalCenter: parent.verticalCenter
                                        }
                                        spacing: 10

                                        // Icono
                                        Item {
                                            width: 32
                                            height: 32
                                            anchors.verticalCenter: parent.verticalCenter

                                            Image {
                                                id: notifImg
                                                anchors.fill: parent
                                                source: {
                                                    const ic = notifItem.modelData.notifIcon ?? ""
                                                    if (!ic || ic.length === 0) return ""
                                                    if (ic.startsWith("/") || ic.startsWith("file://")) return ic
                                                    if (ic.length > 4) return "image://theme/" + ic
                                                    return ""
                                                }
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                mipmap: true
                                                visible: status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🔔"
                                                font.pixelSize: 18
                                                visible: notifImg.status !== Image.Ready
                                            }
                                        }

                                        // Texto
                                        Column {
                                            spacing: 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 42

                                            Text {
                                                text: notifItem.modelData.notifSummary ?? ""
                                                color: Theme.text
                                                font.pixelSize: 12
                                                font.bold: true
                                                width: parent.width
                                                elide: Text.ElideRight
                                                visible: text.length > 0
                                            }

                                            Text {
                                                text: notifItem.modelData.notifBody ?? ""
                                                color: Theme.muted1
                                                font.pixelSize: 11
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                visible: text.length > 0
                                            }

                                            Text {
                                                text: notifItem.modelData.notifApp ?? ""
                                                color: Theme.muted3
                                                font.pixelSize: 10
                                                visible: text.length > 0
                                            }
                                        }
                                    }

                                    // Hover overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: Theme.hover
                                        visible: notifHoverArea.containsMouse
                                    }
                                    MouseArea {
                                        id: notifHoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    // Botón dismiss individual
                                    Rectangle {
                                        id: dismissBtn
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: dismissBtnArea.containsMouse ? Theme.surface4 : "transparent"
                                        z: 10

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: dismissBtnArea.containsMouse ? Theme.text : Theme.muted3
                                            font.pixelSize: 11

                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }

                                        MouseArea {
                                            id: dismissBtnArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.notifModel) root.notifModel.remove(notifItem.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } // fin Flickable
                    } // fin Item wrapper
                }
            }

            // ── Columna derecha: Reloj + Calendario ───────────────────────
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 0

                Item { Layout.preferredHeight: 20 }

                // ── Reloj grande ──────────────────────────────────────────
                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: 64
                    font.bold: true
                    color: Theme.text

                    property string _time: ""
                    text: _time

                    function updateTime() {
                        const now = new Date()
                        if (root.use24hFormat) {
                            const h = String(now.getHours()).padStart(2, "0")
                            const m = String(now.getMinutes()).padStart(2, "0")
                            _time = h + ":" + m
                        } else {
                            let h = now.getHours()
                            const ampm = h >= 12 ? "PM" : "AM"
                            h = h % 12 || 12
                            const m = String(now.getMinutes()).padStart(2, "0")
                            _time = h + ":" + m + " " + ampm
                        }
                        root._dateText = Qt.formatDateTime(now, "dddd, d 'de' MMMM")
                    }

                    Component.onCompleted: updateTime()
                }

                // ── Fecha completa ────────────────────────────────────────
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root._dateText
                    font.pixelSize: 13
                    color: Theme.muted1
                }

                Item { Layout.preferredHeight: 12 }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 1
                    color: Theme.surface2
                }

                Item { Layout.preferredHeight: 10 }

                // ── Navegación del calendario ─────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 4

                    // ‹ mes anterior
                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28; radius: 7; color: Theme.surface3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentMonth === 0) { root.currentMonth = 11; root.currentYear-- }
                                else { root.currentMonth-- }
                                root.updateCalendar()
                            }
                        }
                        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 16; color: Theme.text }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(new Date(root.currentYear, root.currentMonth, 1), "MMMM")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.text
                    }

                    // › mes siguiente
                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28; radius: 7; color: Theme.surface3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentMonth === 11) { root.currentMonth = 0; root.currentYear++ }
                                else { root.currentMonth++ }
                                root.updateCalendar()
                            }
                        }
                        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 16; color: Theme.text }
                    }

                    Item { Layout.preferredWidth: 8 }

                    // ‹ año anterior
                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28; radius: 7; color: Theme.surface3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentYear--; root.updateCalendar() }
                        }
                        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 16; color: Theme.text }
                    }

                    Text {
                        text: String(root.currentYear)
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.text
                    }

                    // › año siguiente
                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28; radius: 7; color: Theme.surface3
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentYear++; root.updateCalendar() }
                        }
                        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 16; color: Theme.text }
                    }
                }

                Item { Layout.preferredHeight: 8 }

                // ── Días de la semana ─────────────────────────────────────
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0

                    Repeater {
                        model: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
                        Text {
                            required property var modelData
                            width: 48
                            text: modelData
                            color: Theme.muted2
                            font.pixelSize: 10
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Item { Layout.preferredHeight: 4 }

                // ── Grid del calendario ───────────────────────────────────
                Grid {
                    id: calendarGrid
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7
                    spacing: 3
                    property var model: []

                    Repeater {
                        model: calendarGrid.model
                        Rectangle {
                            id: calDay
                            required property var modelData
                            width: 48; height: 30; radius: 6
                            color: calDay.modelData.isToday ? Theme.accent
                                   : calDay.modelData.otherMonth ? "transparent"
                                   : Theme.surface3
                            opacity: calDay.modelData.otherMonth ? 0.35 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: calDay.modelData.day
                                font.pixelSize: 12
                                color: calDay.modelData.isToday ? Theme.cardBg3
                                       : calDay.modelData.otherMonth ? Theme.muted3
                                       : Theme.text
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 1
                    color: Theme.surface2
                }

                Item { Layout.preferredHeight: 10 }

                // ── Selector de formato ───────────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 14
                    spacing: 8

                    Text {
                        text: "Formato:"
                        font.pixelSize: 11
                        color: Theme.muted2
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 26; radius: 7; color: Theme.surface2
                        border.color: Theme.accent
                        border.width: root.use24hFormat ? 2 : 0

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
                        border.width: root.use24hFormat ? 0 : 2

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
    }

    // ── Persistencia de formato ───────────────────────────────────────────
    Component.onCompleted: loadFormatPref()

    function loadFormatPref() {
        loadFormatProc.running = true
    }

    Process {
        id: loadFormatProc
        running: false
        command: ["bash", "-c", "cat \"" + Paths.config + "/clock-prefs.json\" 2>/dev/null || echo '{\"use24h\":true}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const prefs = JSON.parse(data.trim())
                    root.use24hFormat = prefs.use24h !== false
                    clockText.updateTime()
                } catch(e) {}
            }
        }
    }

    function setFormat(is24h) {
        root.use24hFormat = is24h
        clockText.updateTime()
        saveFormatProc.command = ["bash", "-c", "echo '{\"use24h\":" + is24h + "}' > \"" + Paths.config + "/clock-prefs.json\""]
        saveFormatProc.running = true
    }

    Process {
        id: saveFormatProc
        running: false
    }
}

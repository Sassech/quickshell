pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../Components"

PanelWindow {
    id: root

    visible: false
    color:   "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    // ── Provider (singleton) ──────────────────────────────────────────────
    WeatherHelpers {
        id: weatherHelpers
    }

    // ── Bindings al provider ─────────────────────────────────────────────
    property var currentWeather: ({
        temperature: WeatherProvider.temperature,
        feelsLike: WeatherProvider.feelsLike,
        windSpeed: WeatherProvider.windSpeed,
        humidity: WeatherProvider.humidity,
        weatherCode: WeatherProvider.weatherCode,
        isDay: WeatherProvider.isDay
    })
    property var hourlyData: WeatherProvider.hourlyData
    property var dailyData: WeatherProvider.dailyData
    property string cityName: WeatherProvider.cityName
    property bool loading: WeatherProvider.loading
    property bool isDay: WeatherProvider.isDay
    property string sunrise: WeatherProvider.sunrise
    property string sunset: WeatherProvider.sunset

    // ── Helpers ───────────────────────────────────────────────────────────
    function wmoIcon(code, day) { return weatherHelpers.wmoIcon(code, day) }
    function wmoDescription(code) { return weatherHelpers.wmoDescription(code) }

    // ── UI State ─────────────────────────────────────────────────────────
    property int selectedHourIndex: 0
    property int selectedDayIndex: 0

    readonly property color accent: isDay ? Theme.sky : Theme.accent2

    onVisibleChanged: {
        if (visible && !WeatherProvider.hasData && !loading) {
            // Trigger refresh if no data
        }
    }

    function refresh() {
        if (WeatherProvider.latitude === 0) {
            WeatherProvider.fallbackToIpGeo()
        } else {
            WeatherProvider.fetchWeather()
        }
    }

    function _selectDay(idx) {
        selectedDayIndex  = idx
        selectedHourIndex = 0
    }

    function _periodLabel() {
        var h = new Date().getHours()
        if (h < 6)  return "Madrugada"
        if (h < 12) return "Mañana"
        if (h < 18) return "Tarde"
        return "Noche"
    }

    function _sunProgress() {
        if (sunrise === "--:--" || sunset === "--:--") return 0.5
        var sp = sunrise.split(":")
        var ep = sunset.split(":")
        var riseMin = parseInt(sp[0]) * 60 + parseInt(sp[1])
        var setMin  = parseInt(ep[0]) * 60 + parseInt(ep[1])
        var nowMin  = new Date().getHours() * 60 + new Date().getMinutes()
        if (nowMin <= riseMin) return 0
        if (nowMin >= setMin)  return 1
        return (nowMin - riseMin) / (setMin - riseMin)
    }

    // ── Background dismiss ───────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onClicked: (mouse) => {
            var p = card.mapToItem(null, 0, 0)
            if (mouse.x < p.x || mouse.x > p.x + card.width ||
                mouse.y < p.y || mouse.y > p.y + card.height) {
                root.visible = false
            } else {
                mouse.accepted = false
            }
        }
    }

    // ── Main card ────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  700
        radius: 16
        color:  Theme.cardBg3
        border.color: Theme.surface2
        border.width: 1
        height: mainCol.implicitHeight + 44

        Rectangle {
            anchors.top:              parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 100; height: 2; radius: 1
            color: root.accent
        }

        // close button
        MouseArea {
            anchors.top:    parent.top
            anchors.right:  parent.right
            anchors.margins: 13
            width: 20; height: 20
            cursorShape: Qt.PointingHandCursor
            z: 10
            onClicked: root.visible = false
            Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted3; font.pixelSize: 12 }
        }

        Column {
            id: mainCol
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: 20
            spacing: 14

            // ── Row 1: period label + refresh ─────────────────────────────
            Item {
                width: parent.width; height: 18

                Text {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._periodLabel(); color: Theme.muted1; font.pixelSize: 12
                }

                MouseArea {
                    anchors.right:          parent.right
                    anchors.rightMargin:    26
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22
                    cursorShape: root.loading ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!root.loading) root.refresh()

                    Text {
                        anchors.centerIn: parent
                        text: "⟳"
                        color: root.loading ? root.accent : Theme.muted3
                        font.pixelSize: 16
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 1200
                            loops: Animation.Infinite
                            running: root.loading
                        }
                    }
                }
            }

            // ── Sun arc ───────────────────────────────────────────────────
            Item {
                width: parent.width; height: 130

                Canvas {
                    id: sunCanvas
                    anchors.fill:         parent
                    anchors.bottomMargin: 18

                    property real prog: root._sunProgress()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width / 2
                        var cy = height
                        var r  = cy * 0.92

                        ctx.beginPath()
                        ctx.arc(cx, cy, r, Math.PI, 0, false)
                        ctx.strokeStyle = Theme.surface2
                        ctx.lineWidth   = 2
                        ctx.setLineDash([5, 5])
                        ctx.stroke()
                        ctx.setLineDash([])

                        var endAng = Math.PI + prog * Math.PI
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, Math.PI, endAng, false)
                        ctx.strokeStyle = root.isDay ? Theme.warning : Theme.accent2
                        ctx.lineWidth   = 2
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(cx - r - 8, cy)
                        ctx.lineTo(cx + r + 8, cy)
                        ctx.strokeStyle = Theme.surface3
                        ctx.lineWidth   = 1
                        ctx.stroke()

                        var ang = Math.PI + prog * Math.PI
                        var sx  = cx + r * Math.cos(ang)
                        var sy  = cy + r * Math.sin(ang)
                        ctx.beginPath()
                        ctx.arc(sx, sy, 5, 0, 2 * Math.PI)
                        ctx.fillStyle = root.isDay ? Theme.warning : Theme.accent2
                        ctx.fill()
                    }

                    Connections {
                        target: WeatherProvider
                        function onDataReady() { sunCanvas.requestPaint() }
                    }
                    Component.onCompleted: requestPaint()
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    anchors.leftMargin: parent.width / 2 - (parent.height - 18) * 0.92 - 2
                    text: "E"; color: Theme.muted3; font.pixelSize: 11
                }
                Text {
                    anchors.bottom:           parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "S"; color: Theme.muted3; font.pixelSize: 11
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.right:  parent.right
                    anchors.rightMargin: parent.width / 2 - (parent.height - 18) * 0.92 - 2
                    text: "W"; color: Theme.muted3; font.pixelSize: 11
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    anchors.leftMargin: parent.width / 2 - (parent.height - 18) * 0.92 + 14
                    text:  "☀ " + root.sunrise; color: Theme.warning; font.pixelSize: 10
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.right:  parent.right
                    anchors.rightMargin: parent.width / 2 - (parent.height - 18) * 0.92 + 14
                    text:  "🌙 " + root.sunset; color: Theme.accent2; font.pixelSize: 10
                }
            }

            // ── Current summary ───────────────────────────────────────────
            Item {
                width:  parent.width
                height: summaryRow.implicitHeight

                Row {
                    id: summaryRow
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.wmoIcon(root.currentWeather.weatherCode, root.currentWeather.isDay); font.pixelSize: 46
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: Math.round(root.currentWeather.temperature) + "°"; color: Theme.text
                            font.pixelSize: 34; font.bold: true
                        }
                        Text { text: root.cityName; color: Theme.muted1; font.pixelSize: 12 }
                    }
                }

                Column {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Row {
                        anchors.right: parent.right
                        spacing: 20

                        Row {
                            spacing: 4
                            Text { text: "↑"; color: Theme.warning; font.pixelSize: 13 }
                            Text { text: Math.round(root.currentWeather.windSpeed) + " km/h"; color: Theme.text; font.pixelSize: 12 }
                        }
                        Row {
                            spacing: 4
                            Text { text: "💧"; font.pixelSize: 11 }
                            Text { text: root.currentWeather.humidity + "%"; color: Theme.text; font.pixelSize: 12 }
                        }
                        Row {
                            spacing: 4
                            Text { text: "🌡"; font.pixelSize: 11 }
                            Text { text: Math.round(root.currentWeather.feelsLike) + "°"; color: Theme.text; font.pixelSize: 12 }
                        }
                    }

                    Text {
                        id: clockText
                        anchors.right: parent.right
                        text:  Qt.formatDateTime(new Date(), "yyyy-MM-dd  HH:mm")
                        color: Theme.muted3; font.pixelSize: 11
                        Timer {
                            interval: 30000; running: true; repeat: true
                            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd  HH:mm")
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // ── Hourly forecast ───────────────────────────────────────────
            Column {
                width: parent.width; spacing: 10

                Text {
                    text: "Previsión horaria"; color: Theme.text
                    font.pixelSize: 13; font.bold: true
                }

                ListView {
                    id: hourlyList
                    width:       parent.width
                    height:      168
                    orientation: ListView.Horizontal
                    spacing:     8
                    clip:        true
                    model:       root.hourlyData

                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitHeight: 3; radius: 2
                            color: root.accent
                            opacity: 0.6
                        }
                    }

                    delegate: Rectangle {
                        id: hourlyDelegate
                        required property var modelData
                        required property int index
                        width:  110; height: 158; radius: 10
                        color:  hourlyDelegate.index === root.selectedHourIndex ? Theme.surface1 : Theme.cardBg3
                        border.color: hourlyDelegate.index === root.selectedHourIndex ? root.accent : Theme.surface2
                        border.width: hourlyDelegate.index === root.selectedHourIndex ? 1 : 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.selectedHourIndex = hourlyDelegate.index
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top:              parent.top
                            anchors.topMargin:        10
                            spacing: 0
                            width:   parent.width - 16

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:  hourlyDelegate.modelData.time
                                color: hourlyDelegate.index === root.selectedHourIndex ? root.accent : Theme.muted1
                                font.pixelSize: 12; font.bold: hourlyDelegate.index === root.selectedHourIndex
                            }
                            Item { width:1; height:4 }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.wmoIcon(hourlyDelegate.modelData.code, hourlyDelegate.modelData.isDay)
                                font.pixelSize: 20
                            }
                            Item { width:1; height:4 }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Text {
                                    text: Math.round(hourlyDelegate.modelData.temp) + "°"
                                    color: Theme.text; font.pixelSize: 18; font.bold: true
                                    anchors.baseline: feelsLbl.baseline
                                }
                                Text {
                                    id: feelsLbl
                                    text: Math.round(hourlyDelegate.modelData.feels) + "°"
                                    color: Theme.muted3; font.pixelSize: 12
                                    anchors.bottom: parent.bottom
                                }
                            }

                            Item { width:1; height:6 }

                            Column {
                                width: parent.width
                                spacing: 2
                                Row {
                                    spacing: 3
                                    Text { text: "💧"; font.pixelSize: 9 }
                                    Text { text: hourlyDelegate.modelData.hum + "%"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "↑"; color: Theme.accent; font.pixelSize: 9 }
                                    Text { text: Math.round(hourlyDelegate.modelData.wind) + " km/h"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "→"; color: Theme.success; font.pixelSize: 9 }
                                    Text { text: Math.round(hourlyDelegate.modelData.press) + " hPa"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "🌧"; font.pixelSize: 9 }
                                    Text { text: hourlyDelegate.modelData.precip + "%"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "◎"; color: Theme.accent2; font.pixelSize: 9 }
                                    Text { text: hourlyDelegate.modelData.vis.toFixed(1) + " km"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // ── Daily forecast ────────────────────────────────────────────
            Column {
                width: parent.width; spacing: 10

                Text {
                    text: "El Tiempo Diario"; color: Theme.text
                    font.pixelSize: 13; font.bold: true
                }

                Row {
                    width: parent.width; spacing: 6

                    Repeater {
                        model: root.dailyData

                        Rectangle {
                            id: dailyDelegate
                            required property var modelData
                            required property int index
                            width:  (parent.width - 6 * 6) / 7
                            height: 104; radius: 10
                            color:  dailyDelegate.index === root.selectedDayIndex ? Theme.surface1 : Theme.cardBg3
                            border.color: dailyDelegate.index === root.selectedDayIndex ? root.accent : Theme.surface2
                            border.width: dailyDelegate.index === root.selectedDayIndex ? 1 : 0

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    root._selectDay(dailyDelegate.index)
                            }

                            Column {
                                anchors.centerIn: parent; spacing: 5

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text:  dailyDelegate.index === 0 ? "Hoy" : dailyDelegate.modelData.dayName
                                    color: dailyDelegate.index === root.selectedDayIndex ? root.accent : Theme.muted1
                                    font.pixelSize: 11; font.bold: dailyDelegate.index === root.selectedDayIndex
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.wmoIcon(dailyDelegate.modelData.code, true); font.pixelSize: 24
                                }
                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(dailyDelegate.modelData.max) + "°"
                                        color: Theme.text; font.pixelSize: 12; font.bold: true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(dailyDelegate.modelData.min) + "°"
                                        color: Theme.muted3; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }
        }
    }
}

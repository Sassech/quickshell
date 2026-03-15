import QtQuick
import QtQuick.Controls
import QtPositioning
import Quickshell
import Quickshell.Io
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

    // ── Props ─────────────────────────────────────────────────────────────
    property string temperature: "--"
    property string feelsLike:   "--"
    property string windSpeed:   "--"
    property string humidity:    "--"
    property string cityName:    "Cargando..."
    property string weatherIcon: "☁"
    property string description: ""
    property bool   isDay:       true
    property bool   loading:     false

    // ── Cache ─────────────────────────────────────────────────────────────
    property string _cachedTemperature: "--"
    property string _cachedFeelsLike:   "--"
    property string _cachedWindSpeed:   "--"
    property string _cachedHumidity:    "--"
    property string _cachedCityName:    "Cargando..."
    property string _cachedWeatherIcon: "☁"
    property string _cachedDescription: ""
    property bool   _cachedIsDay:       true
    property string _cachedSunrise:    "--:--"
    property string _cachedSunset:     "--:--"
    property var    _cachedHourlyData:    []
    property var    _cachedAllHourlyData: []
    property var    _cachedDailyData:     []

    // ── Timer para caché (actualiza cada 10 minutos) ─────────────────────
    Timer {
        interval: 600000  // 10 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshCache()
    }

    function refreshCache() {
        if (_geoSourceSystem) {
            _positionSource.update()
        } else {
            _geoRaw = ""
            _weatherRaw = ""
            geoProc.running = true
        }
    }

    PositionSource {
        id: _positionSource
        active: true
        preferredPositioningMethods: PositionSource.AllPositioningMethods
        updateInterval: 3600000

        onPositionChanged: {
            var pos = _positionSource.position
            if (pos.coordinate.latitude !== 0 && pos.coordinate.longitude !== 0) {
                root._lat = pos.coordinate.latitude
                root._lon = pos.coordinate.longitude
                root._geoSourceSystem = true
                root.cityName = "Ubicación actual"
                root._cachedCityName = "Ubicación actual"
                _fetchWeather()
            }
        }

        onSourceErrorChanged: {
            console.log("WeatherModal PositionSource error:", sourceError)
            _geoRaw = ""
            _weatherRaw = ""
            geoProc.running = true
        }
    }

    function _fetchWeather() {
        _weatherRaw = ""
        weatherProc.command = [
            "sh", "-c",
            "curl -s --max-time 10 'https://api.open-meteo.com/v1/forecast" +
            "?latitude="  + root._lat +
            "&longitude=" + root._lon +
            "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day" +
            "&hourly=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure,relative_humidity_2m,visibility,precipitation_probability,is_day" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset" +
            "&forecast_days=7&wind_speed_unit=kmh&temperature_unit=celsius&timezone=auto'"
        ]
        weatherProc.running = true
    }

    Timer {
        interval: 8000
        running: true
        repeat: false
        onTriggered: {
            if (root._lat === 0 && root._lon === 0) {
                root._geoRaw = ""
                root._weatherRaw = ""
                geoProc.running = true
            }
        }
    }

    function _loadCachedData() {
        temperature  = _cachedTemperature
        feelsLike    = _cachedFeelsLike
        windSpeed    = _cachedWindSpeed
        humidity     = _cachedHumidity
        cityName     = _cachedCityName
        weatherIcon  = _cachedWeatherIcon
        description  = _cachedDescription
        isDay        = _cachedIsDay
        sunrise      = _cachedSunrise
        sunset       = _cachedSunset
        hourlyData   = _cachedHourlyData
        allHourlyData = _cachedAllHourlyData
        dailyData    = _cachedDailyData
    }

    function open() {
        _loadCachedData()
        root.visible = true
    }

    property string sunrise:    "--:--"
    property string sunset:     "--:--"
    property var    hourlyData:    []
    property var    allHourlyData: []   // array of 7 arrays, one per day
    property var    dailyData:     []

    property int selectedHourIndex: 0
    property int selectedDayIndex:  0

    property double _lat:        0
    property double _lon:        0
    property string _geoRaw:     ""
    property string _weatherRaw: ""

    readonly property color accent: root.isDay ? Theme.sky : Theme.accent2

    onVisibleChanged: {
        if (visible) {
            if (_cachedCityName !== "Cargando...") {
                _loadCachedData()
            }
            if (!loading && _cachedCityName === "Cargando...") {
                _startFetch()
            } else if (!loading && !_geoRaw && !_weatherRaw) {
                // Refresh if no fetch in progress and cache is stale
                _startFetch()
            }
        }
    }

    function _startFetch() {
        loading           = true
        _geoRaw           = ""
        _weatherRaw       = ""
        selectedHourIndex = 0
        selectedDayIndex  = 0
        geoProc.running   = true
    }

    function _selectDay(idx) {
        selectedDayIndex  = idx
        selectedHourIndex = 0
        if (allHourlyData.length > idx)
            hourlyData = allHourlyData[idx]
        hourlyList.positionViewAtIndex(0, ListView.Beginning)
    }

    function _periodLabel() {
        var h = new Date().getHours()
        if (h < 6)  return "Madrugada"
        if (h < 12) return "Mañana"
        if (h < 18) return "Tarde"
        return "Noche"
    }

    function _sunProgress() {
        if (root.sunrise === "--:--" || root.sunset === "--:--") return 0.5
        var sp = root.sunrise.split(":")
        var ep = root.sunset.split(":")
        var riseMin = parseInt(sp[0]) * 60 + parseInt(sp[1])
        var setMin  = parseInt(ep[0]) * 60 + parseInt(ep[1])
        var nowMin  = new Date().getHours() * 60 + new Date().getMinutes()
        if (nowMin <= riseMin) return 0
        if (nowMin >= setMin)  return 1
        return (nowMin - riseMin) / (setMin - riseMin)
    }

    // ── WMO helpers ───────────────────────────────────────────────────────
    function wmoIcon(code, day) {
        if (code === 0)  return day ? "☀" : "🌙"
        if (code <= 2)   return day ? "🌤" : "☁"
        if (code === 3)  return "☁"
        if (code <= 49)  return "🌫"
        if (code <= 57)  return "🌦"
        if (code <= 67)  return "🌧"
        if (code <= 77)  return "❄"
        if (code <= 82)  return "🌦"
        if (code <= 86)  return "🌨"
        if (code <= 99)  return "⛈"
        return "🌡"
    }

    function wmoDescription(code) {
        if (code === 0)  return "Despejado"
        if (code === 1)  return "Principalmente despejado"
        if (code === 2)  return "Parcialmente nublado"
        if (code === 3)  return "Nublado"
        if (code <= 49)  return "Niebla"
        if (code <= 55)  return "Llovizna"
        if (code <= 57)  return "Llovizna helada"
        if (code <= 65)  return "Lluvia"
        if (code <= 67)  return "Lluvia helada"
        if (code <= 73)  return "Nieve ligera"
        if (code <= 75)  return "Nieve intensa"
        if (code === 77) return "Granizo"
        if (code <= 82)  return "Chubascos"
        if (code <= 86)  return "Nieve con lluvia"
        if (code <= 99)  return "Tormenta"
        return "Desconocido"
    }

    // ── Background dismiss (only outside the card) ─────────────────────────
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

    // ── Main card ─────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  700
        radius: 16
        color:  Theme.base
        border.color: Theme.surface2
        border.width: 1
        height: mainCol.implicitHeight + 44

        Rectangle {
            anchors.top:              parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 100; height: 2; radius: 1
            color: root.accent
        }

        // (no blocking MouseArea needed — background dismiss checks position)

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
                    onClicked: if (!root.loading) root._startFetch()

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
                        target: root
                        function onSunriseChanged() { sunCanvas.requestPaint() }
                        function onSunsetChanged()  { sunCanvas.requestPaint() }
                        function onIsDayChanged()   { sunCanvas.requestPaint() }
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
                        text: root.weatherIcon; font.pixelSize: 46
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: root.temperature; color: Theme.text
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
                            Text { text: root.windSpeed; color: Theme.text; font.pixelSize: 12 }
                        }
                        Row {
                            spacing: 4
                            Text { text: "💧"; font.pixelSize: 11 }
                            Text { text: root.humidity;  color: Theme.text; font.pixelSize: 12 }
                        }
                        Row {
                            spacing: 4
                            Text { text: "🌡"; font.pixelSize: 11 }
                            Text { text: root.feelsLike; color: Theme.text; font.pixelSize: 12 }
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
                            opacity: parent.active ? 0.8 : 0.3
                        }
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width:  110; height: 158; radius: 10
                        color:  index === root.selectedHourIndex ? Theme.surface1 : Theme.base
                        border.color: index === root.selectedHourIndex ? root.accent : Theme.surface2
                        border.width: index === root.selectedHourIndex ? 1 : 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.selectedHourIndex = index
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top:              parent.top
                            anchors.topMargin:        10
                            spacing: 0
                            width:   parent.width - 16

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:  modelData.time
                                color: index === root.selectedHourIndex ? root.accent : Theme.muted1
                                font.pixelSize: 12; font.bold: index === root.selectedHourIndex
                            }
                            Item { width:1; height:4 }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: wmoIcon(modelData.code, modelData.isDay)
                                font.pixelSize: 20
                            }
                            Item { width:1; height:4 }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Text {
                                    text: Math.round(modelData.temp) + "°"
                                    color: Theme.text; font.pixelSize: 18; font.bold: true
                                    anchors.baseline: feelsLbl.baseline
                                }
                                Text {
                                    id: feelsLbl
                                    text: Math.round(modelData.feels) + "°"
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
                                    Text { text: modelData.hum + "%"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "↑"; color: Theme.accent; font.pixelSize: 9 }
                                    Text { text: Math.round(modelData.wind) + " km/h"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "→"; color: Theme.success; font.pixelSize: 9 }
                                    Text { text: Math.round(modelData.press) + " hPa"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "🌧"; font.pixelSize: 9 }
                                    Text { text: modelData.precip + "%"; color: Theme.muted1; font.pixelSize: 9 }
                                }
                                Row {
                                    spacing: 3
                                    Text { text: "◎"; color: Theme.accent2; font.pixelSize: 9 }
                                    Text { text: modelData.vis.toFixed(1) + " km"; color: Theme.muted1; font.pixelSize: 9 }
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
                            required property var modelData
                            required property int index
                            width:  (parent.width - 6 * 6) / 7
                            height: 104; radius: 10
                            color:  index === root.selectedDayIndex ? Theme.surface1 : Theme.base
                            border.color: index === root.selectedDayIndex ? root.accent : Theme.surface2
                            border.width: index === root.selectedDayIndex ? 1 : 0

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    root._selectDay(index)
                            }

                            Column {
                                anchors.centerIn: parent; spacing: 5

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text:  index === 0 ? "Hoy" : modelData.dayName
                                    color: index === root.selectedDayIndex ? root.accent : Theme.muted1
                                    font.pixelSize: 11; font.bold: index === root.selectedDayIndex
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: wmoIcon(modelData.code, true); font.pixelSize: 24
                                }
                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(modelData.max) + "°"
                                        color: Theme.text; font.pixelSize: 12; font.bold: true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(modelData.min) + "°"
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

    // ── Fetch processes ───────────────────────────────────────────────────
    Process {
        id: geoProc
        command: ["sh", "-c", "curl -s --max-time 6 'http://ip-api.com/json/'"]
        running: false

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._geoRaw += data }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 || !root._geoRaw.trim()) {
                root.cityName = "Sin conexión"; root.loading = false; return
            }
            try {
                var j = JSON.parse(root._geoRaw.trim())
                if (j.status !== "success" || j.lat === undefined || j.lon === undefined) {
                    root.cityName = "Sin ubicación"; root.loading = false; return
                }
                root._lat     = parseFloat(j.lat)
                root._lon     = parseFloat(j.lon)
                var city = j.city || j.regionName || j.country || "Desconocido"
                root.cityName = city
                root._cachedCityName = city
                _fetchWeather()
            } catch(e) {
                root.cityName = "Error geo"; root.loading = false
            }
        }
    }

    Process {
        id: weatherProc
        command: ["sh", "-c", "echo init"]
        running: false

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._weatherRaw += data }
        }

        onExited: (exitCode) => {
            root.loading = false
            if (exitCode !== 0 || !root._weatherRaw.trim()) return
            try {
                var j = JSON.parse(root._weatherRaw.trim())
                var c = j.current
                var tempVal = Math.round(c.temperature_2m)      + "°C"
                var feelsVal = Math.round(c.apparent_temperature) + "°C"
                var windVal = Math.round(c.wind_speed_10m)       + " km/h"
                var humVal = c.relative_humidity_2m             + "%"
                var isDayVal = (c.is_day === 1)
                var iconVal = wmoIcon(c.weather_code, c.is_day === 1)
                var descVal = wmoDescription(c.weather_code)

                // Update current display
                root.temperature = tempVal
                root.feelsLike   = feelsVal
                root.windSpeed   = windVal
                root.humidity    = humVal
                root.isDay       = isDayVal
                root.weatherIcon = iconVal
                root.description = descVal

                // Update cache
                root._cachedTemperature = tempVal
                root._cachedFeelsLike   = feelsVal
                root._cachedWindSpeed   = windVal
                root._cachedHumidity    = humVal
                root._cachedIsDay       = isDayVal
                root._cachedWeatherIcon = iconVal
                root._cachedDescription = descVal

                var srVal = "--:--"
                var ssVal = "--:--"
                if (j.daily && j.daily.sunrise && j.daily.sunrise.length > 0) {
                    var srFull = j.daily.sunrise[0]
                    srVal = srFull.substring(srFull.indexOf("T") + 1)
                    root.sunrise = srVal
                    root._cachedSunrise = srVal
                }
                if (j.daily && j.daily.sunset && j.daily.sunset.length > 0) {
                    var ssFull = j.daily.sunset[0]
                    ssVal = ssFull.substring(ssFull.indexOf("T") + 1)
                    root.sunset = ssVal
                    root._cachedSunset = ssVal
                }

                var nowHour = new Date().getHours()
                var today   = Qt.formatDateTime(new Date(), "yyyy-MM-dd")

                // Build per-day hourly arrays (7 days)
                var allByDay = []
                if (j.hourly && j.hourly.time && j.daily && j.daily.time) {
                    for (var di2 = 0; di2 < j.daily.time.length; di2++) {
                        var dayDate = j.daily.time[di2]   // "yyyy-MM-dd"
                        var dayArr  = []
                        for (var i = 0; i < j.hourly.time.length; i++) {
                            var tStr = j.hourly.time[i]
                            if (tStr.substring(0, 10) !== dayDate) continue
                            var hh = parseInt(tStr.substring(tStr.indexOf("T") + 1, tStr.indexOf("T") + 3))
                            // day 0: skip past hours
                            if (di2 === 0 && dayDate === today && hh < nowHour) continue
                            dayArr.push({
                                time:   tStr.substring(tStr.indexOf("T") + 1),
                                temp:   j.hourly.temperature_2m[i],
                                feels:  j.hourly.apparent_temperature[i],
                                code:   j.hourly.weather_code[i],
                                wind:   j.hourly.wind_speed_10m[i],
                                press:  j.hourly.surface_pressure ? j.hourly.surface_pressure[i] : 0,
                                hum:    j.hourly.relative_humidity_2m[i],
                                vis:    j.hourly.visibility ? (j.hourly.visibility[i] / 1000) : 0,
                                precip: j.hourly.precipitation_probability ? j.hourly.precipitation_probability[i] : 0,
                                isDay:  j.hourly.is_day[i] === 1
                            })
                        }
                        allByDay.push(dayArr)
                    }
                }
                root.allHourlyData    = allByDay
                root._cachedAllHourlyData = allByDay
                root.selectedDayIndex = 0
                root.hourlyData       = allByDay.length > 0 ? allByDay[0] : []
                root._cachedHourlyData = allByDay.length > 0 ? allByDay[0] : []

                var days = ["dom","lun","mar","mié","jue","vie","sáb"]
                var dailyArr = []
                if (j.daily && j.daily.time) {
                    for (var di = 0; di < j.daily.time.length; di++) {
                        var date = new Date(j.daily.time[di] + "T12:00:00")
                        dailyArr.push({
                            dayName: days[date.getDay()],
                            code:    j.daily.weather_code[di],
                            min:     j.daily.temperature_2m_min[di],
                            max:     j.daily.temperature_2m_max[di]
                        })
                    }
                }
                root.dailyData   = dailyArr
                root._cachedDailyData = dailyArr
                root._weatherRaw = ""
                sunCanvas.requestPaint()

            } catch(e) { root.description = "Error parseando" }
        }
    }
}

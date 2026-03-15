import QtQuick
import Quickshell
import Quickshell.Io
import "../Components"

Rectangle {
    id: root

    radius: 8
    color: Theme.surface2
    implicitWidth: weatherRow.implicitWidth + 16
    implicitHeight: 28

    // ── Datos exportados ──────────────────────────────────────────────────
    property string temperature:   "--"
    property string feelsLike:     "--"
    property string windSpeed:     "--"
    property string humidity:      "--"
    property string cityName:      "..."
    property string weatherIcon:   "☁"
    property string description:   "Cargando..."
    property int    weatherCode:   0
    property bool   isDay:         true
    property bool   loaded:        false
    property string sunrise:       "--:--"
    property string sunset:        "--:--"
    property var    hourlyData:    []
    property var    dailyData:     []

    property double _lat: 0
    property double _lon: 0
    property string _geoRaw: ""
    property string _weatherRaw: ""

    signal clicked()

    // ── Accent left border ────────────────────────────────────────────────
    Rectangle {
        width:  3
        height: parent.height * 0.6
        radius: 2
        color:  Theme.sky
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:           parent.left
        anchors.leftMargin:     7
    }

    // ── Contenido ─────────────────────────────────────────────────────────
    Row {
        id: weatherRow
        anchors.centerIn:              parent
        anchors.horizontalCenterOffset: 4
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.weatherIcon
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color:          Theme.text
            font.pixelSize: 13
            font.bold:      true
            text:           root.temperature
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // ── 1. Obtener geolocalización por IP ─────────────────────────────────
    Process {
        id: geoProcess
        command: ["sh", "-c", "curl -s --max-time 6 'http://ip-api.com/json/'"]
        running: true

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._geoRaw += data
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 || !root._geoRaw.trim()) {
                root.description = "Sin conexión"
                retryTimer.start()
                return
            }
            try {
                var j = JSON.parse(root._geoRaw.trim())
                if (j.status !== "success" || j.lat === undefined || j.lon === undefined) {
                    root.description = "Geo sin coords"
                    retryTimer.start()
                    return
                }
                root._lat      = parseFloat(j.lat)
                root._lon      = parseFloat(j.lon)
                root.cityName  = j.city || j.regionName || j.country || "Desconocido"
                root._geoRaw     = ""
                root._weatherRaw = ""
                weatherProcess.command = [
                    "sh", "-c",
                    "curl -s --max-time 8 'https://api.open-meteo.com/v1/forecast" +
                    "?latitude="  + root._lat +
                    "&longitude=" + root._lon +
                    "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day" +
                    "&hourly=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure,relative_humidity_2m,visibility,precipitation_probability,is_day" +
                    "&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset" +
                    "&forecast_days=7&wind_speed_unit=kmh&temperature_unit=celsius&timezone=auto'"
                ]
                weatherProcess.running = true
            } catch(e) {
                root.description = "Error geo"
                retryTimer.start()
            }
        }
    }

    // ── 2. Obtener clima de Open-Meteo ────────────────────────────────────
    Process {
        id: weatherProcess
        command: ["sh", "-c", "echo init"]
        running: false

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root._weatherRaw += data
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 || !root._weatherRaw.trim()) {
                retryTimer.start()
                return
            }
            try {
                var j = JSON.parse(root._weatherRaw.trim())
                var c = j.current
                root.temperature  = Math.round(c.temperature_2m)    + "°"
                root.feelsLike    = Math.round(c.apparent_temperature) + "°C"
                root.windSpeed    = Math.round(c.wind_speed_10m)     + " km/h"
                root.humidity     = c.relative_humidity_2m           + "%"
                root.weatherCode  = c.weather_code
                root.isDay        = (c.is_day === 1)
                root.weatherIcon  = wmoIcon(c.weather_code, c.is_day === 1)
                root.description  = wmoDescription(c.weather_code)
                root.loaded       = true

                // sunrise / sunset
                if (j.daily && j.daily.sunrise && j.daily.sunrise.length > 0) {
                    var srFull = j.daily.sunrise[0]
                    root.sunrise = srFull.substring(srFull.indexOf("T") + 1)
                }
                if (j.daily && j.daily.sunset && j.daily.sunset.length > 0) {
                    var ssFull = j.daily.sunset[0]
                    root.sunset = ssFull.substring(ssFull.indexOf("T") + 1)
                }

                // hourly: next 24h from current hour
                var nowHour = new Date().getHours()
                var today   = Qt.formatDateTime(new Date(), "yyyy-MM-dd")
                var hourlyArr = []
                if (j.hourly && j.hourly.time) {
                    for (var i = 0; i < j.hourly.time.length && hourlyArr.length < 24; i++) {
                        var tStr = j.hourly.time[i]
                        var dd   = tStr.substring(0, 10)
                        var hh   = parseInt(tStr.substring(tStr.indexOf("T") + 1, tStr.indexOf("T") + 3))
                        if (dd === today && hh < nowHour) continue
                        hourlyArr.push({
                            time:  tStr.substring(tStr.indexOf("T") + 1),
                            temp:  j.hourly.temperature_2m[i],
                            feels: j.hourly.apparent_temperature[i],
                            code:  j.hourly.weather_code[i],
                            wind:  j.hourly.wind_speed_10m[i],
                            press: j.hourly.surface_pressure ? j.hourly.surface_pressure[i] : 0,
                            hum:   j.hourly.relative_humidity_2m[i],
                            vis:   j.hourly.visibility ? (j.hourly.visibility[i] / 1000) : 0,
                            precip: j.hourly.precipitation_probability ? j.hourly.precipitation_probability[i] : 0,
                            isDay: j.hourly.is_day[i] === 1
                        })
                    }
                }
                root.hourlyData = hourlyArr

                // daily
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
                root.dailyData = dailyArr

                root._weatherRaw  = ""
            } catch(e) {
                root.description = "Error parseando clima"
                retryTimer.start()
            }
        }
    }

    // Reintento en caso de fallo (30s)
    Timer {
        id: retryTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root._geoRaw     = ""
            root._weatherRaw = ""
            geoProcess.running = true
        }
    }

    Timer {
        interval: 600000
        running:  true
        repeat:   true
        onTriggered: {
            root._geoRaw      = ""
            root._weatherRaw  = ""
            geoProcess.running = true
        }
    }

    // ── WMO helpers ───────────────────────────────────────────────────────
    function wmoIcon(code, day) {
        if (code === 0)          return day ? "☀" : "🌙"
        if (code <= 2)           return day ? "🌤" : "☁"
        if (code === 3)          return "☁"
        if (code <= 49)          return "🌫"
        if (code <= 57)          return "🌦"
        if (code <= 67)          return "🌧"
        if (code <= 77)          return "❄"
        if (code <= 82)          return "🌦"
        if (code <= 86)          return "🌨"
        if (code <= 99)          return "⛈"
        return "🌡"
    }

    function wmoDescription(code) {
        if (code === 0)          return "Despejado"
        if (code === 1)          return "Principalmente despejado"
        if (code === 2)          return "Parcialmente nublado"
        if (code === 3)          return "Nublado"
        if (code <= 49)          return "Niebla"
        if (code <= 55)          return "Llovizna"
        if (code <= 57)          return "Llovizna helada"
        if (code <= 65)          return "Lluvia"
        if (code <= 67)          return "Lluvia helada"
        if (code <= 73)          return "Nieve ligera"
        if (code <= 75)          return "Nieve intensa"
        if (code === 77)         return "Granizo"
        if (code <= 82)          return "Chubascos"
        if (code <= 86)          return "Nieve con lluvia"
        if (code <= 99)          return "Tormenta"
        return "Desconocido"
    }
}

pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    
    // ── Estado ────────────────────────────────────────────────────────────
    property bool loading: true
    property bool hasData: false
    
    property double latitude: 0
    property double longitude: 0
    property bool geoSourceSystem: false
    property string cityName: "Cargando..."
    
    // ── Datos del clima actual ────────────────────────────────────────────
    property double temperature: 0
    property double feelsLike: 0
    property double windSpeed: 0
    property int humidity: 0
    property int weatherCode: 0
    property bool isDay: true
    property string sunrise: "--:--"
    property string sunset: "--:--"
    
    // ── Datos forecast ────────────────────────────────────────────────────
    property var hourlyData: []
    property var dailyData: []
    
    // ── Senales personalizadas ────────────────────────────────────────────
    signal dataReady()
    
    // ── Gate de visibilidad para el timer ────────────────────────────────
    property bool _anyConsumerVisible: false

    // ── Init ──────────────────────────────────────────────────────────────
    Component.onCompleted: {
        weatherProcess.running = true
    }
    
    // ── Children (QtObject has no default property — must declare explicitly) ─
    property Timer _refreshTimer: Timer {
        interval: 600000
        running: root._anyConsumerVisible
        repeat: true
        onTriggered: {
            if (root.latitude !== 0 && root.longitude !== 0) {
                root.fetchWeather()
            }
        }
    }
    
    // ── Proceso único ─────────────────────────────────────────────────────
    // qs-helper weather resuelve las coordenadas (args > preferencias >
    // geo-IP) y consulta Open-Meteo con cache en disco. Un solo proceso
    // reemplaza los dos curls (geo + weather) anteriores.
    property Process _weatherProcess: Process {
        id: weatherProcess
        command: [Paths.scripts + "/qs-helper/qs-helper", "weather"]
        running: false
        
        stdout: StdioCollector {
            id: weatherCollector
        }
        
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            root.loading = false
            if (exitCode !== 0) {
                root.cityName = "Sin conexion"
            } else {
                root._handleWeatherResponse(weatherCollector.text)
            }
        }
        // qmllint enable signal-handler-parameters
    }
    
    // ── Funciones publicas ───────────────────────────────────────────────
    function fetchWeather() {
        loading = true
        weatherProcess.running = true
    }
    
    function _handleWeatherResponse(raw) {
        if (!raw.trim()) {
            root.cityName = "Sin conexion"
            return
        }
        
        try {
            var j = JSON.parse(raw.trim())
            
            var g = j.geo
            if (g && g.lat !== undefined && g.lon !== undefined) {
                root.latitude = parseFloat(g.lat)
                root.longitude = parseFloat(g.lon)
                root.geoSourceSystem = true
                root.cityName = g.city || "Desconocido"
            }
            
            var c = j.current
            if (!c) return
            
            root.temperature = c.temperature_2m
            root.feelsLike = c.apparent_temperature
            root.windSpeed = c.wind_speed_10m
            root.humidity = c.relative_humidity_2m
            root.weatherCode = c.weather_code
            root.isDay = (c.is_day === 1)
            
            if (j.daily && j.daily.sunrise && j.daily.sunrise.length > 0) {
                var srFull = j.daily.sunrise[0]
                root.sunrise = srFull.substring(srFull.indexOf("T") + 1)
            }
            if (j.daily && j.daily.sunset && j.daily.sunset.length > 0) {
                var ssFull = j.daily.sunset[0]
                root.sunset = ssFull.substring(ssFull.indexOf("T") + 1)
            }
            
            var nowHour = new Date().getHours()
            var today = Qt.formatDateTime(new Date(), "yyyy-MM-dd")
            var hourlyArr = []
            
            if (j.hourly && j.hourly.time) {
                for (var i = 0; i < j.hourly.time.length && hourlyArr.length < 24; i++) {
                    var tStr = j.hourly.time[i]
                    var dd = tStr.substring(0, 10)
                    var hh = parseInt(tStr.substring(tStr.indexOf("T") + 1, tStr.indexOf("T") + 3))
                    if (dd === today && hh < nowHour) continue
                    hourlyArr.push({
                        time: tStr.substring(tStr.indexOf("T") + 1),
                        temp: j.hourly.temperature_2m[i],
                        feels: j.hourly.apparent_temperature[i],
                        code: j.hourly.weather_code[i],
                        wind: j.hourly.wind_speed_10m[i],
                        press: j.hourly.surface_pressure ? j.hourly.surface_pressure[i] : 0,
                        hum: j.hourly.relative_humidity_2m[i],
                        vis: j.hourly.visibility ? (j.hourly.visibility[i] / 1000) : 0,
                        precip: j.hourly.precipitation_probability ? j.hourly.precipitation_probability[i] : 0,
                        isDay: j.hourly.is_day[i] === 1
                    })
                }
            }
            root.hourlyData = hourlyArr
            
            var days = ["dom","lun","mar","mie","jue","vie","sab"]
            var dailyArr = []
            if (j.daily && j.daily.time) {
                for (var di = 0; di < j.daily.time.length; di++) {
                    var date = new Date(j.daily.time[di] + "T12:00:00")
                    dailyArr.push({
                        dayName: days[date.getDay()],
                        code: j.daily.weather_code[di],
                        min: j.daily.temperature_2m_min[di],
                        max: j.daily.temperature_2m_max[di]
                    })
                }
            }
            root.dailyData = dailyArr
            
            root.hasData = true
            root.dataReady()
            
        } catch(e) {
            console.log("WeatherProvider: Parse error:", e)
        }
    }
}

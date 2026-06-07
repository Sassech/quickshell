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
    
    // ── Raw buffers ───────────────────────────────────────────────────────
    property string _geoRaw: ""
    property string _weatherRaw: ""
    
    // ── Senales personalizadas ────────────────────────────────────────────
    signal dataReady()
    signal statusChanged()
    
    // ── Init Timer ────────────────────────────────────────────────────────
    Component.onCompleted: {
        loading = true
        statusChanged()
        _geoRaw = ""
        geoProcess.running = true
    }
    
    // ── Children (QtObject has no default property — must declare explicitly) ─
    property Timer _refreshTimer: Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: {
            if (root.latitude !== 0 && root.longitude !== 0) {
                root.fetchWeather()
            }
        }
    }
    
    property Process _geoProcess: Process {
        id: geoProcess
        command: ["curl", "-s", "--max-time", "6", "http://ip-api.com/json/"]
        
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._geoRaw += data }
        }
        
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            root.loading = false
            root.statusChanged()
            
            if (exitCode !== 0 || !root._geoRaw.trim()) {
                root.cityName = "Sin conexion"
                return
            }
            try {
                var j = JSON.parse(root._geoRaw.trim())
                if (j.status !== "success" || j.lat === undefined || j.lon === undefined) {
                    root.cityName = "Sin ubicacion"
                    return
                }
                root.latitude = parseFloat(j.lat)
                root.longitude = parseFloat(j.lon)
                root.cityName = j.city || j.regionName || j.country || "Desconocido"
                root._geoRaw = ""
                root.fetchWeather()
            } catch(e) {
                root.cityName = "Error geo"
            }
        }
        // qmllint enable signal-handler-parameters
    }
    
    property Process _weatherProcess: Process {
        id: weatherProcess
        command: ["sh", "-c", "echo init"]
        running: false
        
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._weatherRaw += data }
        }
        
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            root.loading = false
            root.statusChanged()
            
            if (exitCode !== 0 || !root._weatherRaw.trim()) {
                return
            }
            
            try {
                var j = JSON.parse(root._weatherRaw.trim())
                var c = j.current
                
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
                root._weatherRaw = ""
                root.dataReady()
                
            } catch(e) {
                console.log("WeatherProvider: Parse error:", e)
            }
        }
        // qmllint enable signal-handler-parameters
    }
    
    // ── Funciones publicas ───────────────────────────────────────────────
    function fetchWeather() {
        if (latitude === 0 || longitude === 0) return
        loading = true
        statusChanged()
        _weatherRaw = ""
        
        var url = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=" + latitude +
            "&longitude=" + longitude +
            "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day" +
            "&hourly=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure,relative_humidity_2m,visibility,precipitation_probability,is_day" +
            "&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset" +
            "&forecast_days=7&wind_speed_unit=kmh&temperature_unit=celsius&timezone=auto"
        
        weatherProcess.command = ["curl", "-s", "--max-time", "10", url]
        weatherProcess.running = true
    }
    
    function fallbackToIpGeo() {
        if (latitude !== 0) return
        loading = true
        statusChanged()
        _geoRaw = ""
        geoProcess.running = true
    }
}

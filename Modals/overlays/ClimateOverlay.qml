// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Io
import "../../Components"

// ClimateOverlay — glanceable + full weather (migrated from WeatherModal).
// Reuses WeatherProvider singleton; tiles degrade to "—" when offline.
// Incluye búsqueda de ciudad, hourly 24h, daily 7d y arco solar.
// Material-you (Theme), gobernado por OverlaysManager entry "climate".
OverlayWindow {
    id: root

    entryId:        "climate"
    corner:         "bottom-right"
    overlayWidth:   700
    restingOpacity: 0.95
    animInMs:       250
    animOutMs:      250
    autoHideMs:     0
    borderColor:    Theme.surface2
    showAccent:     false

    // Keyboard focus solo en modo búsqueda (para TextInput)
    WlrLayershell.keyboardFocus: root._searchMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
        WeatherProvider.climateOverlayVisible = visible
        if (visible && !WeatherProvider.hasData && !WeatherProvider.loading) {
            WeatherProvider.fetchWeather()
        }
        if (!visible) {
            root._searchMode = false
            root._searchQuery = ""
            root._searchResults = []
            root._searching = false
            root._searchStack = []
        }
    }

    WeatherHelpers {
        id: weatherHelpers
    }

    // — Provider bindings (compat con WeatherModal) —
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

    function wmoIcon(code, day) { return weatherHelpers.wmoIcon(code, day) }
    function wmoDescription(code) { return weatherHelpers.wmoDescription(code) }

    // — UI state —
    property int selectedHourIndex: 0
    property int selectedDayIndex: 0
    property bool _searchMode: false

    readonly property bool _offline: WeatherProvider.cityName === "Sin conexion"
    readonly property string _cityText: root._offline ? "Sin conexión" : WeatherProvider.cityName
    readonly property color _selAccent: isDay ? Theme.sky : Theme.accent2

    function _windCompass(deg) {
        if (deg === undefined || deg === null || deg < 0 || isNaN(Number(deg))) return ""
        var dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        return dirs[Math.round(Number(deg) / 22.5) % 16]
    }

    readonly property string tempText: !WeatherProvider.hasData ? "—"
        : Math.round(WeatherProvider.temperature) + "°"
    readonly property string feelsText: !WeatherProvider.hasData ? "—"
        : Math.round(WeatherProvider.feelsLike) + "°"
    readonly property string humText: !WeatherProvider.hasData ? "—"
        : WeatherProvider.humidity + "%"
    readonly property string minMaxText: {
        if (!WeatherProvider.hasData) return "—"
        var d = WeatherProvider.dailyData
        if (!d || d.length === 0 || d[0].min === undefined || d[0].max === undefined) return "—"
        return Math.round(d[0].min) + "° / " + Math.round(d[0].max) + "°"
    }
    readonly property string windText: {
        if (!WeatherProvider.hasData) return "—"
        var compass = root._windCompass(WeatherProvider.windDirection)
        var spd = Math.round(WeatherProvider.windSpeed) + " km/h"
        return compass.length > 0 ? spd + " " + compass : spd
    }
    readonly property string pressureText: {
        if (!WeatherProvider.hasData || WeatherProvider.pressureMsl < 0) return "—"
        return Math.round(WeatherProvider.pressureMsl) + " hPa"
    }
    readonly property string precipText: {
        if (!WeatherProvider.hasData) return "—"
        var hasMm = WeatherProvider.precipitation >= 0
        var prob = -1
        var h = WeatherProvider.hourlyData
        if (h && h.length > 0 && h[0].precip !== undefined && !isNaN(Number(h[0].precip))) prob = Number(h[0].precip)
        if (!hasMm && prob < 0) return "—"
        var mm = hasMm ? (Math.round(WeatherProvider.precipitation * 10) / 10) + " mm" : "—"
        return prob >= 0 ? mm + " · " + Math.round(prob) + "%" : mm
    }
    readonly property string uvText: {
        if (!WeatherProvider.hasData || WeatherProvider.uvIndex < 0) return "—"
        return (Math.round(WeatherProvider.uvIndex * 10) / 10) + ""
    }
    readonly property string sunText: {
        if (!WeatherProvider.hasData) return "—"
        var sr = WeatherProvider.sunrise
        var ss = WeatherProvider.sunset
        if ((!sr || sr === "--:--") && (!ss || ss === "--:--")) return "—"
        return (sr === "--:--" ? "—" : sr) + " / " + (ss === "--:--" ? "—" : ss)
    }

    function refresh() {
        WeatherProvider.fetchWeather()
    }

    function _selectDay(idx) {
        selectedDayIndex = idx
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

    // — Búsqueda de ciudad —
    property string _searchQuery: ""
    property var _searchResults: []
    property bool _searching: false
    property string _searchBuf: ""
    property var _searchStack: []

    Process {
        id: searchProc
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._searchBuf += data }
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            root._searching = false
            if (exitCode !== 0 || !root._searchBuf.trim()) {
                root._searchResults = []
                return
            }
            try {
                var arr = JSON.parse(root._searchBuf.trim())
                root._searchResults = Array.isArray(arr) ? arr : []
            } catch(e) {
                root._searchResults = []
            }
        }
        // qmllint enable signal-handler-parameters
    }

    function doSearch(query) {
        var q = query.trim()
        if (q === "") { root._searchResults = []; return }
        root._searchBuf = ""
        root._searching = true
        root._searchResults = []
        searchProc.command = [Paths.scripts + "/qs-helper/qs-helper", "weather-search", q]
        searchProc.running = true
    }

    function drillDown(refinedQuery) {
        var stack = root._searchStack.slice()
        stack.push(root._searchQuery)
        root._searchStack = stack
        root._searchQuery = refinedQuery
        root.doSearch(refinedQuery)
    }

    function searchBack() {
        var stack = root._searchStack.slice()
        if (stack.length === 0) return
        var prev = stack.pop()
        root._searchStack = stack
        root._searchQuery = prev
        root.doSearch(prev)
    }

    Process {
        id: writePrefsProc
        running: false
    }

    function _savePrefs(lat, lon, cityName_, countryName, auto_) {
        writePrefsProc.command = [
            Paths.scripts + "/qs-helper/qs-helper",
            "prefs-weather-set",
            String(lat), String(lon),
            cityName_, countryName,
            auto_ ? "true" : "false"
        ]
        writePrefsProc.running = true
    }

    function selectCity(lat, lon, cityName_, countryName) {
        root._searchResults = []
        root._searchMode = false
        root._searchQuery = ""
        root._searchStack = []
        root._savePrefs(lat, lon, cityName_, countryName, false)
        WeatherProvider.fetchWeather()
    }

    function useAutoLocation() {
        root._searchResults = []
        root._searchMode = false
        root._searchQuery = ""
        root._searchStack = []
        root._savePrefs(0, 0, "", "", true)
        WeatherProvider.fetchWeather()
    }

    // — Contenido principal (slot → contentArea) —

    // X close button (absolute, outside columns for consistent position)
    MouseArea {
        id: closeBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 20; height: 20
        cursorShape: Qt.PointingHandCursor
        z: 10
        visible: !root._searchMode
        onClicked: {
            var e = OverlaysManager.get("climate")
            if (e) e.enabled = false
        }
        Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted3; font.pixelSize: 12 }
    }

    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 18
        visible: !root._searchMode
        opacity: root._searchMode ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // Row 1: city + edit city + refresh (period label quitado)
        Item {
            width: parent.width; height: 18

            // city name in center area if space allows (truncated)
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 120)
                text: root._cityText; color: Theme.muted2; font.pixelSize: 11
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: editCityBtn
                anchors.right: parent.right
                anchors.rightMargin: 52
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root._searchMode = true
                    root._searchResults = []
                    root._searchQuery = ""
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰏫"
                    color: editCityBtn.containsMouse ? root._selAccent : Theme.muted3
                    font.pixelSize: 14
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            MouseArea {
                anchors.right: parent.right
                anchors.rightMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                cursorShape: root.loading ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!root.loading) root.refresh()

                Text {
                    anchors.centerIn: parent
                    text: "⟳"
                    color: root.loading ? root._selAccent : Theme.muted3
                    font.pixelSize: 16
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 1200
                        loops: Animation.Infinite
                        running: root.loading
                    }
                }
            }
        }

        // Sun arc
        Item {
            width: parent.width; height: 130

            Canvas {
                id: sunCanvas
                anchors.fill: parent
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
                anchors.left: parent.left
                anchors.leftMargin: parent.width / 2 - (parent.height - 18) * 0.92 - 2
                text: "E"; color: Theme.muted3; font.pixelSize: 11
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: "S"; color: Theme.muted3; font.pixelSize: 11
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: parent.width / 2 - (parent.height - 18) * 0.92 - 2
                text: "W"; color: Theme.muted3; font.pixelSize: 11
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: parent.width / 2 - (parent.height - 18) * 0.92 + 14
                text: "☀ " + root.sunrise; color: Theme.warning; font.pixelSize: 10
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: parent.width / 2 - (parent.height - 18) * 0.92 + 14
                text: "🌙 " + root.sunset; color: Theme.accent2; font.pixelSize: 10
            }
        }

        // Current summary — distribuido a lo largo (no apilado a la derecha)
        Column {
            id: summaryItem
            width: parent.width
            spacing: 12

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

            // Métricas a lo largo — fila horizontal distribuida, sin cajas, con iconos
            Flow {
                id: rightCol
                width: parent.width
                spacing: 18

                Row { spacing: 4; Text { text: "↑"; color: Theme.warning; font.pixelSize: 12 } Text { text: Math.round(root.currentWeather.windSpeed) + " km/h"; color: Theme.text; font.pixelSize: 11 } }
                Row { spacing: 4; Text { text: "💧"; font.pixelSize: 11; color: Theme.muted1 } Text { text: root.currentWeather.humidity + "%"; color: Theme.text; font.pixelSize: 11 } }
                Row { spacing: 4; Text { text: "🌡"; font.pixelSize: 11; color: Theme.muted1 } Text { text: Math.round(root.currentWeather.feelsLike) + "°"; color: Theme.text; font.pixelSize: 11 } }
                Row { spacing: 4; Text { text: "📅"; font.pixelSize: 11; color: Theme.muted1 } Text { text: root.minMaxText; font.pixelSize: 11; color: Theme.text } }
                Row { spacing: 4; Text { text: "→"; font.pixelSize: 11; color: Theme.success } Text { text: root.pressureText; font.pixelSize: 11; color: Theme.text } }
                Row { spacing: 4; Text { text: "🌧"; font.pixelSize: 11 } Text { text: root.precipText; font.pixelSize: 11; color: Theme.text } }
                Row { spacing: 4; Text { text: "☀"; font.pixelSize: 11; color: Theme.warning } Text { text: root.uvText; font.pixelSize: 11; color: Theme.text } }
                Row { spacing: 4; Text { text: "🌅"; font.pixelSize: 11; color: Theme.warning } Text { text: root.sunText; font.pixelSize: 11; color: Theme.text } }
            }
        }

        // Offline indicator
        Text {
            width: parent.width
            visible: root._offline
            wrapMode: Text.WordWrap
            text: "Sin conexión — mostrando últimos valores."
            font.pixelSize: 10
            color: Theme.warning
        }

        Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

        // Hourly forecast
        Column {
            width: parent.width; spacing: 10

            Text {
                text: "Previsión horaria"; color: Theme.text
                font.pixelSize: 13; font.bold: true
            }

            ListView {
                id: hourlyList
                width: parent.width
                height: 168
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: root.hourlyData

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitHeight: 3; radius: 2
                        color: root._selAccent
                        opacity: 0.6
                    }
                }

                delegate: Rectangle {
                    id: hourlyDelegate
                    required property var modelData
                    required property int index
                    width: 110; height: 158; radius: 10
                    color: hourlyDelegate.index === root.selectedHourIndex ? Theme.surface1 : Theme.cardBg3
                    border.color: hourlyDelegate.index === root.selectedHourIndex ? root._selAccent : Theme.surface2
                    border.width: hourlyDelegate.index === root.selectedHourIndex ? 1 : 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedHourIndex = hourlyDelegate.index
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        spacing: 0
                        width: parent.width - 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hourlyDelegate.modelData.time
                            color: hourlyDelegate.index === root.selectedHourIndex ? root._selAccent : Theme.muted1
                            font.pixelSize: 12; font.bold: hourlyDelegate.index === root.selectedHourIndex
                        }
                        Item { width: 1; height: 4 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.wmoIcon(hourlyDelegate.modelData.code, hourlyDelegate.modelData.isDay)
                            font.pixelSize: 20
                        }
                        Item { width: 1; height: 4 }

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

                        Item { width: 1; height: 6 }

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

        // Daily forecast
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
                        width: (parent.width - 6 * 6) / 7
                        height: 104; radius: 10
                        color: dailyDelegate.index === root.selectedDayIndex ? Theme.surface1 : Theme.cardBg3
                        border.color: dailyDelegate.index === root.selectedDayIndex ? root._selAccent : Theme.surface2
                        border.width: dailyDelegate.index === root.selectedDayIndex ? 1 : 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._selectDay(dailyDelegate.index)
                        }

                        Column {
                            anchors.centerIn: parent; spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dailyDelegate.index === 0 ? "Hoy" : dailyDelegate.modelData.dayName
                                color: dailyDelegate.index === root.selectedDayIndex ? root._selAccent : Theme.muted1
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

    // — Vista de búsqueda de ciudad —
    Column {
        id: searchCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 14
        visible: root._searchMode
        opacity: root._searchMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Item {
            width: parent.width; height: 22

            MouseArea {
                id: backBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (root._searchStack.length > 0) {
                        root.searchBack()
                    } else {
                        root._searchMode = false
                        root._searchResults = []
                        root._searchQuery = ""
                        root._searchStack = []
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "←"
                    color: backBtn.containsMouse ? root._selAccent : Theme.muted2
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            Text {
                anchors.centerIn: parent
                text: root._searchStack.length > 0
                    ? "Explorando: " + root._searchStack[root._searchStack.length - 1]
                    : "Cambiar ciudad"
                font.pixelSize: 14
                font.bold: root._searchStack.length === 0
                color: root._searchStack.length > 0 ? Theme.muted1 : Theme.text
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        Rectangle {
            id: searchFieldRect
            width: parent.width
            height: 36
            radius: 10
            color: Theme.surface2
            border.color: searchInput.activeFocus ? root._selAccent : Theme.surface3
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 4
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍋"
                    font.pixelSize: 14
                    color: Theme.muted3
                }

                TextInput {
                    id: searchInput
                    width: parent.width - 50
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 13
                    color: Theme.text
                    clip: true
                    text: root._searchQuery
                    onTextChanged: root._searchQuery = text
                    onAccepted: root.doSearch(text)
                    enabled: !root._searching

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text === "" && !parent.activeFocus
                        text: "Buscar ciudad..."
                        font.pixelSize: 13
                        color: Theme.muted3
                    }
                }
            }

            Connections {
                target: root
                function on_SearchModeChanged() {
                    if (root._searchMode) {
                        searchInput.forceActiveFocus()
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                id: searchActionBtn
                width: (parent.width - 8) / 2
                height: 32
                radius: 8
                color: searchBtnArea.containsMouse && !root._searching
                    ? Theme.surface4 : Theme.surface2
                opacity: root._searching ? 0.5 : 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: root._searching ? "Buscando..." : "Buscar"
                    font.pixelSize: 12
                    color: Theme.text
                }
                MouseArea {
                    id: searchBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root._searching ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root._searching
                    onClicked: root.doSearch(root._searchQuery)
                }
            }

            Rectangle {
                id: autoLocBtn
                width: (parent.width - 8) / 2
                height: 32
                radius: 8
                color: autoLocArea.containsMouse ? Theme.surface4 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "Usar geo-IP"
                    font.pixelSize: 12
                    color: Theme.muted1
                }
                MouseArea {
                    id: autoLocArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.useAutoLocation()
                }
            }
        }

        ListView {
            id: searchResultsList
            width: parent.width
            height: Math.min(root._searchResults.length, 6) * 40
            visible: root._searchResults.length > 0
            clip: true
            model: root._searchResults
            spacing: 3

            delegate: Rectangle {
                id: resRow
                required property var modelData
                required property int index

                readonly property bool isConcrete: resRow.modelData.region !== undefined
                                                && resRow.modelData.region !== ""

                width: searchResultsList.width
                height: 36
                radius: 8
                color: resArea.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 80 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: resRow.isConcrete ? "󰍉" : "󰍋"
                        font.pixelSize: 13
                        color: resRow.isConcrete ? root._selAccent : Theme.muted2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60
                        text: {
                            if (resRow.isConcrete) {
                                return resRow.modelData.name + " · "
                                     + resRow.modelData.region + " · "
                                     + (resRow.modelData.country || "")
                            } else {
                                return resRow.modelData.name + " · "
                                     + (resRow.modelData.country || "")
                            }
                        }
                        font.pixelSize: 12
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !resRow.isConcrete
                        text: "Explorar →"
                        font.pixelSize: 10
                        color: Theme.muted3
                    }
                }

                MouseArea {
                    id: resArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (resRow.isConcrete) {
                            root.selectCity(
                                resRow.modelData.lat,
                                resRow.modelData.lon,
                                resRow.modelData.name,
                                resRow.modelData.country || ""
                            )
                        } else {
                            root.drillDown(resRow.modelData.name + " " + (resRow.modelData.country || ""))
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: !root._searching && root._searchQuery !== "" && root._searchResults.length === 0
            text: "Sin resultados. Probá con otra búsqueda."
            font.pixelSize: 11
            color: Theme.muted3
            horizontalAlignment: Text.AlignHCenter
        }

        Item { width: 1; height: 4 }
    }
}

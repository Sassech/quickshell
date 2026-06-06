//@ pragma UseQApplication
// @ pragma ComponentBehavior:Bound  // TODO: activar cuando Quickshell lo soporte

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import "Components"
import "Modals"

ShellRoot {
    id: root

    // ── Shared paths (resolved via Paths singleton) ──────────────────────
    property string _scriptsPath: Paths.scripts
    property string _configPath:  Paths.config
    // ════════════════════════════════════════════════════════════════════════
    // ── Python Backend — single process feeding all system data ──────────
    // ════════════════════════════════════════════════════════════════════════
    Process {
        id: backendProcess
        command: ["python3", root._scriptsPath + "/quickshell_backend.py"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (!line) return
                try {
                    SysData.dispatch(JSON.parse(line))
                } catch(e) {}
            }
        }

        onExited: function(code) {
            console.log("[Backend] exited with code " + code + " — restarting in 3s")
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: backendProcess.running = true
    }

    // ── Notification policy config ─────────────────────────────────────────
    property var _categoryModes: ({
        media: "silent",
        system: "popup",
        critical: "popup",
        volume: "osd",
        brightness: "osd",
        network: "popup",
        messages: "popup",
        battery: "popup"
    })
    property var _mediaApps: [
        "spotify", "rmpc", "mpd", "music player daemon", "mpv", "vlc",
        "lollypop", "rhythmbox", "clementine", "audacious", "cmus", "amberol"
    ]
    property var _mediaPhrases: [
        "now playing", "reproduciendo", "track changed", "song changed"
    ]
    property var _messageApps: [
        "telegram", "discord", "slack", "signal", "whatsapp", "thunderbird"
    ]
    property var _networkApps: [
        "networkmanager", "nm-applet", "nm-tray", "blueman"
    ]
    property var _networkPhrases: [
        "wifi", "network", "ethernet", "vpn", "bluetooth", "conectado", "desconectado"
    ]

    // ── Helpers ───────────────────────────────────────────────
    function getScreenFromMonName(monName) {
        const name = monName.trim()
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i]
            }
        }
        return Quickshell.screens[0]
    }

    function mkFifoCmd(fifoPath) {
        const rawPath = String(fifoPath ?? "")
        const safePath = rawPath.replace(/'/g, "'\"'\"'")
        return [
            "bash", "-c",
            "[ -p '" + safePath + "' ] || { rm -f '" + safePath + "'; mkfifo '" + safePath + "'; }; " +
            "exec 3<>'" + safePath + "'; " +
            "while IFS= read -r line <&3; do printf '%s\\n' \"$line\"; done"
        ]
    }

    function fifoScreenReader(monName, broadcaster) {
        const name = (monName ?? "").trim()
        const targetScreen = name.length > 0
            ? root.getScreenFromMonName(name)
            : Quickshell.screens[0]
        if (typeof broadcaster === "function") {
            broadcaster(targetScreen)
        }
    }

    function _containsAny(text, needles) {
        const value = (text ?? "").toLowerCase()
        for (var i = 0; i < needles.length; i++) {
            const needle = needles[i]
            const idx = value.indexOf(needle)
            if (idx === -1) continue
            const beforeOk = idx === 0 || !(/[a-z0-9]/.test(value.charAt(idx - 1)))
            const afterOk  = idx + needle.length >= value.length || !(/[a-z0-9]/.test(value.charAt(idx + needle.length)))
            if (beforeOk && afterOk) return true
        }
        return false
    }

    function isMediaNotification(notification) {
        const appName = (notification.appName ?? "").toLowerCase()
        const summary = (notification.summary ?? "").toLowerCase()
        const body = (notification.body ?? "").toLowerCase()

        return _containsAny(appName, root._mediaApps)
            || _containsAny(summary, root._mediaPhrases)
            || _containsAny(body, root._mediaPhrases)
    }

    function classifyExternalNotification(notification, urgent) {
        if (urgent) return "critical"

        const appName = (notification.appName ?? "").toLowerCase()
        const summary = (notification.summary ?? "").toLowerCase()
        const body = (notification.body ?? "").toLowerCase()

        if (isMediaNotification(notification)) return "media"
        if (_containsAny(appName, root._messageApps)) return "messages"

        if (_containsAny(appName, root._networkApps)
                || _containsAny(summary, root._networkPhrases)
                || _containsAny(body, root._networkPhrases)) {
            return "network"
        }

        return "system"
    }

    function _sanitizePolicyMode(value, fallback) {
        const mode = (value ?? "").toLowerCase().trim()
        if (mode === "popup" || mode === "osd" || mode === "silent") return mode
        return fallback
    }

    function getCategoryMode(category, fallbackMode) {
        const fallback = _sanitizePolicyMode(fallbackMode, "popup")
        const configured = root._categoryModes[category]
        return _sanitizePolicyMode(configured, fallback)
    }

    function shouldEmitInternal(category, expectedMode, fallbackMode) {
        return getCategoryMode(category, fallbackMode) === expectedMode
    }

    function _normalizeStringArray(values) {
        if (!Array.isArray(values)) return []
        var out = []
        for (var i = 0; i < values.length; i++) {
            const raw = values[i]
            if (raw === null || raw === undefined) continue
            const value = String(raw).toLowerCase().trim()
            if (value.length > 0) out.push(value)
        }
        return out
    }

    function _mergeCategoryModes(modeMap) {
        const next = {
            media: root.getCategoryMode("media", "silent"),
            system: root.getCategoryMode("system", "popup"),
            critical: root.getCategoryMode("critical", "popup"),
            volume: root.getCategoryMode("volume", "osd"),
            brightness: root.getCategoryMode("brightness", "osd"),
            network: root.getCategoryMode("network", "popup"),
            messages: root.getCategoryMode("messages", "popup"),
            battery: root.getCategoryMode("battery", "popup")
        }

        if (!modeMap || typeof modeMap !== "object") {
            root._categoryModes = next
            return
        }

        const keys = ["media", "system", "critical", "volume", "brightness", "network", "messages", "battery"]
        for (var i = 0; i < keys.length; i++) {
            const key = keys[i]
            if (Object.prototype.hasOwnProperty.call(modeMap, key)) {
                next[key] = root._sanitizePolicyMode(modeMap[key], next[key])
            }
        }

        root._categoryModes = next
    }

    function loadNotificationConfig() {
        notifConfigProc.command = [
            "bash", "-c",
            "cat \"" + root._configPath + "/notifications.json\" 2>/dev/null || echo '{\"categoryModes\":{},\"showMediaPopups\":false,\"mediaApps\":[],\"mediaPhrases\":[]}'"
        ]
        notifConfigProc.running = true
    }

    Process {
        id: notifConfigProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const payload = data.trim()
                if (payload.length === 0) return

                try {
                    const cfg = JSON.parse(payload)
                    root._mergeCategoryModes(cfg.categoryModes)

                    if (cfg.showMediaPopups === true
                            && (!cfg.categoryModes || cfg.categoryModes.media === undefined)) {
                        root._categoryModes.media = "popup"
                    }

                    const mediaApps = root._normalizeStringArray(cfg.mediaApps)
                    if (mediaApps.length > 0) root._mediaApps = mediaApps

                    const mediaPhrases = root._normalizeStringArray(cfg.mediaPhrases)
                    if (mediaPhrases.length > 0) root._mediaPhrases = mediaPhrases
                } catch (e) {
                    console.log("[Notifications] Config inválida, usando defaults")
                }
            }
        }
    }

    // ── Signals ───────────────────────────────────────────────
    signal broadcastNotify(string title, string body, string icon, bool active, bool isMedia)
    signal broadcastCloseAll(var screen)
    signal broadcastWeather(var screen)





    signal broadcastClipboard(var screen)
    signal broadcastSpotlight(var screen)
    signal broadcastWallpaperPicker(var screen)
    signal broadcastOpenFolderBrowser(var screen, string initialPath)
    signal broadcastFolderResult(var screen, string path)
    signal broadcastOverview(var screen)
    signal broadcastLanguage(var screen)
    signal broadcastWifi(var screen)
    signal broadcastBluetooth(var screen)
    signal broadcastAudio(var screen)

    signal broadcastBrightness(int pct)
    signal broadcastVolume()
    signal broadcastClock(var screen)
    signal broadcastControlCenter(var screen)
    signal broadcastScreenshot(var screen)
    signal broadcastClipboardCount(int n)

    // ── Top Bar ──────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        TopBar {
            id: topBarInst
            property var modelData
            screen: modelData
            onWeatherClicked:        screen => root.broadcastWeather(screen)
            onClipboardClicked:      screen => root.broadcastClipboard(screen)
            onClockClicked:          screen => root.broadcastClock(screen)
            onControlCenterClicked:  screen => root.broadcastControlCenter(screen)
            Connections {
                target: root
                // Actualiza el badge del ClipboardWidget sin timer de polling
                function onBroadcastClipboardCount(n) { topBarInst.updateClipboardCount(n) }
            }
        }
    }

    // ── Bottom Bar ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        BottomBar {
            property var modelData
            screen: modelData
            onLanguageClicked:   screen => root.broadcastLanguage(screen)
            onWifiClicked:       screen => root.broadcastWifi(screen)
            onBluetoothClicked:  screen => root.broadcastBluetooth(screen)

        }
    }


    // ── CLOCK MODAL ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        ClockModal {
            id: clockModalInst
            property var modelData
            targetScreen: modelData
            notifModel: notifHistory
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (clockModalInst.modelData === screen) clockModalInst.visible = false
                }
                function onBroadcastClock(screen) {
                    if (clockModalInst.modelData !== screen) return
                    var was = clockModalInst.visible
                    root.broadcastCloseAll(screen)
                    clockModalInst.visible = !was
                }
            }
        }
    }

    // ── WEATHER MODAL ─────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        WeatherModal {
            id: weatherModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (weatherModalInst.modelData === screen) weatherModalInst.visible = false
                }
                function onBroadcastWeather(screen) {
                    if (weatherModalInst.modelData !== screen) return
                    var was = weatherModalInst.visible
                    root.broadcastCloseAll(screen)
                    weatherModalInst.visible = !was
                }
            }
        }
    }

    // ── CLIPBOARD MODAL ───────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        ClipboardModal {
            id: clipboardModalInst
            property var modelData
            screen: modelData
            // Propaga el conteo actualizado al widget del topbar (elimina timer 30s)
            onCountChanged: n => root.broadcastClipboardCount(n)
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (clipboardModalInst.modelData === screen) clipboardModalInst.visible = false
                }
                function onBroadcastClipboard(screen) {
                    if (clipboardModalInst.modelData !== screen) return
                    var was = clipboardModalInst.visible
                    root.broadcastCloseAll(screen)
                    clipboardModalInst.visible = !was
                }
            }
        }
    }

    // ── CLIPBOARD FIFO (SUPER+V) ──────────────────────────────────────────
    Process {
        id: clipboardFifo
        running: true
        command: root.mkFifoCmd("/tmp/qs-clipboard")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => root.fifoScreenReader(monName, root.broadcastClipboard)
        }
        onExited: function(code) {
            console.log("[FIFO] clipboard exited (" + code + "), restarting")
            clipboardFifo.running = true
        }
    }

    // ── WALLPAPER PICKER FIFO (SUPER+Y) ───────────────────────────────────
    Process {
        id: wallpaperFifo
        running: true
        command: root.mkFifoCmd("/tmp/qs-wallpaper")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => root.fifoScreenReader(monName, root.broadcastWallpaperPicker)
        }
        onExited: function(code) {
            console.log("[FIFO] wallpaper exited (" + code + "), restarting")
            wallpaperFifo.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        WallpaperPickerModal {
            id: wallpaperPickerInst
            property var modelData
            screen: modelData
            onRequestFolderBrowser: path => root.broadcastOpenFolderBrowser(modelData, path)
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (wallpaperPickerInst.modelData === screen) wallpaperPickerInst.visible = false
                }
                function onBroadcastWallpaperPicker(screen) {
                    if (wallpaperPickerInst.modelData !== screen) return
                    var was = wallpaperPickerInst.visible
                    root.broadcastCloseAll(screen)
                    wallpaperPickerInst.visible = !was
                }
                function onBroadcastFolderResult(screen, path) {
                    if (wallpaperPickerInst.modelData !== screen) return
                    wallpaperPickerInst.receiveFolderResult(path)
                }
            }
        }
    }

    // ── FOLDER BROWSER ────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        FolderBrowserModal {
            id: folderBrowserInst
            property var modelData
            screen: modelData
            onFolderSelected: path => root.broadcastFolderResult(modelData, path)
            Connections {
                target: root
                function onBroadcastOpenFolderBrowser(screen, initialPath) {
                    if (folderBrowserInst.modelData !== screen) return
                    folderBrowserInst.open(initialPath)
                }
            }
        }
    }

    // ── OVERVIEW FIFO ─────────────────────────────────────────────────────
    Process {
        id: overviewFifo
        running: true
        command: root.mkFifoCmd("/tmp/qs-overview")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => root.fifoScreenReader(monName, root.broadcastOverview)
        }
        onExited: function(code) {
            console.log("[FIFO] overview exited (" + code + "), restarting")
            overviewFifo.running = true
        }
    }

    // ── SPOTLIGHT FIFO ────────────────────────────────────────────────────
    Process {
        id: spotlightFifo
        running: true
        command: root.mkFifoCmd("/tmp/qs-spotlight")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => root.fifoScreenReader(monName, root.broadcastSpotlight)
        }
        onExited: function(code) {
            console.log("[FIFO] spotlight exited (" + code + "), restarting")
            spotlightFifo.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        SpotlightModal {
            id: spotlightInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (spotlightInst.modelData === screen) spotlightInst.closeSpotlight()
                }
                function onBroadcastSpotlight(screen) {
                    if (spotlightInst.modelData !== screen) return
                    if (spotlightInst.visible) {
                        spotlightInst.closeSpotlight()
                    } else {
                        spotlightInst.openSpotlight()
                    }
                }
            }
        }
    }

    // ── HISTORIAL DE NOTIFICACIONES ───────────────────────────────────────
    ListModel {
        id: notifHistory
    }

    // ── NOTIFICATION SERVER ───────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: notification => {
            const icon     = notification.image !== "" ? notification.image : notification.appIcon
            const urgent   = notification.urgency === NotificationUrgency.Critical
            const category = root.classifyExternalNotification(notification, urgent)
            console.log("[notif] insert", notification.summary, notification.body)

            // Agregar al historial (siempre, sin filtro de modo)
            notifHistory.insert(0, {
                notifSummary: notification.summary ?? "",
                notifBody:    notification.body    ?? "",
                notifApp:     notification.appName ?? "",
                notifIcon:    icon                 ?? "",
                notifUrgent:  urgent
            })

            // Popup solo si aplica por política
            const mode = urgent ? "popup" : root.getCategoryMode(category, "popup")
            if (mode !== "popup") return
            root.broadcastNotify(notification.summary, notification.body, icon, urgent, category === "media")
        }
    }

    // ── NOTIFICATION POPUP ────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        NotificationPopup {
            id: notifPopup
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastNotify(title, body, icon, active, isMedia) {
                    notifPopup.show(title, body, icon, active, isMedia)
                }
            }
        }
    }

    // ── LANGUAGE MODAL ────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        // LanguageModal eliminado — ahora abre ControlCenter con _activePanel = "language"
    }


    // ── CONTROL CENTER ────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        ControlCenter {
            id: ccInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (ccInst.modelData === screen) ccInst.visible = false
                }
                function onBroadcastControlCenter(screen) {
                    if (ccInst.modelData !== screen) return
                    var was = ccInst.visible
                    root.broadcastCloseAll(screen)
                    ccInst.visible = !was
                }
                function onBroadcastWifi(screen) {
                    if (ccInst.modelData !== screen) return
                    root.broadcastCloseAll(screen)
                    ccInst.visible          = true
                    ccInst._activePanel     = "wifi"
                    ccInst._wifiStatusMsg   = ""
                    ccInst._wifiSelectedIdx = -1
                    ccInst._wifiPasswordByIndex = ({})
                }
                function onBroadcastBluetooth(screen) {
                    if (ccInst.modelData !== screen) return
                    root.broadcastCloseAll(screen)
                    ccInst.visible      = true
                    ccInst._activePanel = "bluetooth"
                    ccInst._btStatusMsg = ""
                    ccInst.btRefreshDeviceLists()
                    if (ccInst._btPwrd && ccInst._btAdapter) {
                        ccInst._btAdapter.discoverable = true
                        ccInst._btAdapter.pairable     = true
                        ccInst.btAutoConnectTrusted()
                    }
                }
                function onBroadcastAudio(screen) {
                    if (ccInst.modelData !== screen) return
                    root.broadcastCloseAll(screen)
                    ccInst.visible      = true
                    ccInst._activePanel = "audio"
                    ccInst.loadAudioDevices()
                }
                function onBroadcastLanguage(screen) {
                    if (ccInst.modelData !== screen) return
                    root.broadcastCloseAll(screen)
                    ccInst.visible      = true
                    ccInst._activePanel = "language"
                    ccInst.langRefresh()
                }
            }
        }
    }

    // ── SCREENSHOT MODAL ──────────────────────────────────────────────────
    Process {
        id: screenshotFifo
        running: true
        command: ["bash", root._scriptsPath + "/screenshot-fifo.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => root.fifoScreenReader(monName, root.broadcastScreenshot)
        }
        onExited: function(code) {
            console.log("[FIFO] screenshot exited (" + code + "), restarting")
            screenshotFifo.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        ScreenshotModal {
            id: screenshotModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (screenshotModalInst.modelData === screen) screenshotModalInst.visible = false
                }
                function onBroadcastScreenshot(screen) {
                    if (screenshotModalInst.modelData !== screen) return
                    var was = screenshotModalInst.visible
                    root.broadcastCloseAll(screen)
                    if (!was) screenshotModalInst.open()
                }
            }
        }
    }

    // ── VOLUME OSD ────────────────────────────────────────────────────────
    Process {
        id: volumeFifo
        running: true
        command: ["bash", root._scriptsPath + "/qs-volume-fifo.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var parts = line.trim().split(":")
                var pct   = parseInt(parts[0]) || 0
                var muted = (parts[1] === "1")
                if (root.shouldEmitInternal("volume", "osd", "osd")) {
                    root.broadcastVolume()
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        VolumeOsd {
            id: volumeOsdInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastVolume() {
                    volumeOsdInst.show()
                }
            }
        }
    }

    // ── BRIGHTNESS OSD ────────────────────────────────────────────────────
    Process {
        id: brightnessFifo
        running: true
        command: ["bash", root._scriptsPath + "/qs-brightness-fifo.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: pct => {
                if (root.shouldEmitInternal("brightness", "osd", "osd")) {
                    root.broadcastBrightness(parseInt(pct.trim()))
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        BrightnessOsd {
            id: brightnessOsdInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastBrightness(pct) {
                    brightnessOsdInst.show(pct)
                }
            }
        }
    }

    // ── BATTERY NOTIFICATIONS — UPower reactive ───────────────────────────
    property var _upBatDev:       UPower.displayDevice
    // Track last notified state to avoid duplicate notifications on startup/ráfagas
    property int _upBatLastState: -1
    // Track last notified low-battery threshold (0 = none, 40 / 30 / 20)
    property int _upBatLastLow:   0

    // Debounce timer — state changes can fire in bursts (HW quirk)
    Timer {
        id: _batStateDebounce
        interval: 1500
        onTriggered: root._handleBatStateChange()
    }

    function _handleBatStateChange() {
        if (!root.shouldEmitInternal("battery", "popup", "popup")) return
        const dev = root._upBatDev
        if (!dev || !dev.ready) return
        const s   = dev.state
        const pct = Math.round(dev.percentage * 100)

        // Skip if same state as last notification (avoids startup false-positives)
        if (s === root._upBatLastState) return
        root._upBatLastState = s

        if (s === UPowerDeviceState.Charging || s === UPowerDeviceState.PendingCharge) {
            root._upBatLastLow = 0   // reset threshold tracking on plug-in
            root.broadcastNotify(
                "󰂄 Cargando",
                "Cargador conectado — " + pct + "%",
                "battery-good", false, false
            )
        } else if (s === UPowerDeviceState.Discharging || s === UPowerDeviceState.PendingDischarge) {
            root.broadcastNotify(
                "󰂃 Desconectado",
                "Cargador desconectado — " + pct + "%",
                "battery", false, false
            )
        } else if (s === UPowerDeviceState.FullyCharged) {
            root.broadcastNotify(
                "󰁹 Carga completa",
                "Batería al " + pct + "%",
                "battery-full", false, false
            )
        }
    }

    Connections {
        target: root._upBatDev ?? null

        function onReadyChanged() {
            // Capture initial state silently — no notification on startup
            if (root._upBatDev && root._upBatDev.ready)
                root._upBatLastState = root._upBatDev.state
        }

        function onStateChanged() {
            // Debounce: restart timer, actual handling runs after 1.5 s of silence
            _batStateDebounce.restart()
        }

        function onPercentageChanged() {
            if (!root.shouldEmitInternal("battery", "popup", "popup")) return
            const dev = root._upBatDev
            if (!dev) return
            const s = dev.state
            // Only alert while discharging
            if (s !== UPowerDeviceState.Discharging && s !== UPowerDeviceState.PendingDischarge) return
            const pct = Math.round(dev.percentage * 100)

            // Notify once per threshold crossing, reset when charging
            // Each threshold fires only once until the battery recharges past it
            if (pct <= 20 && root._upBatLastLow < 20) {
                root._upBatLastLow = 20
                root.broadcastNotify(
                    "󰂃 Batería crítica",
                    "Solo queda " + pct + "% — conectá el cargador",
                    "battery-caution", true, false
                )
            } else if (pct <= 30 && root._upBatLastLow < 30) {
                root._upBatLastLow = 30
                root.broadcastNotify(
                    "󰁽 Batería baja",
                    "Queda " + pct + "% de batería",
                    "battery-low", false, false
                )
            } else if (pct <= 40 && root._upBatLastLow < 40) {
                root._upBatLastLow = 40
                root.broadcastNotify(
                    "󰁿 Batería baja",
                    "Queda " + pct + "% de batería",
                    "battery-low", false, false
                )
            }
            // Reset threshold tracker when battery recovers above 45%
            // (gives margin so it doesn't re-notify immediately after plugging in briefly)
            if (pct > 45 && root._upBatLastLow > 0) {
                root._upBatLastLow = 0
            }
        }
    }

    Component.onCompleted: {
        loadNotificationConfig()
        console.log("Quickshell loaded")
        console.log("✅ Backend | Workspaces | Power Menu | Weather | Notifications | UPower")
    }

    Component.onDestruction: {
        backendProcess.running = false
        clipboardFifo.running = false
        wallpaperFifo.running = false
        overviewFifo.running = false
        spotlightFifo.running = false
        screenshotFifo.running = false
        volumeFifo.running = false
        brightnessFifo.running = false
    }
}

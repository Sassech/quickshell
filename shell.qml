//@ pragma UseQApplication
// @ pragma ComponentBehavior:Bound  // TODO: activar cuando Quickshell lo soporte

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "Components"
import "Modals"

ShellRoot {
    id: root

    // ── Shared paths (resolved once, used by backend + FIFOs) ────────────
    property string _scriptsPath: Qt.resolvedUrl("scripts").toString().replace("file://", "")
    property string _configPath:  Qt.resolvedUrl("config").toString().replace("file://", "")

    // ════════════════════════════════════════════════════════════════════════
    // PYTHON BACKEND — single process feeding all system data
    // ════════════════════════════════════════════════════════════════════════
    Process {
        id: backendProcess
        command: ["python3", root._scriptsPath + "/quickshell_backend.py"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim()
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
    function getFocusedScreen() {
        var monCmd = ["bash", "-c",
            "hyprctl monitors -j | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\""]
        return monCmd
    }

    function getScreenFromMonName(monName) {
        var name = monName.trim()
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i]
            }
        }
        return Quickshell.screens[0]
    }

    // Shared FIFO command builder — simplified hyprctl focused monitor
    function mkFifoCmd(fifoPath) {
        return [
            "bash", "-c",
            "rm -f " + fifoPath + "; mkfifo " + fifoPath + "; " +
            "exec 3<>" + fifoPath + "; " +
            "while IFS= read -r _ <&3; do " +
            "hyprctl -j monitors 2>/dev/null | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\"; " +
            "done"
        ]
    }

    // Shared FIFO reader — resolves screen name and calls callback
    function fifoScreenReader(monName, broadcastFn) {
        var name = monName.trim()
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                broadcastFn(Quickshell.screens[i])
                return
            }
        }
        broadcastFn(Quickshell.screens[0])
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
    signal broadcastPowerMenu(var screen)
    signal broadcastWeather(var screen)
    signal broadcastBattery(var screen)
    signal broadcastFan(var screen)
    signal broadcastCpu(var screen)
    signal broadcastRam(var screen)
    signal broadcastDisk(var screen)
    signal broadcastGpu(var screen)
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
    signal broadcastMedia(var screen)
    signal broadcastBrightness(int pct)
    signal broadcastVolume()
    signal broadcastClock(var screen)

    // ============================================
    // BARRA SUPERIOR
    // ============================================
    Variants {
        model: Quickshell.screens

        TopBar {
            property var modelData
            screen: modelData
            onPowerButtonClicked: screen => root.broadcastPowerMenu(screen)
            onWeatherClicked: screen => root.broadcastWeather(screen)
            onBatteryClicked: screen => root.broadcastBattery(screen)
            onCpuClicked: screen => root.broadcastCpu(screen)
            onRamClicked: screen => root.broadcastRam(screen)
            onDiskClicked: screen => root.broadcastDisk(screen)
            onGpuClicked: screen => root.broadcastGpu(screen)
            onClipboardClicked: screen => root.broadcastClipboard(screen)
            onClockClicked: screen => root.broadcastClock(screen)
            onMediaClicked: screen => root.broadcastMedia(screen)
        }
    }

    // ============================================
    // BARRA INFERIOR
    // ============================================
    Variants {
        model: Quickshell.screens
        BottomBar {
            property var modelData
            screen: modelData
            onLanguageClicked:   screen => root.broadcastLanguage(screen)
            onWifiClicked:       screen => root.broadcastWifi(screen)
            onBluetoothClicked:  screen => root.broadcastBluetooth(screen)
            onAudioClicked:      screen => root.broadcastAudio(screen)
            onFanClicked: screen => root.broadcastFan(screen)
        }
    }

    // ── POWER MENU ────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PowerMenu {
            id: powerMenuInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (powerMenuInst.modelData === screen) powerMenuInst.visible = false
                }
                function onBroadcastPowerMenu(screen) {
                    if (powerMenuInst.modelData !== screen) return
                    var was = powerMenuInst.visible
                    root.broadcastCloseAll(screen)
                    powerMenuInst.visible = !was
                }
            }
        }
    }

    // ── CLOCK MODAL ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        ClockModal {
            id: clockModalInst
            property var modelData
            screen: modelData
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

    // ── BATTERY MODAL ─────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        BatteryModal {
            id: batteryModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (batteryModalInst.modelData === screen) batteryModalInst.visible = false
                }
                function onBroadcastBattery(screen) {
                    if (batteryModalInst.modelData !== screen) return
                    var was = batteryModalInst.visible
                    root.broadcastCloseAll(screen)
                    batteryModalInst.visible = !was
                }
            }
        }
    }

    // ── FAN MODAL ─────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        FanModal {
            id: fanModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (fanModalInst.modelData === screen) fanModalInst.visible = false
                }
                function onBroadcastFan(screen) {
                    if (fanModalInst.modelData !== screen) return
                    var was = fanModalInst.visible
                    root.broadcastCloseAll(screen)
                    fanModalInst.visible = !was
                }
            }
        }
    }

    // ── CPU MODAL ─────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        CpuModal {
            id: cpuModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (cpuModalInst.modelData === screen) cpuModalInst.visible = false
                }
                function onBroadcastCpu(screen) {
                    if (cpuModalInst.modelData !== screen) return
                    var was = cpuModalInst.visible
                    root.broadcastCloseAll(screen)
                    cpuModalInst.visible = !was
                }
            }
        }
    }

    // ── RAM MODAL ─────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        RamModal {
            id: ramModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (ramModalInst.modelData === screen) ramModalInst.visible = false
                }
                function onBroadcastRam(screen) {
                    if (ramModalInst.modelData !== screen) return
                    var was = ramModalInst.visible
                    root.broadcastCloseAll(screen)
                    ramModalInst.visible = !was
                }
            }
        }
    }

    // ── DISK MODAL ────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        DiskModal {
            id: diskModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (diskModalInst.modelData === screen) diskModalInst.visible = false
                }
                function onBroadcastDisk(screen) {
                    if (diskModalInst.modelData !== screen) return
                    var was = diskModalInst.visible
                    root.broadcastCloseAll(screen)
                    diskModalInst.visible = !was
                }
            }
        }
    }

    // ── GPU MODAL ─────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        GpuModal {
            id: gpuModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (gpuModalInst.modelData === screen) gpuModalInst.visible = false
                }
                function onBroadcastGpu(screen) {
                    if (gpuModalInst.modelData !== screen) return
                    var was = gpuModalInst.visible
                    root.broadcastCloseAll(screen)
                    gpuModalInst.visible = !was
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

    // ── NOTIFICATION SERVER ───────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: notification => {
            const icon   = notification.image !== "" ? notification.image : notification.appIcon
            const urgent = notification.urgency === NotificationUrgency.Critical

            const category = root.classifyExternalNotification(notification, urgent)
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
        LanguageModal {
            id: languageModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (languageModalInst.modelData === screen) languageModalInst.visible = false
                }
                function onBroadcastLanguage(screen) {
                    if (languageModalInst.modelData !== screen) return
                    var was = languageModalInst.visible
                    root.broadcastCloseAll(screen)
                    languageModalInst.visible = !was
                }
            }
        }
    }

    // ── WIFI MODAL ────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        WifiModal {
            id: wifiModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (wifiModalInst.modelData === screen) wifiModalInst.visible = false
                }
                function onBroadcastWifi(screen) {
                    if (wifiModalInst.modelData !== screen) return
                    var was = wifiModalInst.visible
                    root.broadcastCloseAll(screen)
                    wifiModalInst.visible = !was
                }
            }
        }
    }

    // ── BLUETOOTH MODAL ───────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        BluetoothModal {
            id: btModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (btModalInst.modelData === screen) btModalInst.visible = false
                }
                function onBroadcastBluetooth(screen) {
                    if (btModalInst.modelData !== screen) return
                    var was = btModalInst.visible
                    root.broadcastCloseAll(screen)
                    btModalInst.visible = !was
                }
            }
        }
    }

    // ── MEDIA MODAL ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        MediaModal {
            id: mediaModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (mediaModalInst.modelData === screen) mediaModalInst.visible = false
                }
                function onBroadcastMedia(screen) {
                    if (mediaModalInst.modelData !== screen) return
                    var was = mediaModalInst.visible
                    root.broadcastCloseAll(screen)
                    mediaModalInst.visible = !was
                }
            }
        }
    }

    // ── AUDIO MODAL ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        AudioModal {
            id: audioModalInst
            property var modelData
            screen: modelData
            Connections {
                target: root
                function onBroadcastCloseAll(screen) {
                    if (audioModalInst.modelData === screen) audioModalInst.visible = false
                }
                function onBroadcastAudio(screen) {
                    if (audioModalInst.modelData !== screen) return
                    var was = audioModalInst.visible
                    root.broadcastCloseAll(screen)
                    audioModalInst.visible = !was
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

    // ── BATTERY NOTIFICATIONS FIFO ────────────────────────────────────────
    Process {
        id: batteryFifo
        running: true
        command: ["bash", root._scriptsPath + "/qs-battery-fifo.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!root.shouldEmitInternal("battery", "popup", "popup")) return

                const parts = line.trim().split(":")
                const event = parts[0]

                if (event === "low") {
                    const pct = parts[1] || "?"
                    root.broadcastNotify(
                        "󰂃 Batería baja",
                        "Queda " + pct + "% de batería",
                        "battery-low",
                        true,
                        false
                    )
                } else if (event === "state") {
                    const status = parts[1] || ""
                    const pct = parts[2] || "?"
                    if (status === "Charging") {
                        root.broadcastNotify(
                            "󰂄 Cargando",
                            "Cargador conectado — " + pct + "%",
                            "battery-good",
                            false,
                            false
                        )
                    } else if (status === "Discharging") {
                        root.broadcastNotify(
                            "󰂃 Desconectado",
                            "Cargador desconectado — " + pct + "%",
                            "battery",
                            false,
                            false
                        )
                    }
                } else if (event === "full") {
                    const pct = parts[1] || "100"
                    root.broadcastNotify(
                        "󰁹 Carga completa",
                        "Batería al " + pct + "%",
                        "battery-full",
                        false,
                        false
                    )
                }
            }
        }
    }

    // ── Default power mode on startup ─────────────────────────────────────
    Process {
        id: defaultPowerMode
        command: ["sudo", root._scriptsPath + "/set-power-mode.sh", "balanced"]
        onExited: function(ec) {
            if (ec === 0) {
                console.log("Power mode: balanced")
            } else {
                console.log("Power mode set failed (non-root?)")
            }
        }
    }

    Component.onCompleted: {
        loadNotificationConfig()
        console.log("Quickshell loaded")
        console.log("✅ Backend | Workspaces | Power Menu | Weather | Notifications")
        defaultPowerMode.running = true
    }

    Component.onDestruction: {
        backendProcess.running = false
        clipboardFifo.running = false
        wallpaperFifo.running = false
        overviewFifo.running = false
        spotlightFifo.running = false
        volumeFifo.running = false
        brightnessFifo.running = false
        batteryFifo.running = false
        defaultPowerMode.running = false
    }
}

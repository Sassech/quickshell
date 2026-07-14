//@ pragma UseQApplication
pragma ComponentBehavior: Bound

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
    // ── System Data Discovery — one-time startup chain (Phase 1 foundation) ──
    // Resolves hwmon/device paths that vary across boots and caches them on
    // SysData. Runs once at startup; each stage fires the next via onExited.
    // Gates SysData.pollersReady, consumed by the native QML pollers (Phase 2)
    // and ControlCenter (Phase 3). The Python backend has been fully removed —
    // these native pollers are now the sole source of system data.
    // ════════════════════════════════════════════════════════════════════════

    // Stage 1 — hwmon names → SysData._hwmonSmm/_hwmonAwcc/_hwmonCpu/_hwmonNvme
    Process {
        id: hwmonDiscovery
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*/; do [ -r \"${d}name\" ] && printf '%s:%s\\n' \"$(cat ${d}name)\" \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: SysData.parseHwmonDiscovery(text)
        }
        onExited: {
            if (SysData._hwmonCpu.length > 0) {
                coreTempDiscovery.running = true
            } else {
                rootDeviceDiscovery.running = true
            }
        }
    }

    // Stage 2 — per-core temp label→path map → SysData._coreTempPaths (skipped if no CPU hwmon)
    Process {
        id: coreTempDiscovery
        running: false
        command: ["sh", "-c", "for f in " + SysData._hwmonCpu + "temp*_label; do printf '%s:%s\\n' \"$(cat $f)\" \"${f%_label}_input\"; done"]
        stdout: StdioCollector {
            onStreamFinished: SysData.parseCoreTempDiscovery(text)
        }
        onExited: rootDeviceDiscovery.running = true
    }

    // Stage 3 — root block device → SysData._rootDevice
    // NOTE: deviates from the originally suggested one-pass sed pipeline —
    // that version double-stripped trailing digits, turning "nvme0n1p6" into
    // "nvme0n" instead of "nvme0n1" (verified against this machine's real
    // /dev/nvme0n1p6 root partition). Two sequential sed invocations keep the
    // "strip pN suffix" and "strip bare trailing digit" cases mutually
    // exclusive so NVMe (nvme0n1pX), SATA/virtio (sdaX/vdaX) and MMC
    // (mmcblkXpY) devices all resolve correctly.
    Process {
        id: rootDeviceDiscovery
        running: false
        command: ["sh", "-c", "df --output=source / | tail -1 | sed -E 's|^/dev/||' | sed -E 's/p[0-9]+$//; t; s/[0-9]+$//'"]
        stdout: StdioCollector {
            onStreamFinished: SysData._rootDevice = text.trim()
        }
        onExited: cpuInfoDiscovery.running = true
    }

    // Stage 4 — CPU model + core count → SysData.cpuModel/cpuNcores
    Process {
        id: cpuInfoDiscovery
        running: false
        command: ["sh", "-c", "awk -F': ' '/^model name/{gsub(/\\(R\\)|\\(TM\\)|11th Gen /,\"\"); gsub(/ @ [0-9.]+GHz/,\"\"); gsub(/  +/,\" \"); print; exit}' /proc/cpuinfo; grep -c '^processor' /proc/cpuinfo"]
        stdout: StdioCollector {
            onStreamFinished: SysData.parseCpuInfo(text)
        }
        onExited: gpuCardDiscovery.running = true
    }

    // Stage 5 — GPU card path → SysData._gpuCardPath; flips pollersReady when done
    Process {
        id: gpuCardDiscovery
        running: false
        command: ["sh", "-c", "for d in /sys/class/drm/card*/; do case \"$d\" in *-*) continue;; esac; [ -r \"${d}device/vendor\" ] && echo \"$d\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: SysData._gpuCardPath = text.trim()
        }
        onExited: SysData.pollersReady = true
    }

    // Default network interface — pure FileView read, no subprocess needed.
    FileView {
        id: netRouteFile
        path: "/proc/net/route"
        onLoaded: {
            const lines = text().trim().split('\n')
            for (let i = 1; i < lines.length; i++) {
                const fields = lines[i].trim().split(/\s+/)
                if (fields.length > 1 && fields[1] === "00000000") {
                    SysData._netIface = fields[0]
                    break
                }
            }
        }
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

    // ── Notification popup config (from notifications.json) ───────────────────
    property int    _notifDismissMs:    4000
    property int    _notifAnimInMs:     200
    property int    _notifAnimOutMs:    200
    property int    _notifMarginTop:    25
    property int    _notifMarginRight:  25
    property int    _notifWidth:        400
    property string _notifPosition:     "top-right"

    // ── Battery alert config (from notifications.json) ────────────────────────
    property int    _batCritical:       20
    property var    _batWarnThresholds: [40, 30]
    property int    _batReset:          45
    property int    _batDebounceMs:     1500

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
            : root._getFocusedScreen()
        if (typeof broadcaster === "function") {
            broadcaster(targetScreen)
        }
    }

    function _getFocusedScreen() {
        // Fallback cuando el script no retorna un nombre válido.
        // Quickshell.screens no garantiza orden, así que devolvemos
        // el primero disponible (el script siempre debería retornar algo).
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i] !== undefined)
                return Quickshell.screens[i]
        }
        return Quickshell.screens[0]
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
            "cat \"" + root._configPath + "/notifications.json\" 2>/dev/null || echo '{\"categoryModes\":{},\"showMediaPopups\":false,\"mediaApps\":[],\"mediaPhrases\":[],\"messageApps\":[],\"networkApps\":[],\"networkPhrases\":[],\"popup\":{},\"battery\":{}}'"
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

                    const messageApps = root._normalizeStringArray(cfg.messageApps)
                    if (messageApps.length > 0) root._messageApps = messageApps

                    const networkApps = root._normalizeStringArray(cfg.networkApps)
                    if (networkApps.length > 0) root._networkApps = networkApps

                    const networkPhrases = root._normalizeStringArray(cfg.networkPhrases)
                    if (networkPhrases.length > 0) root._networkPhrases = networkPhrases

                    // Popup config
                    if (cfg.popup) {
                        const p = cfg.popup
                        if (typeof p.dismissMs   === "number") root._notifDismissMs   = p.dismissMs
                        if (typeof p.animInMs    === "number") root._notifAnimInMs    = p.animInMs
                        if (typeof p.animOutMs   === "number") root._notifAnimOutMs   = p.animOutMs
                        if (typeof p.marginTop   === "number") root._notifMarginTop   = p.marginTop
                        if (typeof p.marginRight === "number") root._notifMarginRight = p.marginRight
                        if (typeof p.width       === "number") root._notifWidth       = p.width
                        if (typeof p.position    === "string") root._notifPosition    = p.position
                    }

                    // Battery config
                    if (cfg.battery) {
                        const b = cfg.battery
                        if (typeof b.criticalThreshold === "number") root._batCritical    = b.criticalThreshold
                        if (Array.isArray(b.warnThresholds))          root._batWarnThresholds = b.warnThresholds
                        if (typeof b.resetThreshold    === "number") root._batReset       = b.resetThreshold
                        if (typeof b.debounceMs        === "number") {
                            root._batDebounceMs  = b.debounceMs
                            _batStateDebounce.interval = b.debounceMs
                        }
                    }
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
        onRunningChanged: if (!running) running = true
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
        onRunningChanged: if (!running) running = true
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
        onRunningChanged: if (!running) running = true
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
        onRunningChanged: if (!running) running = true
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
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true   // MUST be first — prevents discard
            if (notification.lastGeneration) return  // skip re-emitted notifications on reload
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
            dismissMs:   root._notifDismissMs
            animInMs:    root._notifAnimInMs
            animOutMs:   root._notifAnimOutMs
            marginTop:   root._notifMarginTop
            marginRight: root._notifMarginRight
            popupWidth:  root._notifWidth
            position:    root._notifPosition
            Connections {
                target: root
                function onBroadcastNotify(title, body, icon, active, isMedia) {
                    notifPopup.show(title, body, icon, active, isMedia)
                }
            }
        }
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
                        // pairable ya tiene default=true per la API — no se fuerza
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
        onRunningChanged: if (!running) running = true
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
        interval: root._batDebounceMs
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
            // Critical threshold
            if (pct <= root._batCritical && root._upBatLastLow < root._batCritical) {
                root._upBatLastLow = root._batCritical
                root.broadcastNotify(
                    "󰂃 Batería crítica",
                    "Solo queda " + pct + "% — conectá el cargador",
                    "battery-caution", true, false
                )
            } else {
                // Warn thresholds (sorted descending, e.g. [40, 30])
                const thresholds = root._batWarnThresholds
                for (let i = 0; i < thresholds.length; i++) {
                    const t = thresholds[i]
                    if (pct <= t && root._upBatLastLow < t) {
                        root._upBatLastLow = t
                        const icon = t <= 30 ? "battery-low" : "battery-caution"
                        root.broadcastNotify(
                            "󰁽 Batería baja",
                            "Queda " + pct + "% de batería",
                            icon, false, false
                        )
                        break
                    }
                }
            }
            // Reset threshold tracker when battery recovers above reset threshold
            if (pct > root._batReset && root._upBatLastLow > 0) {
                root._upBatLastLow = 0
            }
        }
    }

    Component.onCompleted: {
        loadNotificationConfig()
        console.log("Quickshell loaded")
        console.log("✅ SysData | Workspaces | Power Menu | Weather | Notifications | UPower")
    }

    Component.onDestruction: {
        clipboardFifo.running = false
        wallpaperFifo.running = false
        overviewFifo.running = false
        spotlightFifo.running = false
        screenshotFifo.running = false
        volumeFifo.running = false
        brightnessFifo.running = false
    }
}

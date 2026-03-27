//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import "Components"
import "Modals"

ShellRoot {
    id: root

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

    function mkFifoCmd(fifoPath, callbackName) {
        return [
            "bash", "-c",
            "rm -f " + fifoPath + "; mkfifo " + fifoPath + "; " +
            "exec 3<>" + fifoPath + "; " +
            "while IFS= read -r _ <&3; do " +
            "hyprctl monitors -j | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\"; " +
            "done"
        ]
    }

    // ── Signals ───────────────────────────────────────────────
    signal broadcastNotify(string title, string body, string icon, bool active, bool isMedia)
    signal broadcastCloseAll(var screen)
    signal broadcastPowerMenu(var screen)
    signal broadcastWeather(var screen)
    signal broadcastBattery(var screen)
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
    signal broadcastBrightness(int pct)
    signal broadcastVolume(int pct, bool muted)
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
        }
    }

    // ============================================
    // POWER MENU MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // CLOCK MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // WEATHER MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // BATTERY MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // CPU MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // RAM MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // DISK MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // GPU MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // CLIPBOARD MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // CLIPBOARD — FIFO global (SUPER+V)
    // ============================================
    Process {
        id: clipboardFifo
        running: true
        command: ["bash", "-c",
            "rm -f /tmp/qs-clipboard; mkfifo /tmp/qs-clipboard; " +
            "exec 3<>/tmp/qs-clipboard; " +
            "while IFS= read -r _ <&3; do " +
            "hyprctl monitors -j | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\"; " +
            "done"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => {
                var name = monName.trim()
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === name) {
                        root.broadcastClipboard(Quickshell.screens[i])
                        return
                    }
                }
                root.broadcastClipboard(Quickshell.screens[0])
            }
        }
    }

    // ============================================
    // WALLPAPER PICKER — FIFO global (SUPER+Y)
    // ============================================
    Process {
        id: wallpaperFifo
        running: true
        command: ["bash", "-c",
            "rm -f /tmp/qs-wallpaper; mkfifo /tmp/qs-wallpaper; " +
            "exec 3<>/tmp/qs-wallpaper; " +
            "while IFS= read -r _ <&3; do " +
            "hyprctl monitors -j | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\"; " +
            "done"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => {
                var name = monName.trim()
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === name) {
                        root.broadcastWallpaperPicker(Quickshell.screens[i])
                        return
                    }
                }
                root.broadcastWallpaperPicker(Quickshell.screens[0])
            }
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

    // ============================================
    // FOLDER BROWSER — una instancia por pantalla
    // ============================================
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

    // ============================================
    // OVERVIEW — FIFO global + una instancia por pantalla
    // ============================================
    Process {
        id: overviewFifo
        running: true
        command: ["bash", "-c",
            "rm -f /tmp/qs-overview; mkfifo /tmp/qs-overview; " +
            "exec 3<>/tmp/qs-overview; " +
            "while IFS= read -r _ <&3; do " +
            "hyprctl monitors -j | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\"; " +
            "done"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => {
                var name = monName.trim()
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === name) {
                        root.broadcastOverview(Quickshell.screens[i])
                        return
                    }
                }
                root.broadcastOverview(Quickshell.screens[0])
            }
        }
    }

    // ============================================
    // SPOTLIGHT — FIFO global + una instancia por pantalla
    // ============================================
    Process {
        id: spotlightFifo
        running: true
        command: ["bash", "-c",
            "rm -f /tmp/qs-spotlight; mkfifo /tmp/qs-spotlight; " +
            "exec 3<>/tmp/qs-spotlight; " +
            "while IFS= read -r _ <&3; do " +
            "hyprctl monitors -j | python3 -c \"import json,sys; ms=json.load(sys.stdin); print(next((m['name'] for m in ms if m.get('focused')), ms[0]['name']))\"; " +
            "done"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: monName => {
                var name = monName.trim()
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === name) {
                        root.broadcastSpotlight(Quickshell.screens[i])
                        return
                    }
                }
                root.broadcastSpotlight(Quickshell.screens[0])
            }
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

    // Último contenido de notificación de media mostrado — para dedup entre MPRIS y rmpc
    property string _mediaLastShown: ""

    // ============================================
    // NOTIFICATION SERVER — intercepta notify-send del sistema
    // ============================================
    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: notification => {
            const icon   = notification.image !== "" ? notification.image : notification.appIcon
            const urgent = notification.urgency === NotificationUrgency.Critical

            // Deduplicar: si el watcher MPRIS ya mostró esta canci\u00f3n, ignorar
            const key = notification.summary + "|" + notification.body
            if (key === root._mediaLastShown) return

            root.broadcastNotify(notification.summary, notification.body, icon, urgent, false)

            // Si viene de rmpc, guardar clave para que el watcher MPRIS no duplique
            if ((notification.appName ?? "").toLowerCase().includes("rmpc")) {
                root._mediaLastShown = key
                dedupClearTimer.restart()
            }
        }
    }

    // ============================================
    // NOTIFICATION POPUP — una instancia por pantalla
    // ============================================
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

    // ============================================
    // MPRIS TRACK-CHANGE NOTIFICATIONS — todos los reproductores
    // Spotify, Brave, rmpc (vía mpDris2), Lollypop, etc.
    // ============================================
    Instantiator {
        model: Mpris.players

        delegate: Item {
            required property MprisPlayer modelData

            // Evita notificaciones duplicadas por el mismo título
            property string _lastTitle: ""

            Connections {
                target: modelData

                function onTrackTitleChanged() {
                    const title  = modelData.trackTitle  ?? ""
                    if (modelData.playbackState !== MprisPlaybackState.Playing) return
                    if (title === "" || title === _lastTitle) return

                    const artist = modelData.trackArtist ?? ""
                    const art    = modelData.trackArtUrl ?? ""
                    const body   = artist ? artist + "  -  " + title : title

                    // Dedup: rmpc pudo haber disparado notify-send antes que nosotros
                    // Comprobar si el título ya fue notificado recientemente
                    if (root._mediaLastShown !== "" && root._mediaLastShown.includes(title)) return

                    _lastTitle = title
                    // Guardar clave para bloquear el notify-send de rmpc si viene después
                    root._mediaLastShown = "Now Playing|" + body
                    dedupClearTimer.restart()
                    root.broadcastNotify("Now Playing", body, art, false, true)
                }
            }
        }
    }

    // Limpia la clave de dedup tras 3s para que notificaciones futuras de otras apps no queden bloqueadas
    Timer {
        id: dedupClearTimer
        interval: 3000
        onTriggered: root._mediaLastShown = ""
    }

    // ============================================
    // LANGUAGE MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // WIFI MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // BLUETOOTH MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // AUDIO MODAL — una instancia por pantalla
    // ============================================
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

    // ============================================
    // VOLUME OSD — FIFO global, OSD en todas las pantallas
    // ============================================
    Process {
        id: volumeFifo
        running: true
        command: ["bash", "/home/sassech/.config/quickshell/scripts/qs-volume-fifo.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var parts = line.trim().split(":")
                var pct   = parseInt(parts[0]) || 0
                var muted = (parts[1] === "1")
                root.broadcastVolume(pct, muted)
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
                function onBroadcastVolume(pct, muted) {
                    volumeOsdInst.show(pct, muted)
                }
            }
        }
    }

    // ============================================
    // BRIGHTNESS OSD — FIFO global, OSD en todas las pantallas
    // ============================================
    Process {
        id: brightnessFifo
        running: true
        command: ["bash", "/home/sassech/.config/quickshell/scripts/qs-brightness-fifo.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: pct => root.broadcastBrightness(parseInt(pct.trim()))
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

    // Aplica modo Balanceado al arrancar
    Process {
        id: defaultPowerMode
        command: ["sudo", "/home/sassech/.config/quickshell/scripts/set-power-mode.sh", "balanced"]
        onExited: function(ec) {
            if (ec === 0) {
                console.log("Power mode: balanced")
            } else {
                console.log("Power mode set failed (non-root?)")
            }
        }
    }

    Component.onCompleted: {
        console.log("Quickshell loaded")
        console.log("✅ Workspaces | Power Menu | Weather | Notifications")
        defaultPowerMode.running = true
    }

    Component.onDestruction: {
        clipboardFifo.running = false
        wallpaperFifo.running = false
        overviewFifo.running = false
        spotlightFifo.running = false
        volumeFifo.running = false
        brightnessFifo.running = false
        defaultPowerMode.running = false
    }
}


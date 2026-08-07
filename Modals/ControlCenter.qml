// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Components"
import "./cc"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true

    // ── Coordinación UI ───────────────────────────────────────────────────
    property bool   _showConfirm:  false
    property string _confirmLabel: ""
    property var    _confirmCmd:   []

    property int    _btRev: 0
    property string _activePanel: ""   // "wifi" | "bluetooth" | "audio" | "power" | "battery" | "language" | "cpu" | "ram" | "gpu" | ""
    property bool   _audioShowSources: true

    // ── Controladores de dominio ──────────────────────────────────────────

    CcBatteryController {
        id: batCtrl
    }

    CcBrightnessController {
        id: brightnessCtrl
    }

    CcGpuController {
        id: gpuCtrl
        active: root.visible && root._activePanel === "gpu"
    }

    CcPowerController {
        id: powerCtrl
    }

    CcLanguageController {
        id: langCtrl
    }

    CcAudioController {
        id: audioCtrl
        panelVisible: root.visible
        panelActive:  root._activePanel === "audio"
    }

    CcBluetoothController {
        id: btCtrl
    }

    CcWifiController {
        id: wifiCtrl
    }

    // ── Conexión: signal del wifi controller → ccPanelOverlay ────────────
    Connections {
        target: wifiCtrl
        function onWifiPasswordFetched(idx, pw) {
            ccPanelOverlay.wifiPasswordFetched(idx, pw)
        }
    }

    // ── Timer: btCodecRefreshTimer necesita condición del root ────────────
    Connections {
        target: btCtrl._btCodecRefreshTimer
        function onRunningChanged() {}
    }
    // Bindear running del codec timer al estado del root
    Binding {
        target: btCtrl._btCodecRefreshTimer
        property: "running"
        value: root.visible && root._activePanel === "bluetooth"
    }

    // ── Aliases Battery ───────────────────────────────────────────────────
    property alias _upowerDev:      batCtrl._upowerDev
    property alias _batAvailableUP: batCtrl._batAvailableUP
    property alias _batPctUP:       batCtrl._batPctUP
    property alias _batChargingUP:  batCtrl._batChargingUP
    property alias _batFullUP:      batCtrl._batFullUP
    property alias _batHealthUP:    batCtrl._batHealthUP
    property alias _batCapWhUP:     batCtrl._batCapWhUP
    property alias _batEnergyUP:    batCtrl._batEnergyUP
    property alias _batChangeRate:  batCtrl._batChangeRate
    property alias _batTimeEmpty:   batCtrl._batTimeEmpty
    property alias _batTimeFull:    batCtrl._batTimeFull

    // ── Aliases Brightness ────────────────────────────────────────────────
    property alias brightness:       brightnessCtrl.brightness
    property alias _brightnessReady: brightnessCtrl._brightnessReady

    // ── Aliases GPU ───────────────────────────────────────────────────────
    property alias _gpuLoaded:      gpuCtrl._gpuLoaded
    property alias _gpus:           gpuCtrl._gpus

    // ── Aliases Power ─────────────────────────────────────────────────────
    property alias _fanProfiles: powerCtrl._fanProfiles

    // ── Aliases Language ──────────────────────────────────────────────────
    property alias _langLayout:        langCtrl._langLayout
    property alias _langLocale:        langCtrl._langLocale
    property alias _langLayouts:       langCtrl._langLayouts
    property alias _langLocales:       langCtrl._langLocales
    property alias _langSearch:        langCtrl._langSearch
    property alias _langSearchPending: langCtrl._langSearchPending
    property alias _langTab:           langCtrl._langTab
    property alias _filteredLayouts:   langCtrl._filteredLayouts
    property alias _filteredLocales:   langCtrl._filteredLocales

    // ── Aliases Audio ─────────────────────────────────────────────────────
    property alias defaultSink:       audioCtrl.defaultSink
    property alias defaultSource:     audioCtrl.defaultSource
    property alias _activeSink:       audioCtrl._activeSink
    property alias _activeSource:     audioCtrl._activeSource
    property alias _activeSinkName:   audioCtrl._activeSinkName
    property alias _activeSourceName: audioCtrl._activeSourceName
    property alias masterVolume:      audioCtrl.masterVolume
    property alias masterMuted:       audioCtrl.masterMuted
    property alias micVolume:         audioCtrl.micVolume
    property alias micMuted:          audioCtrl.micMuted
    property alias _pwRev:            audioCtrl._pwRev
    property alias _audioSinkAvail:   audioCtrl._audioSinkAvail
    property alias _audioSourceAvail: audioCtrl._audioSourceAvail
    property alias _audioComboCards:  audioCtrl._audioComboCards
    property alias audioSinks:        audioCtrl.audioSinks
    property alias audioSources:      audioCtrl.audioSources

    // ── Aliases Bluetooth ─────────────────────────────────────────────────
    property alias _btAdapter:         btCtrl._btAdapter
    property alias _btAvailable:       btCtrl._btAvailable
    property alias _btPwrd:            btCtrl._btPwrd
    property alias _btScanning:        btCtrl._btScanning
    property alias _btWorking:         btCtrl._btWorking
    property alias _btStatusMsg:       btCtrl._btStatusMsg
    property alias _btPairedList:      btCtrl._btPairedList
    property alias _btNearbyList:      btCtrl._btNearbyList
    property alias _btPairedCount:     btCtrl._btPairedCount
    property alias _btNearbyCount:     btCtrl._btNearbyCount
    property alias _btCodecData:       btCtrl._btCodecData
    property alias btAdapter:          btCtrl.btAdapter
    property alias btPowered:          btCtrl.btPowered
    property alias btConnectedCount:   btCtrl.btConnectedCount
    property alias btFirstConnectedName: btCtrl.btFirstConnectedName

    // ── Aliases WiFi ──────────────────────────────────────────────────────
    property alias _nmWifiDev:          wifiCtrl._nmWifiDev
    property alias _wifiRadioOn:        wifiCtrl._wifiRadioOn
    property alias _wifiScanning:       wifiCtrl._wifiScanning
    property alias _wifiWorking:        wifiCtrl._wifiWorking
    property alias _wifiStatusMsg:      wifiCtrl._wifiStatusMsg
    property alias _wifiSelectedIdx:    wifiCtrl._wifiSelectedIdx
    property alias _wifiPasswordByIndex: wifiCtrl._wifiPasswordByIndex
    property alias _wifiTargetNet:      wifiCtrl._wifiTargetNet
    property alias _wifiConnectedNet:   wifiCtrl._wifiConnectedNet
    property alias _wifiConnectedSsid:  wifiCtrl._wifiConnectedSsid
    property alias _wifiIp:             wifiCtrl._wifiIp
    property alias _wifiGateway:        wifiCtrl._wifiGateway
    property alias _wifiDns:            wifiCtrl._wifiDns
    property alias _ethConnected:       wifiCtrl._ethConnected
    property alias _ethIp:              wifiCtrl._ethIp
    property alias _ethSpeed:           wifiCtrl._ethSpeed

    // ── Wrappers de funciones de controladores (para mantener contrato) ───

    // Battery/Power
    function _powerLabel(profile) { return powerCtrl._powerLabel(profile) }
    function _powerIcon(profile)  { return powerCtrl._powerIcon(profile) }
    function setPower(profile)    { powerCtrl.setPower(profile) }
    function _fmtTime(seconds)    { return powerCtrl._fmtTime(seconds) }
    function _fmtSpeed(bps)       { return powerCtrl._fmtSpeed(bps) }
    function formatDuration(ms)   { return powerCtrl.formatDuration(ms) }

    // Brightness
    function setBrightness(pct) { brightnessCtrl.setBrightness(pct) }

    // Language
    function langRefresh() { langCtrl.langRefresh() }

    // Audio
    function setMasterVolume(v)    { audioCtrl.setMasterVolume(v) }
    function setMicVol(v)          { audioCtrl.setMicVol(v) }
    function toggleMasterMute()    { audioCtrl.toggleMasterMute() }
    function toggleMicMute()       { audioCtrl.toggleMicMute() }
    function setDefaultSink(entry) { audioCtrl.setDefaultSink(entry) }
    function setDefaultSource(entry) { audioCtrl.setDefaultSource(entry) }
    function loadAudioDevices()    { audioCtrl.loadAudioDevices() }
    function _audioFormatDesc(desc, name) { return audioCtrl._audioFormatDesc(desc, name) }

    // Bluetooth
    function btSanitizeMac(mac)          { return btCtrl.btSanitizeMac(mac) }
    function btRunNextCodecQuery()        { btCtrl.btRunNextCodecQuery() }
    function btSetCodec(mac, profile)    { btCtrl.btSetCodec(mac, profile) }
    function btResetAction(msg)          { btCtrl.btResetAction(msg) }
    function btRefreshDeviceLists()      { btCtrl.btRefreshDeviceLists() }
    function btAutoConnectTrusted()      { btCtrl.btAutoConnectTrusted() }
    function btAutoConnNext()            { btCtrl.btAutoConnNext() }
    function btTogglePower()             { btCtrl.btTogglePower() }
    function btToggleScan()              { btCtrl.btToggleScan() }
    function btConnectDevice(device)     { btCtrl.btConnectDevice(device) }
    function btDisconnectDevice(device)  { btCtrl.btDisconnectDevice(device) }
    function btPairDevice(device)        { btCtrl.btPairDevice(device) }
    function btForgetDevice(device)      { btCtrl.btForgetDevice(device) }

    // WiFi
    function wifiToggleRadio()             { wifiCtrl.wifiToggleRadio() }
    function wifiRescan()                  { wifiCtrl.wifiRescan() }
    function wifiConnectKnown(net)         { wifiCtrl.wifiConnectKnown(net) }
    function wifiConnectNew(ssid, pw)      { wifiCtrl.wifiConnectNew(ssid, pw) }
    function wifiDisconnect(net)           { wifiCtrl.wifiDisconnect(net) }
    function wifiForget(net)               { wifiCtrl.wifiForget(net) }
    function wifiFetchPasswordFor(ssid, idx) { wifiCtrl.wifiFetchPasswordFor(ssid, idx) }
    function wifiCopyPassword(ssid)        { wifiCtrl.wifiCopyPassword(ssid) }
    function wifiSignalIcon(strength)      { return wifiCtrl.wifiSignalIcon(strength) }
    function wifiSecurityLabel(sec)        { return wifiCtrl.wifiSecurityLabel(sec) }
    function wifiIsOpen(sec)               { return wifiCtrl.wifiIsOpen(sec) }

    // ── MPRIS — reproductor ───────────────────────────────────────────────
    property var mprisPlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property real playerPos: 0
    property int  _posSync: 0

    function _syncPlayerPos() {
        if (root.mprisPlayer && root.mprisPlayer.positionSupported)
            root.playerPos = root.mprisPlayer.position
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.mprisPlayer?.isPlaying ?? false)
        onTriggered: {
            root.playerPos += 1
            root._posSync++
            if (root._posSync >= 10) { root._posSync = 0; root._syncPlayerPos() }
        }
    }

    Connections {
        target: root.mprisPlayer ?? null
        function onTrackChanged() { root._syncPlayerPos(); root._posSync = 0 }
    }

    // ── Startup / teardown ────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            root._gpuLoaded = false
            brightnessCtrl.refresh()
            Qt.callLater(root._syncPlayerPos)
            root._pwRev++
            root._btRev++
            Qt.callLater(function() { ccCard.forceActiveFocus() })
        } else {
            root._activePanel  = ""
            root._showConfirm  = false
        }
    }

    // ── Backdrop ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    // ── Card principal ────────────────────────────────────────────────────
    Rectangle {
        id: ccCard
        focus: true
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 36
            rightMargin: 12
        }
        width: 360
        height: Math.min(parent.height - 72, Math.max(scrollContent.implicitHeight + 24, 100))
        radius: 16
        color: Theme.cardBg3

        Keys.onEscapePressed: root.visible = false

        // Borde sutil
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
            border.width: 1
        }

        MouseArea { anchors.fill: parent }

        // ── Scroll container ───────────────────────────────────────────────
        Flickable {
            id: ccFlick
            anchors { fill: parent; margins: 12 }
            contentWidth: width
            contentHeight: scrollContent.implicitHeight
            clip: true
            boundsMovement: Flickable.StopAtBounds

            Column {
                id: scrollContent
                width: ccFlick.width
                spacing: 0

                // ── POWER BAR ─────────────────────────────────────────────
                CcPowerBar {
                    width: parent.width
                    onShowConfirm: (label, cmd) => {
                        root._confirmLabel = label
                        root._confirmCmd   = cmd
                        root._showConfirm  = true
                    }
                    onRunCmd: cmd => {
                        root.visible = false
                        ccExecProc.runCmd(cmd)
                    }
                    onClose: root.visible = false
                }

                // ── SEPARADOR ──────────────────────────────────────────────
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }
                Item { width: parent.width; height: 8 }

                // ══════════════════════════════════════════════════════════
                // SECCIÓN 1 — Sliders de audio y brillo
                // ══════════════════════════════════════════════════════════

                CcSliders {
                    width: parent.width
                    masterVolume: root.masterVolume
                    masterMuted:  root.masterMuted
                    micVolume:    root.micVolume
                    micMuted:     root.micMuted
                    brightness:   root.brightness
                    onSetMasterVolume: v => root.setMasterVolume(v)
                    onToggleMasterMute: root.toggleMasterMute()
                    onSetMicVol: v => root.setMicVol(v)
                    onToggleMicMute: root.toggleMicMute()
                    onSetBrightness: v => root.setBrightness(v)
                }

                Item { width: parent.width; height: 8 }
                Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

                // ── Controles rápidos ─────────────────────────────────────
                CcQuickToggles {
                    width: parent.width
                    activePanel:          root._activePanel
                    btAdapter:            root.btAdapter
                    btPowered:            root.btPowered
                    btConnectedCount:     root.btConnectedCount
                    btFirstConnectedName: root.btFirstConnectedName
                    batAvailable:         root._batAvailableUP
                    batPct:               root._batPctUP
                    batCharging:          root._batChargingUP
                    batFull:              root._batFullUP
                    batTimeFull:          root._batTimeFull
                    batTimeEmpty:         root._batTimeEmpty
                    defaultSink:          root.defaultSink
                    langLayout:           root._langLayout
                    langLocale:           root._langLocale
                    powerLabelFn:         root._powerLabel
                    powerIconFn:          root._powerIcon
                    fmtTimeFn:            root._fmtTime
                    audioFormatDescFn:    root._audioFormatDesc

                    onOpenWifi: {
                        root._activePanel = "wifi"
                        wifiCtrl.openPanel()
                    }
                    onOpenBluetooth: {
                        root._activePanel = "bluetooth"
                        root._btStatusMsg = ""
                        root.btRefreshDeviceLists()
                        if (root._btPwrd && root._btAdapter) {
                            root._btAdapter.discoverable = true
                            root.btAutoConnectTrusted()
                        }
                    }
                    onOpenPower: {
                        root._activePanel = "power"
                        if (root._fanProfiles.length === 0)
                            powerCtrl._fanProfilesProc.running = true
                    }
                    onOpenAudio: {
                        root._activePanel = "audio"
                        root.loadAudioDevices()
                    }
                    onOpenBattery: root._activePanel = "battery"
                    onOpenLanguage: {
                        root._activePanel = "language"
                        root.langRefresh()
                    }
                }

                // ── Métricas del sistema ──────────────────────────────────
                CcSystemSection {
                    width: parent.width
                    activePanel: root._activePanel
                    diskPct:    SysData.diskPercent
                    diskUsed:   SysData.diskUsedGb
                    diskTotal:  SysData.diskUsedGb + SysData.diskAvailGb
                    homePct:    SysData.homePercent
                    homeUsed:   SysData.homeUsedGb
                    homeTotal:  SysData.homeUsedGb + SysData.homeAvailGb
                    onTogglePanel: function(key) {
                        root._activePanel = (root._activePanel === key) ? "" : key
                    }
                }

                // ── Media player ──────────────────────────────────────────
                CcMediaPlayer {
                    width: parent.width
                    mprisPlayer: root.mprisPlayer
                    playerPos:   root.playerPos
                }

                Item { width: parent.width; height: 8 }
            }
        }

        // Scrollbar visual
        Rectangle {
            visible: ccFlick.contentHeight > ccFlick.height + 1
            anchors { right: parent.right; rightMargin: 3 }
            y: 12 + ccFlick.visibleArea.yPosition * (ccCard.height - 24)
            width: 3; radius: 2
            height: Math.max(20, ccFlick.visibleArea.heightRatio * (ccCard.height - 24))
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
        }
    }

    // ── Panel overlay (popups de detalle) ─────────────────────────────────
    CcPanelOverlay {
        id: ccPanelOverlay
        anchors.fill: parent
        z: 200

        activePanel: root._activePanel

        // WiFi
        nmWifiDev:           root._nmWifiDev
        wifiRadioOn:         root._wifiRadioOn
        wifiScanning:        root._wifiScanning
        wifiWorking:         root._wifiWorking
        wifiStatusMsg:       root._wifiStatusMsg
        wifiSelectedIdx:     root._wifiSelectedIdx
        wifiPasswordByIndex: root._wifiPasswordByIndex
        wifiConnectedSsid:   root._wifiConnectedSsid
        ethConnected:        root._ethConnected
        ethIp:               root._ethIp
        ethSpeed:            root._ethSpeed
        wifiIp:              root._wifiIp
        wifiGateway:         root._wifiGateway
        wifiDns:             root._wifiDns
        // Bluetooth
        btAdapter:     root._btAdapter
        btAvailable:   root._btAvailable
        btPwrd:        root._btPwrd
        btScanning:    root._btScanning
        btWorking:     root._btWorking
        btStatusMsg:   root._btStatusMsg
        btPairedList:  root._btPairedList
        btNearbyList:  root._btNearbyList
        btPairedCount: root._btPairedCount
        btNearbyCount: root._btNearbyCount
        btCodecData:   root._btCodecData

        // Audio
        audioSinks:   root.audioSinks
        audioSources: root.audioSources

        // Power
        fanProfiles: root._fanProfiles
        fanProfile:  SysData.fanProfile

        // Battery
        batAvailable:  root._batAvailableUP
        batPct:        root._batPctUP
        batCharging:   root._batChargingUP
        batFull:       root._batFullUP
        batHealth:     root._batHealthUP
        batCapWh:      root._batCapWhUP
        batEnergy:     root._batEnergyUP
        batChangeRate: root._batChangeRate
        batTimeEmpty:  root._batTimeEmpty
        batTimeFull:   root._batTimeFull

        // CPU
        cpuAvailable:   SysData.cpuAvailable
        cpuPercent:     SysData.cpuPercent
        cpuTemp:        SysData.cpuTemp
        cpuModel:       SysData.cpuModel
        cpuAvgFreq:     SysData.cpuAvgFreqMhz
        cpuGov:         SysData.cpuGovernor
        cpuNcores:      SysData.cpuNcores
        cpuCorePcts:    SysData.cpuCorePcts
        cpuCoreTemps:   SysData.cpuCoreTemps
        cpuLoaded:      SysData.cpuAvailable

        // RAM
        ramAvailable: SysData.ramAvailable
        ramPercent:   SysData.ramPercent
        ramUsedGb:    SysData.ramUsedGb
        ramTotalGb:   SysData.ramTotalGb
        ramAvailGb:   SysData.ramAvailGb
        ramCacheGb:   SysData.ramCacheGb
        ramAppsGb:    SysData.ramAppsGb
        swapPercent:  SysData.swapPercent
        swapTotalGb:  SysData.swapTotalGb
        swapFreeGb:   SysData.swapFreeGb

        // GPU
        gpus:       root._gpus
        gpuLoaded:  root._gpuLoaded

        // Disk
        diskAvailable:  SysData.diskAvailable
        diskPercent:    SysData.diskPercent
        diskUsed:       SysData.diskUsedGb
        diskAvail:      SysData.diskAvailGb
        homePercent:    SysData.homePercent
        homeUsed:       SysData.homeUsedGb
        homeAvail:      SysData.homeAvailGb
        nvmeModel:      SysData.diskNvmeModel
        nvmeFw:         SysData.diskNvmeFw
        nvmeTemp:       SysData.diskNvmeTemp
        diskReadMbs:    SysData.diskReadMbs
        diskWriteMbs:   SysData.diskWriteMbs

        // Language
        filteredLayouts: root._filteredLayouts
        filteredLocales: root._filteredLocales
        langLayout:      root._langLayout
        langLocale:      root._langLocale
        langTab:         root._langTab
        langSearch:      root._langSearch

        // ── Signal handlers ───────────────────────────────────────────────
        onClosePanel: {
            if (root._activePanel === "bluetooth") {
                if (root._btAdapter) {
                    root._btAdapter.discovering  = false
                    root._btAdapter.discoverable = false
                    root._btAdapter.pairable     = false
                }
                root._btScanning = false
                btCtrl._btScanTimer.stop()
                btCtrl._btActionTimeout.stop()
                btCtrl._btAutoConnTimer.stop()
                btCtrl._btConnectRetryTimer.stop()
            }
            root._activePanel = ""
        }
        onDiskPanelOpened: SysData.triggerDiskIoSample()

        // WiFi
        onWifiToggleRadio:    root.wifiToggleRadio()
        onWifiRescan:         root.wifiRescan()
        onWifiConnectKnown: (net) => root.wifiConnectKnown(net)
        onWifiConnectNew: (ssid, pw) => root.wifiConnectNew(ssid, pw)
        onWifiDisconnect: (net) => root.wifiDisconnect(net)
        onWifiForget: (net) => root.wifiForget(net)
        onWifiFetchPassword: (ssid, idx) => root.wifiFetchPasswordFor(ssid, idx)
        onWifiCopyPassword: (ssid) => root.wifiCopyPassword(ssid)
        onWifiSelectIdx: (idx) => { root._wifiSelectedIdx = idx }
        onWifiStatusMessage: (msg) => { root._wifiStatusMsg = msg }
        onWifiPasswordChanged: (idx, pw) => {
            root._wifiPasswordByIndex[idx] = pw
            root._wifiPasswordByIndexChanged()
        }

        // Bluetooth
        onBtTogglePower:  root.btTogglePower()
        onBtToggleScan:   root.btToggleScan()
        onBtConnect: (d)      => root.btConnectDevice(d)
        onBtDisconnect: (d)   => root.btDisconnectDevice(d)
        onBtPair: (d)         => root.btPairDevice(d)
        onBtCancelPair: (d)   => { if (d) d.cancelPair() }
        onBtForget: (d)       => root.btForgetDevice(d)
        onBtSetCodec: (mac, prof) => root.btSetCodec(mac, prof)

        // Audio
        onAudioSetDefaultSink: (e)  => root.setDefaultSink(e)
        onAudioSetDefaultSource: (e) => root.setDefaultSource(e)

        // Power
        onPowerSetProfile: (p) => root.setPower(p)

        // Language
        onLangSelectTab: (tab) => {
            root._langTab           = tab
            langCtrl.stopSearch()
        }
        onLangSearchQuery: (q) => {
            langCtrl.startSearch(q)
        }
        onLangSetLayout: (code) => {
            langCtrl.setLayout(code)
        }
        onLangSetLocale: (value) => {
            langCtrl.setLocale(value)
        }
    }

    // ── Confirm overlay (acciones críticas de power) ──────────────────────
    Rectangle {
        visible: root._showConfirm
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        z: 100

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 240; height: confirmCol.implicitHeight + 40
            radius: 14; color: Theme.cardBg3
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            opacity: root._showConfirm ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Column {
                id: confirmCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 22 }
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root._confirmLabel
                    font.pixelSize: 16; font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Are you sure?"
                    font.pixelSize: 12; color: Qt.rgba(1, 1, 1, 0.50)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: 96; height: 34; radius: 9
                        color: cnNoHov.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                        border.color: Qt.rgba(1,1,1, cnNoHov.containsMouse ? 0.25 : 0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.80) }
                        MouseArea { id: cnNoHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._showConfirm = false }
                    }

                    Rectangle {
                        width: 96; height: 34; radius: 9
                        color: cnYesHov.containsMouse ? Qt.rgba(0.9,0.2,0.2,0.45) : Qt.rgba(0.8,0.15,0.15,0.25)
                        border.color: Qt.rgba(1,0.35,0.35, cnYesHov.containsMouse ? 0.7 : 0.40); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Confirm"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Qt.rgba(1,0.6,0.6,1) }
                        MouseArea { id: cnYesHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cmd = root._confirmCmd
                                root._showConfirm = false
                                root.visible = false
                                ccExecProc.runCmd(cmd)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Power exec process ────────────────────────────────────────────────
    Process {
        id: ccExecProc
        running: false
        function runCmd(cmd) { command = cmd; running = true }
        // qmllint disable signal-handler-parameters
        onExited: running = false
        // qmllint enable signal-handler-parameters
    }

    // ── CPU detail refresh — native QML pollers (SysData) ─────────────────
    Timer {
        interval: 1500; repeat: true
        running: root.visible && root._activePanel === "cpu"
        onTriggered: SysData.refreshCpuDetail()
        onRunningChanged: {
            if (running) SysData.refreshCpuDetail()
        }
    }
}

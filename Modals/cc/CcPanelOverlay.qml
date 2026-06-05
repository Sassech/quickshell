import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking
import "."
import "../../Components"

// ── Overlay de paneles del Control Center ─────────────────────────────────────
// Se coloca con z:200 dentro del PanelWindow principal.
// Muestra un backdrop + el panel activo centrado verticalmente, alineado a la derecha.
Item {
    id: root

    // ── Inputs desde ControlCenter ────────────────────────────────────────
    required property string activePanel          // "wifi"|"bluetooth"|"audio"|"power"|"battery"|"language"|"cpu"|"ram"|"gpu"|""

    // WiFi
    required property var    nmWifiDev
    required property bool   wifiRadioOn
    required property bool   wifiScanning
    required property bool   wifiWorking
    required property string wifiStatusMsg
    required property int    wifiSelectedIdx
    required property var    wifiPasswordByIndex
    required property string wifiConnectedSsid
    required property bool   ethConnected
    required property string ethIp
    required property string ethSpeed
    required property string wifiIp
    required property string wifiGateway
    required property string wifiDns
    // Bluetooth
    required property var    btAdapter
    required property bool   btAvailable
    required property bool   btPwrd
    required property bool   btScanning
    required property bool   btWorking
    required property string btStatusMsg
    required property var    btPairedList
    required property var    btNearbyList
    required property int    btPairedCount
    required property int    btNearbyCount
    required property var    btCodecData

    // Audio
    required property var audioSinks
    required property var audioSources

    // Power
    required property var    fanProfiles
    required property string fanProfile

    // Battery
    required property bool  batAvailable
    required property real  batPct
    required property bool  batCharging
    required property bool  batFull
    required property real  batHealth
    required property real  batCapWh
    required property real  batEnergy
    required property real  batChangeRate
    required property real  batTimeEmpty
    required property real  batTimeFull

    // CPU
    required property bool cpuAvailable
    required property int  cpuPercent
    required property int  cpuTemp

    // RAM
    required property bool ramAvailable
    required property int  ramPercent
    required property real ramUsedGb
    required property real ramTotalGb
    required property real ramAvailGb
    required property int  swapPercent

    // GPU
    required property bool   gpuAvailable
    required property int    gpuPercent
    required property int    gpuTemp
    required property string gpuName
    required property int    gpuVramUsedMb
    required property int    gpuVramTotalMb

    // Language
    required property var    filteredLayouts
    required property var    filteredLocales
    required property string langLayout
    required property string langLocale
    required property string langTab
    required property string langSearch

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closePanel()

    // WiFi signals
    signal wifiToggleRadio()
    signal wifiRescan()
    signal wifiConnectKnown(var net)
    signal wifiConnectNew(string ssid, string password)
    signal wifiDisconnect(var net)
    signal wifiForget(var net)
    signal wifiFetchPassword(string ssid, int idx)
    signal wifiCopyPassword(string ssid)
    signal wifiSelectIdx(int idx)
    signal wifiPasswordChanged(int idx, string pw)
    signal wifiPasswordFetched(int idx, string pw)
    signal wifiStatusMessage(string msg)

    onWifiPasswordFetched: (idx, pw) => wifiPanelInst.passwordFetched(idx, pw)

    // Bluetooth signals
    signal btTogglePower()
    signal btToggleScan()
    signal btConnect(var device)
    signal btDisconnect(var device)
    signal btPair(var device)
    signal btForget(var device)
    signal btSetCodec(string mac, string profile)

    // Audio signals
    signal audioSetDefaultSink(var entry)
    signal audioSetDefaultSource(var entry)

    // Power signals
    signal powerSetProfile(var profile)

    // Language signals
    signal langSelectTab(string tab)
    signal langSearchQuery(string query)
    signal langSetLayout(string code)
    signal langSetLocale(string value)

    // ── Visibilidad ───────────────────────────────────────────────────────
    visible: root.activePanel !== ""

    // ── Backdrop ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    // ── Panel container — alineado a la derecha (mismo margen que ccCard) ─
    Item {
        anchors {
            right: parent.right
            rightMargin: 12
            top: parent.top
            topMargin: 150
        }
        width: childrenRect.width
        height: childrenRect.height

        // Animación de entrada
        scale: root.visible ? 1.0 : 0.94
        opacity: root.visible ? 1.0 : 0.0
        Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // ── WiFi Panel ────────────────────────────────────────────────────
        CcWifiPanel {
            id: wifiPanelInst
            visible: root.activePanel === "wifi"

            nmWifiDev:          root.nmWifiDev
            wifiRadioOn:        root.wifiRadioOn
            wifiScanning:       root.wifiScanning
            wifiWorking:        root.wifiWorking
            wifiStatusMsg:      root.wifiStatusMsg
            wifiSelectedIdx:    root.wifiSelectedIdx
            wifiPasswordByIndex: root.wifiPasswordByIndex
            wifiConnectedSsid:  root.wifiConnectedSsid
            ethConnected:       root.ethConnected
            ethIp:              root.ethIp
            ethSpeed:           root.ethSpeed
            wifiIp:             root.wifiIp
            wifiGateway:        root.wifiGateway
            wifiDns:            root.wifiDns
            onCloseRequested:     root.closePanel()
            onToggleRadio:        root.wifiToggleRadio()
            onRescan:             root.wifiRescan()
            onConnectKnown: (net) => root.wifiConnectKnown(net)
            onConnectNew: (ssid, pw) => root.wifiConnectNew(ssid, pw)
            onDisconnectNet: (net) => root.wifiDisconnect(net)
            onForgetNet: (net) => root.wifiForget(net)
            onFetchPassword: (ssid, idx) => root.wifiFetchPassword(ssid, idx)
            onCopyPassword: (ssid) => root.wifiCopyPassword(ssid)
            onSelectNetwork: (idx) => root.wifiSelectIdx(idx)
            onPasswordChanged: (idx, pw) => root.wifiPasswordChanged(idx, pw)
            onStatusMessage: (msg) => root.wifiStatusMessage(msg)
        }

        // ── Bluetooth Panel ───────────────────────────────────────────────
        CcBluetoothPanel {
            visible: root.activePanel === "bluetooth"

            btAdapter:     root.btAdapter
            btAvailable:   root.btAvailable
            btPwrd:        root.btPwrd
            btScanning:    root.btScanning
            btWorking:     root.btWorking
            btStatusMsg:   root.btStatusMsg
            btPairedList:  root.btPairedList
            btNearbyList:  root.btNearbyList
            btPairedCount: root.btPairedCount
            btNearbyCount: root.btNearbyCount
            btCodecData:   root.btCodecData

            onCloseRequested:          root.closePanel()
            onTogglePower:             root.btTogglePower()
            onToggleScan:              root.btToggleScan()
            onConnectDevice: (d)    => root.btConnect(d)
            onDisconnectDevice: (d) => root.btDisconnect(d)
            onPairDevice: (d)       => root.btPair(d)
            onForgetDevice: (d)     => root.btForget(d)
            onSetCodec: (mac, prof) => root.btSetCodec(mac, prof)
        }

        // ── Audio Panel ───────────────────────────────────────────────────
        CcAudioPanel {
            visible: root.activePanel === "audio"

            audioSinks:   root.audioSinks
            audioSources: root.audioSources

            onCloseRequested:          root.closePanel()
            onSetDefaultSink: (e)   => root.audioSetDefaultSink(e)
            onSetDefaultSource: (e) => root.audioSetDefaultSource(e)
        }

        // ── Power Panel ───────────────────────────────────────────────────
        CcPowerPanel {
            visible: root.activePanel === "power"

            fanProfiles: root.fanProfiles
            fanProfile:  root.fanProfile

            onCloseRequested: root.closePanel()
            onSetPower: (p) => root.powerSetProfile(p)
        }

        // ── Battery Panel ─────────────────────────────────────────────────
        CcBatteryPanel {
            visible: root.activePanel === "battery"

            batAvailable:  root.batAvailable
            batPct:        root.batPct
            batCharging:   root.batCharging
            batFull:       root.batFull
            batHealth:     root.batHealth
            batCapWh:      root.batCapWh
            batEnergy:     root.batEnergy
            batChangeRate: root.batChangeRate
            batTimeEmpty:  root.batTimeEmpty
            batTimeFull:   root.batTimeFull

            onCloseRequested: root.closePanel()
        }

        // ── CPU Panel ─────────────────────────────────────────────────────
        CcCpuPanel {
            visible: root.activePanel === "cpu"

            cpuAvailable: root.cpuAvailable
            cpuPercent:   root.cpuPercent
            cpuTemp:      root.cpuTemp

            onCloseRequested: root.closePanel()
        }

        // ── RAM Panel ─────────────────────────────────────────────────────
        CcRamPanel {
            visible: root.activePanel === "ram"

            ramAvailable: root.ramAvailable
            ramPercent:   root.ramPercent
            ramUsedGb:    root.ramUsedGb
            ramTotalGb:   root.ramTotalGb
            ramAvailGb:   root.ramAvailGb
            swapPercent:  root.swapPercent

            onCloseRequested: root.closePanel()
        }

        // ── GPU Panel ─────────────────────────────────────────────────────
        CcGpuPanel {
            visible: root.activePanel === "gpu"

            gpuAvailable:  root.gpuAvailable
            gpuPercent:    root.gpuPercent
            gpuTemp:       root.gpuTemp
            gpuName:       root.gpuName
            gpuVramUsedMb: root.gpuVramUsedMb
            gpuVramTotalMb: root.gpuVramTotalMb

            onCloseRequested: root.closePanel()
        }

        // ── Language Panel ────────────────────────────────────────────────
        CcLanguagePanel {
            visible: root.activePanel === "language"

            filteredLayouts: root.filteredLayouts
            filteredLocales: root.filteredLocales
            langLayout:      root.langLayout
            langLocale:      root.langLocale
            langTab:         root.langTab
            langSearch:      root.langSearch

            onCloseRequested:          root.closePanel()
            onTabChanged: (tab)     => root.langSelectTab(tab)
            onSearchChanged: (q)    => root.langSearchQuery(q)
            onSetLayout: (code)     => root.langSetLayout(code)
            onSetLocale: (value)    => root.langSetLocale(value)
        }
    }
}

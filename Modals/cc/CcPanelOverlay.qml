import QtQuick
import qs.Modals.cc
pragma ComponentBehavior: Bound

// Overlay de paneles del Control Center
// Muestra un backdrop + el panel activo, alineado a la derecha.
Item {
    id: root

    // Inputs desde ControlCenter
    required property string activePanel          // "wifi"|"bluetooth"|"audio"|"power"|"battery"|"language"|""

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

    required property var audioSinks
    required property var audioSources

    required property var    fanProfiles
    required property string fanProfile

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

    required property var    filteredLayouts
    required property var    filteredLocales
    required property string langLayout
    required property string langLocale
    required property string langTab
    required property string langSearch

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

    // wifiPanelInst ya no es accesible directamente (está dentro del Loader).
    // Se accede via wifiLoader.item para llamar el método passwordFetched.
    onWifiPasswordFetched: (idx, pw) => {
        const w = wifiLoader.item as CcWifiPanel
        if (w) w.passwordFetched(idx, pw)
    }

    // Bluetooth signals
    signal btTogglePower()
    signal btToggleScan()
    signal btConnect(var device)
    signal btDisconnect(var device)
    signal btPair(var device)
    signal btCancelPair(var device)
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

    // Visibilidad
    visible: root.activePanel !== ""

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    // Panel container — alineado a la derecha (mismo margen que ccCard)
    Item {
        id: panelHost
        anchors {
            right: parent.right
            rightMargin: 12
            top: parent.top
            topMargin: 150
        }
        // Tamaño implícito del panel visible. El loop sobre children.visible fallaba con Loaders porque el item se instancia de forma asíncrona: el binding se evaluaba antes
        // de que el Loader completara la carga y visible fuera true. Solución: leer implicitWidth/implicitHeight del Loader activo por id, con Qt.binding para re-evaluar cuando statusChanged dispare.
        width:  _activeLoader ? _activeLoader.implicitWidth  : 0
        height: _activeLoader ? _activeLoader.implicitHeight : 0

        // Re-evalúa cuando el Loader activo termina de instanciar su item. Un timer de un solo disparo
        // diferido asegura que el binding se re-evalúa DESPUÉS de que el Loader completa la carga asíncrona.
        property int _loaderRevision: 0
        readonly property Loader _activeLoader: {
            const _ = root.activePanel
            const __ = _loaderRevision     // dependency: re-evalúa en cada bump
            for (const child of panelHost.children) {
                const loader = child as Loader
                if (loader && loader.active) return loader
            }
            return null
        }

        Timer {
            id: loaderReadyTimer
            interval: 0          // dispara en el próximo event loop tick
            repeat: false
            onTriggered: panelHost._loaderRevision++
        }

        Connections {
            target: root
            function onActivePanelChanged() {
                // Cuando cambia el panel, diferir la actualización de tamaño
                // para que el Loader tenga tiempo de instanciar su item.
                loaderReadyTimer.restart()
            }
        }

        // Animación de entrada
        scale: root.visible ? 1.0 : 0.94
        opacity: root.visible ? 1.0 : 0.0
        Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // WiFi Panel
        Loader {
            id: wifiLoader
            active: root.activePanel === "wifi"
            sourceComponent: Component {
                CcWifiPanel {
                    nmWifiDev:           root.nmWifiDev
                    wifiRadioOn:         root.wifiRadioOn
                    wifiScanning:        root.wifiScanning
                    wifiWorking:         root.wifiWorking
                    wifiStatusMsg:       root.wifiStatusMsg
                    wifiSelectedIdx:     root.wifiSelectedIdx
                    wifiPasswordByIndex: root.wifiPasswordByIndex
                    wifiConnectedSsid:   root.wifiConnectedSsid
                    ethConnected:        root.ethConnected
                    ethIp:               root.ethIp
                    ethSpeed:            root.ethSpeed
                    wifiIp:              root.wifiIp
                    wifiGateway:         root.wifiGateway
                    wifiDns:             root.wifiDns
                    onCloseRequested:      root.closePanel()
                    onToggleRadio:         root.wifiToggleRadio()
                    onRescan:              root.wifiRescan()
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
            }
        }

        // Bluetooth Panel
        Loader {
            active: root.activePanel === "bluetooth"
            sourceComponent: Component {
                CcBluetoothPanel {
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
                    onCancelPairDevice: (d) => root.btCancelPair(d)
                    onForgetDevice: (d)     => root.btForget(d)
                    onSetCodec: (mac, prof) => root.btSetCodec(mac, prof)
                }
            }
        }

        // Audio Panel
        Loader {
            active: root.activePanel === "audio"
            sourceComponent: Component {
                CcAudioPanel {
                    audioSinks:   root.audioSinks
                    audioSources: root.audioSources
                    onCloseRequested:          root.closePanel()
                    onSetDefaultSink: (e)   => root.audioSetDefaultSink(e)
                    onSetDefaultSource: (e) => root.audioSetDefaultSource(e)
                }
            }
        }

        // Power Panel
        Loader {
            active: root.activePanel === "power"
            sourceComponent: Component {
                CcPowerPanel {
                    fanProfiles: root.fanProfiles
                    fanProfile:  root.fanProfile
                    onCloseRequested: root.closePanel()
                    onSetPower: (p) => root.powerSetProfile(p)
                }
            }
        }

        // Battery Panel
        Loader {
            active: root.activePanel === "battery"
            sourceComponent: Component {
                CcBatteryPanel {
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
            }
        }

        // Language Panel
        Loader {
            active: root.activePanel === "language"
            sourceComponent: Component {
                CcLanguagePanel {
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
    }
}

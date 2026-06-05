import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking
import "../../Components"

// ── Panel WiFi — popup del Control Center ────────────────────────────────────
Rectangle {
    id: root

    implicitWidth: 340
    implicitHeight: wifiDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
        border.width: 1
    }

    // ── Inputs ────────────────────────────────────────────────────────────
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
    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()
    signal toggleRadio()
    signal rescan()
    signal connectKnown(var net)
    signal connectNew(string ssid, string password)
    signal disconnectNet(var net)
    signal forgetNet(var net)
    signal fetchPassword(string ssid, int idx)
    signal copyPassword(string ssid)
    signal selectNetwork(int idx)
    signal passwordChanged(int idx, string pw)
    signal passwordFetched(int idx, string pw)

    // ── Estado interno ────────────────────────────────────────────────────
    property int _fetchingIdx: -1

    // ── Helpers ───────────────────────────────────────────────────────────
    function wifiSignalIcon(strength) {
        if (strength >= 0.80) return "󰤨"
        if (strength >= 0.60) return "󰤥"
        if (strength >= 0.40) return "󰤢"
        return "󰤟"
    }

    function wifiSecurityLabel(sec) {
        if (sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe) return "Open"
        if (sec === WifiSecurityType.Wpa3SuiteB192 || sec === WifiSecurityType.Sae) return "WPA3"
        if (sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.Wpa2Eap) return "WPA2"
        if (sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.WpaEap) return "WPA"
        if (sec === WifiSecurityType.StaticWep || sec === WifiSecurityType.DynamicWep) return "WEP"
        return ""
    }

    function wifiIsOpen(sec) {
        return sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe
    }

    // ── Contenido ─────────────────────────────────────────────────────────
    Column {
        id: wifiDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 6

        // ── Header ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 32

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text {
                    text: root.wifiRadioOn ? "󰤨" : "󰤮"
                    font.pixelSize: 16
                    color: root.wifiRadioOn ? Theme.accent : Theme.muted2
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { text: "WiFi"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        text: root.wifiConnectedSsid ? root.wifiConnectedSsid
                              : (root.wifiRadioOn ? "Desconectado" : "Radio apagada")
                        font.pixelSize: 9; color: Theme.muted1
                    }
                }
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                // Rescan
                Rectangle {
                    visible: root.wifiRadioOn
                    width: 26; height: 26; radius: 7
                    color: wRescanMA.containsMouse ? Theme.surface3 : Theme.surface2
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 13
                        color: root.wifiScanning ? Theme.accent : Theme.muted1
                        RotationAnimation on rotation {
                            running: root.wifiScanning; loops: Animation.Infinite
                            from: 0; to: 360; duration: 1200
                        }
                    }
                    MouseArea {
                        id: wRescanMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rescan()
                    }
                }

                // Toggle radio
                Rectangle {
                    width: 40; height: 22; radius: 11
                    color: root.wifiRadioOn ? Theme.accent : Theme.surface3
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 16; height: 16; radius: 8; color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.wifiRadioOn ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 200 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleRadio()
                    }
                }

                // Close button
                Rectangle {
                    width: 26; height: 26; radius: 7
                    color: wCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                    MouseArea {
                        id: wCloseMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

        // ── Status / working — un solo Text, tres estados ─────────────────
        Text {
            visible: root.wifiWorking || root.wifiStatusMsg !== ""
            text:  root.wifiWorking ? "Conectando…" : root.wifiStatusMsg
            font.pixelSize: 10
            color: root.wifiWorking
                   ? Theme.muted1
                   : root.wifiStatusMsg.startsWith("✓") ? Theme.success : Theme.error
        }

        // ── Ethernet info ─────────────────────────────────────────────────
        Rectangle {
            visible: root.ethConnected
            width: parent.width; height: root.ethConnected ? 44 : 0
            radius: 8; color: Theme.successSurface
            border.color: Qt.tint(Theme.surface2, Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.30))
            Behavior on height { NumberAnimation { duration: 150 } }
            Row {
                anchors { fill: parent; margins: 10 }
                spacing: 10
                Text { text: "󰈀"; font.pixelSize: 16; color: Theme.success; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    spacing: 1; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Ethernet"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text { text: root.ethIp || "Sin IP"; font.pixelSize: 9; color: Theme.muted1 }
                }
                Item { width: 1 }
                Text {
                    visible: root.ethSpeed !== ""
                    text: root.ethSpeed; font.pixelSize: 9; color: Theme.muted1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Radio off ─────────────────────────────────────────────────────
        Item {
            visible: !root.wifiRadioOn
            width: parent.width; height: 36
            Text { anchors.centerIn: parent; text: "WiFi está apagado"; font.pixelSize: 11; color: Theme.muted1 }
        }

        // ── Network list ──────────────────────────────────────────────────
        Column {
            visible: root.wifiRadioOn && root.nmWifiDev !== null
            width: parent.width; spacing: 4

            Repeater {
                model: {
                    var dev = root.nmWifiDev
                    if (!dev) return []
                    var nets = dev.networks.values.slice()
                    nets.sort(function(a, b) {
                        if (a.connected !== b.connected) return a.connected ? -1 : 1
                        return b.signalStrength - a.signalStrength
                    })
                    return nets
                }

                Column {
                    id: wNetRow
                    required property var modelData
                    required property int index
                    width: parent.width; spacing: 0

                    property bool   showPwText:    false
                    property string realPassword:  ""
                    property bool   fetchingPw:    false

                    function fetchSavedPassword() {
                        if (realPassword !== "" || fetchingPw) {
                            showPwText = !showPwText
                            return
                        }
                        // Cancelar fetch previo en vuelo para otra fila
                        root._fetchingIdx = index
                        fetchingPw = true
                        root.fetchPassword(modelData.name, index)
                    }

                    Connections {
                        target: root
                        function onPasswordFetched(idx, pw) {
                            if (idx !== index) return
                            if (root._fetchingIdx !== index) return   // resultado obsoleto
                            wNetRow.realPassword = pw
                            wNetRow.fetchingPw   = false
                            root._fetchingIdx    = -1
                            if (pw !== "") wNetRow.showPwText = true
                        }
                    }

                    // ── Network row ───────────────────────────────────────
                    Rectangle {
                        width: parent.width; height: 36; radius: 8
                        color: {
                            if (wNetRow.modelData.connected)          return Theme.accentSurface
                            if (root.wifiSelectedIdx === index)       return Theme.surface3
                            return wRowMA.containsMouse ? Theme.surface3 : Theme.surface2
                        }
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: wNetRow.modelData.connected
                            width: 3; height: 18; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 6

                            Text {
                                text: root.wifiSignalIcon(wNetRow.modelData.signalStrength)
                                font.pixelSize: 13
                                color: wNetRow.modelData.connected ? Theme.accent : Theme.muted2
                            }
                            Text {
                                Layout.fillWidth: true
                                text: wNetRow.modelData.name
                                font.pixelSize: 11; color: Theme.text; elide: Text.ElideRight
                            }
                            Text {
                                visible: !root.wifiIsOpen(wNetRow.modelData.security)
                                text: "󰌆"; font.pixelSize: 10; color: Theme.muted2
                            }
                            Text {
                                text: Math.round(wNetRow.modelData.signalStrength * 100) + "%"
                                font.pixelSize: 9; color: Theme.muted2; width: 28
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                height: 22; radius: 6
                                width: wNetRow.modelData.connected ? 78 : 64
                                color: wNetRow.modelData.connected ? Theme.error
                                     : (root.wifiSelectedIdx === index ? Theme.accent : Theme.surface3)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: wNetRow.modelData.connected ? "Desconectar" : "Conectar"
                                    font.pixelSize: 9; color: "white"
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (wNetRow.modelData.connected) {
                                            root.disconnectNet(wNetRow.modelData)
                                        } else if (root.wifiSelectedIdx !== index) {
                                            root.selectNetwork(index)
                                            root.passwordChanged(index, "")
                                            wNetRow.showPwText = false
                                        } else {
                                            var needsPw = !root.wifiIsOpen(wNetRow.modelData.security)
                                            var pw = root.wifiPasswordByIndex[index] || ""
                                            if (!needsPw || wNetRow.modelData.known) {
                                                root.connectKnown(wNetRow.modelData)
                                            } else if (pw !== "") {
                                                root.connectNew(wNetRow.modelData.name, pw)
                                            } else {
                                                // status msg handled by parent
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: wRowMA
                            anchors.fill: parent; hoverEnabled: true; z: -1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = (root.wifiSelectedIdx === index) ? -1 : index
                                root.selectNetwork(next)
                                if (next === index) {
                                    root.passwordChanged(index, "")
                                    wNetRow.showPwText = false
                                }
                            }
                        }
                    }

                    // ── Expanded panel ────────────────────────────────────
                    Rectangle {
                        visible: root.wifiSelectedIdx === index
                        width: parent.width
                        height: visible ? wExpandCol.implicitHeight + 20 : 0
                        radius: 8; color: Theme.surface3; clip: true
                        Behavior on height { NumberAnimation { duration: 150 } }

                        Rectangle {
                            anchors.fill: parent; radius: parent.radius; color: "transparent"
                            border.color: Theme.accentSurface; border.width: 1
                        }

                        Column {
                            id: wExpandCol
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                            spacing: 6

                            // ── Password field ────────────────────────────
                            RowLayout {
                                visible: !root.wifiIsOpen(wNetRow.modelData.security) && !wNetRow.modelData.connected
                                width: parent.width; spacing: 6

                                Text { text: "󰌋"; font.pixelSize: 12; color: Theme.muted1; Layout.alignment: Qt.AlignVCenter }

                                Item {
                                    Layout.fillWidth: true; height: 22

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: wNetRow.modelData.known && !wNetRow.showPwText
                                        text: "••••••••"; font.pixelSize: 12; color: Theme.muted1
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: wNetRow.modelData.known && wNetRow.showPwText
                                        text: wNetRow.realPassword !== "" ? wNetRow.realPassword : "—"
                                        font.pixelSize: 11; color: Theme.text; font.family: "monospace"
                                    }
                                    TextInput {
                                        id: wPwInput
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                        visible: !wNetRow.modelData.known
                                        text: root.wifiPasswordByIndex[index] || ""
                                        onTextChanged: root.passwordChanged(index, text)
                                        echoMode: wNetRow.showPwText ? TextInput.Normal : TextInput.Password
                                        color: Theme.text; font.pixelSize: 11
                                        verticalAlignment: TextInput.AlignVCenter
                                        Keys.onReturnPressed: {
                                            var pw = root.wifiPasswordByIndex[index] || ""
                                            if (pw !== "") root.connectNew(wNetRow.modelData.name, pw)
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !wNetRow.modelData.known && wPwInput.text.length === 0
                                        text: "Contraseña"; font.pixelSize: 11; color: Theme.muted2
                                    }
                                }

                                Rectangle {
                                    width: 24; height: 24; radius: 6
                                    color: wEyeMA.containsMouse ? Theme.surface2 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: wNetRow.showPwText ? "󰈊" : "󰈉"
                                        font.pixelSize: 13
                                        color: wNetRow.showPwText ? Theme.accent : Theme.muted2
                                    }
                                    MouseArea {
                                        id: wEyeMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wNetRow.fetchSavedPassword()
                                    }
                                }

                                Rectangle {
                                    visible: wNetRow.modelData.known
                                    width: 24; height: 24; radius: 6
                                    color: wCopyPwMA.containsMouse ? Theme.surface2 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "󰂏"; font.pixelSize: 12; color: Theme.muted1 }
                                    MouseArea {
                                        id: wCopyPwMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.copyPassword(wNetRow.modelData.name)
                                    }
                                }
                            }

                            Rectangle {
                                visible: !root.wifiIsOpen(wNetRow.modelData.security) && !wNetRow.modelData.connected
                                width: parent.width; height: 1; color: Theme.surface2
                            }

                            // ── Info ──────────────────────────────────────
                            Column {
                                width: parent.width; spacing: 3

                                Row {
                                    spacing: 4
                                    Text { text: "Señal:";     font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                    Text { text: Math.round(wNetRow.modelData.signalStrength * 100) + "%"; font.pixelSize: 10; color: Theme.text }
                                }
                                Row {
                                    spacing: 4
                                    Text { text: "Seguridad:"; font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                    Text { text: root.wifiSecurityLabel(wNetRow.modelData.security); font.pixelSize: 10; color: Theme.text }
                                }
                                Row {
                                    spacing: 4
                                    Text { text: "Estado:";    font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                    Text {
                                        text: wNetRow.modelData.connected ? "Conectada"
                                            : (wNetRow.modelData.known ? "Guardada" : "No guardada")
                                        font.pixelSize: 10; color: Theme.text
                                    }
                                }
                                Row {
                                    visible: wNetRow.modelData.connected
                                    spacing: 4
                                    Text { text: "IP:";        font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                    Text {
                                        text: root.wifiIp !== "" ? root.wifiIp : "—"
                                        font.pixelSize: 10; color: Theme.text
                                        elide: Text.ElideRight; width: wExpandCol.width - 76
                                    }
                                }
                                Row {
                                    visible: wNetRow.modelData.connected
                                    spacing: 4
                                    Text { text: "Gateway:";   font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                    Text { text: root.wifiGateway !== "" ? root.wifiGateway : "—"; font.pixelSize: 10; color: Theme.text }
                                }
                                Row {
                                    visible: wNetRow.modelData.connected
                                    spacing: 4
                                    Text { text: "DNS:";       font.pixelSize: 10; color: Theme.muted1; width: 72 }
                                    Text { text: root.wifiDns !== "" ? root.wifiDns : "—"; font.pixelSize: 10; color: Theme.text }
                                }
                            }

                            // ── Forget ────────────────────────────────────
                            Row {
                                visible: wNetRow.modelData.known
                                width: parent.width
                                Rectangle {
                                    height: 24; radius: 6
                                    width: wForgetText.implicitWidth + 18
                                    color: wForgetMA.containsMouse
                                        ? Qt.tint(Theme.surface2, Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18))
                                        : Theme.surface2
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        id: wForgetText; anchors.centerIn: parent
                                        text: "󱑃  Olvidar red"; font.pixelSize: 10; color: Theme.error
                                    }
                                    MouseArea {
                                        id: wForgetMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.forgetNet(wNetRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { width: parent.width; height: 4 }
    }
}

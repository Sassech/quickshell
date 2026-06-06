import QtQuick
import QtQuick.Layouts
import "../../Components"

// ── Panel Bluetooth — popup del Control Center ────────────────────────────────
Rectangle {
    id: root

    implicitWidth: 340
    implicitHeight: btDetailCol.implicitHeight + 32
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

    // ── Outputs ───────────────────────────────────────────────────────────
    signal closeRequested()
    signal togglePower()
    signal toggleScan()
    signal connectDevice(var device)
    signal disconnectDevice(var device)
    signal pairDevice(var device)
    signal forgetDevice(var device)
    signal setCodec(string mac, string profile)

    // ── Helpers ───────────────────────────────────────────────────────────
    function _deviceName(device) {
        return device.name || device.deviceName || device.address
    }

    // ── Estado de forget pendiente (clave: MAC del dispositivo) ───────────
    property var    _pendingForget:    ({})   // { "AA:BB:CC" : true }
    property string _forgetPendingMac: ""

    Timer {
        id: btForgetCancelTimer
        interval: 3000
        onTriggered: {
            if (root._forgetPendingMac !== "") {
                var pf = Object.assign({}, root._pendingForget)
                delete pf[root._forgetPendingMac]
                root._pendingForget = pf
                root._forgetPendingMac = ""
            }
        }
    }

    // ── Contenido ─────────────────────────────────────────────────────────
    Column {
        id: btDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 8

        // ── Header ─────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 32

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text {
                    text: "󰂯"; font.pixelSize: 16
                    color: root.btPwrd ? Theme.accent : Theme.muted2
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { text: "Bluetooth"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text }
                    Text {
                        text: !root.btAvailable ? "Sin adaptador"
                            : !root.btPwrd      ? "Apagado"
                            : root.btScanning   ? "Buscando..."
                            : "Encendido"
                        font.pixelSize: 9; color: Theme.muted1
                    }
                }
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                // Scan button
                Rectangle {
                    visible: root.btAvailable && root.btPwrd
                    width: 26; height: 26; radius: 7
                    color: btScanBtnMA.containsMouse
                        ? Theme.surface3
                        : (root.btScanning ? Theme.accentSurface : Theme.surface2)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 13
                        color: root.btScanning ? Theme.accent : Theme.muted1
                        RotationAnimation on rotation {
                            running: root.btScanning; loops: Animation.Infinite
                            from: 0; to: 360; duration: 1200
                        }
                    }
                    MouseArea {
                        id: btScanBtnMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleScan()
                    }
                }

                // Power toggle
                Rectangle {
                    visible: root.btAvailable
                    width: 40; height: 22; radius: 11
                    color: root.btPwrd ? Theme.accent : Theme.surface3
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 16; height: 16; radius: 8; color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.btPwrd ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 200 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePower()
                    }
                }

                // Close button
                Rectangle {
                    width: 26; height: 26; radius: 7
                    color: btCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                    MouseArea {
                        id: btCloseMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

        // ── Status message ─────────────────────────────────────────────────
        Text {
            visible: root.btWorking || root.btStatusMsg !== ""
            text: root.btWorking ? "Trabajando…" : root.btStatusMsg
            font.pixelSize: 10
            color: root.btWorking ? Theme.muted1
                 : root.btStatusMsg.startsWith("✓") ? Theme.success : Theme.error
        }

        // ── No adapter ─────────────────────────────────────────────────────
        Item {
            visible: !root.btAvailable
            width: parent.width; height: 40
            Text {
                anchors.centerIn: parent
                text: "No se encontró adaptador Bluetooth"
                font.pixelSize: 11; color: Theme.muted1
            }
        }

        // ── Off message ────────────────────────────────────────────────────
        Item {
            visible: root.btAvailable && !root.btPwrd
            width: parent.width; height: 36
            Text {
                anchors.centerIn: parent
                text: "Enciende el Bluetooth para ver dispositivos"
                font.pixelSize: 10; color: Theme.muted1
            }
        }

        // ── Device lists ───────────────────────────────────────────────────
        Column {
            visible: root.btAvailable && root.btPwrd
            width: parent.width; spacing: 4

            // Paired label
            Text {
                visible: root.btPairedCount > 0
                text: "Dispositivos emparejados"
                font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
            }

            Repeater {
                model: root.btPairedList

                Column {
                    id: btPairedEntry
                    required property var modelData
                    required property int index
                    width: parent.width; spacing: 4

                    property string devMac:   modelData.address.toUpperCase()
                    property var    cInfo:    root.btCodecData[devMac] ?? null
                    property bool   hasCodec: modelData.connected
                                              && cInfo !== null
                                              && (cInfo.profiles?.length ?? 0) > 0
                    property bool   pendingForget: root._pendingForget[devMac] === true

                    Rectangle {
                        width: parent.width; height: 38; radius: 8
                        color: btPairedEntry.modelData.connected
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                            : Theme.surface3

                        Rectangle {
                            visible: btPairedEntry.modelData.connected
                            width: 3; height: 18; radius: 2
                            anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 6

                            Text {
                                text: "󰂱"; font.pixelSize: 14
                                color: btPairedEntry.modelData.connected ? Theme.accent : Theme.muted2
                            }

                            Column {
                                Layout.fillWidth: true; spacing: 1
                                Text {
                                    text: root._deviceName(btPairedEntry.modelData)
                                    font.pixelSize: 11; color: Theme.text
                                    elide: Text.ElideRight; width: parent.width
                                }
                                Text {
                                    text: btPairedEntry.modelData.address
                                    font.pixelSize: 8; color: Theme.muted2
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 24; radius: 6
                                Layout.preferredWidth: btConnBtnText.implicitWidth + 16
                                color: btPairedEntry.modelData.connected ? Theme.error : Theme.accent
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    id: btConnBtnText; anchors.centerIn: parent
                                    text: btPairedEntry.modelData.connected ? "Desconectar" : "Conectar"
                                    font.pixelSize: 9; color: "white"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.btWorking
                                    cursorShape: root.btWorking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (btPairedEntry.modelData.connected)
                                            root.disconnectDevice(btPairedEntry.modelData)
                                        else
                                            root.connectDevice(btPairedEntry.modelData)
                                    }
                                }
                            }

                            // Forget button (2-step confirm)
                            Rectangle {
                                id: btForgetBtn
                                Layout.preferredHeight: 24; radius: 6
                                Layout.preferredWidth: btPairedEntry.pendingForget
                                    ? btForgetConfirmText.implicitWidth + 14
                                    : 24
                                Behavior on width { NumberAnimation { duration: 120 } }
                                color: btPairedEntry.pendingForget
                                    ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                    : (btForgetMA.containsMouse
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14)
                                        : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !btPairedEntry.pendingForget
                                    text: "󰩹"; font.pixelSize: 13
                                    color: btForgetMA.containsMouse ? Theme.error : Theme.muted2
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    id: btForgetConfirmText; anchors.centerIn: parent
                                    visible: btPairedEntry.pendingForget
                                    text: "¿Borrar?"; font.pixelSize: 9; color: Theme.error
                                }
                                MouseArea {
                                    id: btForgetMA; anchors.fill: parent; hoverEnabled: true
                                    enabled: !root.btWorking
                                    cursorShape: root.btWorking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (!btPairedEntry.pendingForget) {
                                            var pf = Object.assign({}, root._pendingForget)
                                            pf[btPairedEntry.devMac] = true
                                            root._pendingForget = pf
                                            root._forgetPendingMac = btPairedEntry.devMac
                                            btForgetCancelTimer.restart()
                                        } else {
                                            btForgetCancelTimer.stop()
                                            var pf2 = Object.assign({}, root._pendingForget)
                                            delete pf2[btPairedEntry.devMac]
                                            root._pendingForget = pf2
                                            root._forgetPendingMac = ""
                                            root.forgetDevice(btPairedEntry.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Codec panel ────────────────────────────────────────
                    Rectangle {
                        visible: btPairedEntry.hasCodec
                        width: parent.width; height: 34; radius: 7
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 6

                            Column {
                                spacing: 1
                                Text {
                                    text: "Codec: " + (btPairedEntry.cInfo?.codec ?? "")
                                    font.pixelSize: 9; font.weight: Font.DemiBold; color: Theme.accent
                                }
                                Text {
                                    text: btPairedEntry.cInfo?.bitrate ?? ""
                                    font.pixelSize: 8; color: Theme.muted1
                                    visible: (btPairedEntry.cInfo?.bitrate ?? "") !== ""
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Repeater {
                                model: btPairedEntry.cInfo?.profiles ?? []
                                delegate: Rectangle {
                                    id: btProfileBtn
                                    required property var modelData
                                    property bool isActive: (btPairedEntry.cInfo?.active ?? "") === modelData.id
                                    height: 20; radius: 5
                                    width: btProfileLabel.implicitWidth + 10
                                    color: isActive ? Theme.accent
                                         : (btProfileMA.containsMouse ? Theme.surface3 : Theme.surface2)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        id: btProfileLabel; anchors.centerIn: parent
                                        text: btProfileBtn.modelData.label
                                        font.pixelSize: 8
                                        color: btProfileBtn.isActive ? "white" : Theme.muted1
                                    }
                                    MouseArea {
                                        id: btProfileMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setCodec(
                                            btPairedEntry.modelData.address,
                                            btProfileBtn.modelData.id
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.btPairedCount === 0 && !root.btWorking
                text: "No hay dispositivos emparejados"
                font.pixelSize: 10; color: Theme.muted1
            }

            // Nearby section
            Item { visible: root.btNearbyCount > 0; width: parent.width; height: 8 }

            Text {
                visible: root.btNearbyCount > 0
                text: "Dispositivos cercanos"
                font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
            }

            Repeater {
                model: root.btNearbyList

                Rectangle {
                    id: wNetRow
                    required property var modelData
                    width: parent.width; height: 38; radius: 8; color: Theme.surface3

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                        spacing: 6

                        Text { text: "󰂯"; font.pixelSize: 14; color: Theme.muted2 }

                        Column {
                            Layout.fillWidth: true; spacing: 1
                            Text {
                                text: root._deviceName(wNetRow.modelData)
                                font.pixelSize: 11; color: Theme.text
                                elide: Text.ElideRight; width: parent.width
                            }
                            Text { text: wNetRow.modelData.address; font.pixelSize: 8; color: Theme.muted2 }
                        }

                        Rectangle {
                            Layout.preferredHeight: 24; radius: 6; Layout.preferredWidth: btPairBtnLabel.implicitWidth + 16
                            color: Theme.surface2
                            Text {
                                id: btPairBtnLabel; anchors.centerIn: parent
                                text: "Emparejar"; font.pixelSize: 9; color: Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.pairDevice(wNetRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}

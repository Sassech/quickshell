import QtQuick
import QtQml
import Quickshell
import Quickshell.Bluetooth
import "../Components"

Rectangle {
    id: root

    implicitWidth:  labelRow.implicitWidth + 20
    implicitHeight: 24
    radius:         8
    color: ma.containsMouse ? Theme.surface3 : Theme.surface2

    signal clicked()

    property var  adapter:   Bluetooth.defaultAdapter
    property bool available: adapter !== null
    property bool powered:   adapter ? adapter.enabled : false

    property int devicesRevision: 0
    property var connectedDevices: {
        devicesRevision
        var all = Bluetooth.devices.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            if (all[i].connected) out.push(all[i])
        }
        return out
    }

    property bool   connected:  connectedDevices.length > 0
    property string deviceName: connected
        ? (connectedDevices[0].name || connectedDevices[0].deviceName)
        : ""

    Behavior on color { ColorAnimation { duration: 100 } }

    property string btIcon: {
        if (!available) return "󰂲"
        if (!powered)   return "󰂲"
        if (connected)  return "󰂱"
        return "󰂯"
    }

    property color btColor: {
        if (!available || !powered) return Theme.muted2
        if (connected) return Theme.accent
        return Theme.muted1
    }

    Connections {
        target: root.adapter ? root.adapter.devices : null
        function onObjectInsertedPost(object, index) { root.devicesRevision++ }
        function onObjectRemovedPost(object, index) { root.devicesRevision++ }
    }

    Instantiator {
        model: root.adapter ? root.adapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { root.devicesRevision++ }
            function onNameChanged() { root.devicesRevision++ }
            function onDeviceNameChanged() { root.devicesRevision++ }
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.btIcon
            font.pixelSize: 14
            color: root.btColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.available) return "No disp."
                if (!root.powered)   return "Apagado"
                if (root.connected)  return root.deviceName || "Conectado"
                return "BT"
            }
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.text
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

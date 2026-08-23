pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Bluetooth
import "../Components"

Rectangle {
    id: root

    implicitWidth:  labelRow.implicitWidth + 20
    implicitHeight: 24
    radius:         8
    color: Theme.surface2

    // Widget de solo estado — no emite clicks ni tiene hover

    // qmllint disable unresolved-type
    property var  adapter:   Bluetooth.defaultAdapter
    // qmllint enable unresolved-type
    property bool available: adapter !== null
    property bool powered:   adapter ? adapter.enabled : false

    property var connectedDevices: []
    property bool   connected:  connectedDevices.length > 0
    property string deviceName: connected
        ? (connectedDevices[0].name || connectedDevices[0].deviceName)
        : ""

    function _updateConnectedDevices() {
        var all = root.adapter ? root.adapter.devices.values : []
        var out = []
        for (var i = 0; i < all.length; i++) {
            if (all[i].connected) out.push(all[i])
        }
        root.connectedDevices = out
    }

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

    onAdapterChanged: _updateConnectedDevices()
    Component.onCompleted: _updateConnectedDevices()

    Connections {
        target: root.adapter ? root.adapter.devices : null
        function onObjectInsertedPost(object, index) { root._updateConnectedDevices() }
        function onObjectRemovedPost(object, index) { root._updateConnectedDevices() }
    }

    Instantiator {
        model: root.adapter ? root.adapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { root._updateConnectedDevices() }
            function onNameChanged() { root._updateConnectedDevices() }
            function onDeviceNameChanged() { root._updateConnectedDevices() }
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

}

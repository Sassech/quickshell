import QtQuick
import Quickshell.Services.SystemTray
import "../Components"

// Widget de System Tray usando el protocolo StatusNotifierItem (SNI)
// Detecta automáticamente apps como Discord, Spotify, Telegram, etc.
Item {
    id: root
    
    property int iconSize: 20
    property int spacing: 4
    
    implicitWidth: trayRow.implicitWidth
    implicitHeight: 28
    
    // El simple acceso a SystemTray.items activa el tracking de tray
    // No necesita polling - se actualiza automáticamente via D-Bus
    // Se declara para asegurar que se inicialice el tracking
    property var _trayItems: SystemTray.items
    
    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: root.spacing
        
        Repeater {
            model: SystemTray.items
            
            delegate: TrayIcon {
                required property var modelData
                trayItem: modelData
                size: root.iconSize
            }
        }
    }
    
    // Placeholder cuando no hay icons en el tray
    Text {
        anchors.centerIn: parent
        text: "󰒲"
        font.pixelSize: 14
        color: Theme.muted2
        visible: !root._trayItems || root._trayItems.length === 0
        opacity: 0.5
    }
}
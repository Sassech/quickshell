import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Hyprland
import "../Components"

// Componente individual para cada ícono del system tray
Rectangle {
    id: root
    
    // Propiedad requerida: objeto del modelo SystemTray
    required property var trayItem
    
    width: 28
    height: 28
    radius: 6
    color: mouseArea.containsMouse ? Theme.surface3 : "transparent"
    
    Behavior on color { ColorAnimation { duration: 100 } }
    
    // Ícono de la aplicación
    Image {
        id: icon
        anchors.centerIn: parent
        width: 18
        height: 18
        sourceSize.width: 18
        sourceSize.height: 18
        smooth: true
        
        // Obtener ícono del trayItem
        // El API de SystemTray típicamente expone: icon, iconPixmap, iconName
        source: {
            if (trayItem.icon) return trayItem.icon
            if (trayItem.iconName) return "image://icon/" + trayItem.iconName
            return ""
        }
        
        // Fallback si no hay ícono
        visible: status === Image.Ready
    }
    
    // Texto fallback si no hay ícono disponible
    Text {
        anchors.centerIn: parent
        text: icon.status !== Image.Ready ? "?" : ""
        font.pixelSize: 13
        color: Theme.muted1
        visible: icon.status !== Image.Ready
    }
    
    // Área interactiva
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                // Click izquierdo: intentar restaurar desde workspace especial
                // Extraer nombre de la app desde el trayItem
                var appName = ""
                if (trayItem.id) {
                    // El ID usualmente es algo como "org.kde.StatusNotifier-XXXXX"
                    // o directamente el nombre de la app
                    appName = trayItem.id.toLowerCase()
                    // Extraer nombre simple si es un DBus name
                    if (appName.includes("spotify")) appName = "spotify"
                    else if (appName.includes("discord")) appName = "discord"
                    else if (appName.includes("telegram")) appName = "telegram"
                    else if (appName.includes("slack")) appName = "slack"
                    else if (appName.includes("element")) appName = "element"
                    else if (appName.includes("signal")) appName = "signal"
                    else if (appName.includes("steam")) appName = "steam"
                } else if (trayItem.title) {
                    appName = trayItem.title.toLowerCase()
                }
                
                // Intentar restaurar desde special:minimized primero
                if (appName) {
                    Hyprland.dispatch("togglespecialworkspace minimized")
                }
                
                // Llamar al método activate() nativo del tray item como fallback
                if (trayItem.activate) {
                    trayItem.activate()
                }
            } else if (mouse.button === Qt.RightButton) {
                // Click derecho: mostrar menú contextual
                if (trayItem.openMenu) {
                    trayItem.openMenu()
                } else if (trayItem.contextMenu) {
                    trayItem.contextMenu()
                }
            }
        }
    }
    
    // Tooltip con el nombre de la aplicación
    ToolTip {
        visible: mouseArea.containsMouse
        delay: 800
        
        contentItem: Text {
            text: trayItem.title || trayItem.tooltip || trayItem.id || "App"
            color: Theme.text
            font.pixelSize: 11
        }
        
        background: Rectangle {
            color: Theme.surface3
            border.color: Theme.overlay
            border.width: 1
            radius: 4
        }
    }
    
    // Efecto visual al presionar
    scale: mouseArea.pressed ? 0.95 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 50 }
    }
}

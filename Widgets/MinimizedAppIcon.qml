import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import "../Components"

// Ícono para app minimizada en special:minimized workspace
Rectangle {
    id: root
    
    required property var app  // {class, title, address}
    property int size: 28
    
    width: size
    height: size
    radius: 6
    color: mouseArea.containsMouse ? Theme.surface3 : "transparent"
    
    Behavior on color { ColorAnimation { duration: 100 } }
    
    // Mapeo de clases a íconos (Nerd Font)
    function getIconForClass(cls) {
        var lower = cls.toLowerCase()
        if (lower.includes("spotify")) return "󰓇"
        if (lower.includes("discord")) return "󰙯"
        if (lower.includes("telegram")) return ""
        if (lower.includes("slack")) return "󰒱"
        if (lower.includes("signal")) return "󰻞"
        if (lower.includes("element")) return "󰊌"
        if (lower.includes("steam")) return "󰓓"
        if (lower.includes("chrome") || lower.includes("brave") || lower.includes("firefox")) return "󰈹"
        if (lower.includes("mail") || lower.includes("thunder")) return "󰇰"
        if (lower.includes("code") || lower.includes("vscode")) return "󰨞"
        if (lower.includes("terminal") || lower.includes("kitty") || lower.includes("alacritty")) return ""
        return "󰘔"  // ícono genérico de ventana
    }
    
    // Ícono de la aplicación
    Text {
        anchors.centerIn: parent
        text: getIconForClass(root.app.class)
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font"
        color: Theme.accent
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
                // Restaurar ventana al workspace actual
                Hyprland.dispatch("movetoworkspacesilent current,address:" + root.app.address)
                Hyprland.dispatch("focuswindow address:" + root.app.address)
            } else if (mouse.button === Qt.RightButton) {
                // Click derecho: cerrar completamente la app
                Hyprland.dispatch("closewindow address:" + root.app.address)
            }
        }
    }
    
    // Tooltip con el nombre de la aplicación
    ToolTip {
        visible: mouseArea.containsMouse
        delay: 500
        
        contentItem: Text {
            text: root.app.title || root.app.class
            color: Theme.text
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 2
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

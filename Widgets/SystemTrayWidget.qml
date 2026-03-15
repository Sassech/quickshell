import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../Components"

// Widget de "System Tray" que muestra ventanas minimizadas en special:minimized
// En lugar de usar StatusNotifierItem, consulta directamente hyprctl
Item {
    id: root
    
    // Propiedades configurables
    property int iconSize: 20
    property int spacing: 4
    
    // Lista de apps minimizadas: [{class: "spotify", title: "...", address: "..."}]
    property var minimizedApps: []
    
    // Cálculo automático del tamaño
    implicitWidth: trayRow.implicitWidth
    implicitHeight: 28
    
    // Visible solo si hay apps minimizadas
    visible: minimizedApps.length > 0
    
    // Polling periódico para actualizar la lista
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // No limpiar, solo iniciar el polling
            pollProc.running = true
        }
    }
    
    Process {
        id: pollProc
        command: ["bash", "/home/sassech/.config/quickshell/scripts/minimized-apps.sh"]
        
        property var tempApps: []
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!line || line.trim() === "") return
                
                var parts = line.split("|")
                if (parts.length >= 3) {
                    var app = {
                        class: parts[0],
                        title: parts[1],
                        address: parts[2]
                    }
                    pollProc.tempApps.push(app)
                }
            }
        }
        onExited: function() {
            // Actualizar solo si hay cambios (comparar addresses)
            var hasChanges = false
            
            if (pollProc.tempApps.length !== root.minimizedApps.length) {
                hasChanges = true
            } else {
                // Comparar addresses de las apps
                for (var i = 0; i < pollProc.tempApps.length; i++) {
                    var found = false
                    for (var j = 0; j < root.minimizedApps.length; j++) {
                        if (pollProc.tempApps[i].address === root.minimizedApps[j].address) {
                            found = true
                            break
                        }
                    }
                    if (!found) {
                        hasChanges = true
                        break
                    }
                }
            }
            
            if (hasChanges) {
                root.minimizedApps = pollProc.tempApps
                console.log("SystemTray: Updated to", pollProc.tempApps.length, "minimized apps")
            }
            
            pollProc.tempApps = []
        }
    }
    
    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: root.spacing
        
        Repeater {
            model: root.minimizedApps
            
            delegate: MinimizedAppIcon {
                required property var modelData
                app: modelData
                size: root.iconSize + 8
            }
        }
    }
    
    // Texto cuando no hay apps (no visible por el visible: false)
    Text {
        anchors.centerIn: parent
        text: "󰒲"
        font.pixelSize: 14
        color: Theme.muted2
        visible: root.minimizedApps.length === 0
        opacity: 0.5
    }
}

import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../Components"

// Widget de "System Tray" que muestra ventanas minimizadas en special:minimized
Item {
    id: root
    
    property int iconSize: 20
    property int spacing: 4
    
    property var minimizedApps: []
    
    implicitWidth: trayRow.implicitWidth
    implicitHeight: 28
    
    visible: minimizedApps.length > 0
    
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProc.running = true
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
                    pollProc.tempApps.push({
                        class: parts[0],
                        title: parts[1],
                        address: parts[2]
                    })
                }
            }
        }
        onExited: function() {
            var oldAddrs = root.minimizedApps.map(a => a.address)
            var newAddrs = pollProc.tempApps.map(a => a.address)
            
            var oldSet = new Set(oldAddrs)
            var newSet = new Set(newAddrs)
            
            var hasChanges = oldSet.size !== newSet.size
            if (!hasChanges) {
                for (var addr of newSet) {
                    if (!oldSet.has(addr)) {
                        hasChanges = true
                        break
                    }
                }
            }
            
            if (hasChanges) {
                root.minimizedApps = pollProc.tempApps
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
    
    Text {
        anchors.centerIn: parent
        text: "󰒲"
        font.pixelSize: 14
        color: Theme.muted2
        visible: root.minimizedApps.length === 0
        opacity: 0.5
    }
}

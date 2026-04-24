import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Hyprland
import "../Widgets"

PanelWindow {
    id: root
    
    signal powerButtonClicked(var screen)
    signal weatherClicked(var screen)
    signal batteryClicked(var screen)
    signal cpuClicked(var screen)
    signal ramClicked(var screen)
    signal diskClicked(var screen)
    signal gpuClicked(var screen)
    signal clipboardClicked(var screen)
    signal clockClicked(var screen)
    signal mediaClicked(var screen)
    
    // ── Aliases al WeatherProvider (instance lives in Weather widget) ───
    // Weather widget already has its own WeatherProvider; no duplicate here.
    // TopBar only needs to relay clicks to the modal.
    
    anchors {
        top: true
        left: true
        right: true
    }
    // #ee → 93%
    // #dd → 87%
    // #cc → 80%
    // #bb → 73%
    // #aa → 67%
    // #99 → 60%
    // #88 → 53%
    // #77 → 47%
    // #66 → 40%
    // #55 → 33%
    // #44 → 27%
    // #33 → 20%   
    implicitHeight: 30    // #ff → 100% (sólido)
    color: Theme.cardBg2
    
    Item {
        anchors.fill: parent
        anchors.margins: 6
        
        // LADO IZQUIERDO - Workspaces
        Row {
            id: leftSection
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 3
            
            Repeater {
                model: Hyprland.workspaces.values
                
                WorkspaceButton {
                    required property var modelData
                    workspace: modelData
                }
            }
        }
        
        // CENTRO - Clock y Media Player (absolutamente centrado)
        Row {
            id: centerSection
            anchors.centerIn: parent
            spacing: 10

            SystemTrayWidget {
                iconSize: 18
                spacing: 4
            }
            
            ClipboardWidget {
                id: clipboardWidget
                onClicked: root.clipboardClicked(root.screen)
            }
            IdleInhibitor {}

            Weather {
                id: weatherWidget
                onClicked: root.weatherClicked(root.screen)
            }
            
            Clock {
                id: clockWidget
                onClicked: root.clockClicked(root.screen)
            }

            Rectangle {
                radius: 6
                color: Theme.surface2
                implicitWidth: mediaPlayerContent.implicitWidth + 12
                implicitHeight: 28

                MediaPlayer {
                    id: mediaPlayerContent
                    anchors.centerIn: parent
                }

                // Click en zona vacía del contenedor → abrir MediaModal
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mediaClicked(root.screen)
                }
            }
        }
        
        // LADO DERECHO  Battery + Sysmon + Power button
        Row {
            id: rightSection
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 4
            }
            spacing: 8

            CpuWidget {
                onClicked: root.cpuClicked(root.screen)
            }
            RamWidget {
                onClicked: root.ramClicked(root.screen)
            }
            GpuWidget {
                onClicked: root.gpuClicked(root.screen)
            }
            DiskWidget {
                onClicked: root.diskClicked(root.screen)
            }
            BatteryWidget {
                id: batteryWidget
                onClicked: root.batteryClicked(root.screen)
            }
            PowerButton {
            onClicked: root.powerButtonClicked(root.screen)
            }
        }
    }
}

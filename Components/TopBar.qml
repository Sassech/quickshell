import QtQuick
import Quickshell
import Quickshell.Hyprland
import QtQuick.Layouts
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
    signal mediaClicked(var screen)
    // Propiedades expuestas del widget clima
    property alias weatherTemp:        weatherWidget.temperature
    property alias weatherFeelsLike:   weatherWidget.feelsLike
    property alias weatherWindSpeed:   weatherWidget.windSpeed
    property alias weatherHumidity:    weatherWidget.humidity
    property alias weatherCity:        weatherWidget.cityName
    property alias weatherIcon:        weatherWidget.weatherIcon
    property alias weatherDescription: weatherWidget.description
    property alias weatherIsDay:       weatherWidget.isDay
    
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
    implicitHeight: 35    // #ff → 100% (sólido)
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

            Clock {}

            Weather {
                id: weatherWidget
                onClicked: root.weatherClicked(root.screen)
            }

            Rectangle {
                radius: 6
                color: Theme.surface2
                implicitWidth: mediaPlayerContent.implicitWidth + 12
                implicitHeight: 28

                // TapHandler detecta clicks en zonas vacías (padding, visualizador, texto)
                // sin bloquear los botones ⏮/▶/⏭ que tienen sus propios MouseArea
                TapHandler {
                    onTapped: root.mediaClicked(root.screen)
                }

                MediaPlayer {
                    id: mediaPlayerContent
                    anchors.centerIn: parent
                }
            }
        }
        
        // LADO DERECHO - Sysmon + Battery + Power button
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
            Battery {
                onClicked: root.batteryClicked(root.screen)
            }
            PowerButton {
                onClicked: root.powerButtonClicked(root.screen)
            }
        }
    }
}

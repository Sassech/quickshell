// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Widgets"

PanelWindow {
    id: root
    
    signal weatherClicked(var screen)
    signal clipboardClicked(var screen)
    signal clockClicked(var screen)
    signal controlCenterClicked(var screen)

    function updateClipboardCount(n) { clipboardWidget.updateCount(n) }
    
    // ── Aliases al WeatherProvider (instance lives in Weather widget) ───
    // Weather widget already has its own WeatherProvider; no duplicate here.
    // TopBar only needs to relay clicks to the modal.
    
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 30
    color: Theme.cardBg2
    
    Item {
        anchors.fill: parent
        anchors.margins: 5
        
        // ── Left section — Workspaces ────────────────────────────────────
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
        Rectangle {
                radius: 6
                color: Theme.surface2
                implicitWidth: mediaPlayerContent.implicitWidth + 12
                implicitHeight: 28

                MediaPlayer {
                    id: mediaPlayerContent
                    anchors.centerIn: parent
                }
            }
        }
        
        // ── Center section — Tray, Clock, Media ───────────────────────────
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
        }
        
        // ── Right section — System monitors + Power ───────────────────────
        Row {
            id: rightSection
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 4
            }
            spacing: 8

            CpuWidget {}
            RamWidget {}
            GpuWidget {}
            DiskWidget {}
            BatteryWidget {}
            ControlCenterButton {
                onClicked: root.controlCenterClicked(root.screen)
            }
        }
    }
}

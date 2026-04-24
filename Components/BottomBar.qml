import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Wayland
import "../Widgets"

PanelWindow {
    id: root

    signal languageClicked(var screen)
    signal wifiClicked(var screen)
    signal bluetoothClicked(var screen)
    signal audioClicked(var screen)
    signal fanClicked(var screen)

    anchors {
        bottom: true
        left:   true
        right:  true
    }

    implicitHeight: 30
    color:          Theme.cardBg2

    WlrLayershell.layer: WlrLayer.Bottom

    RowLayout {
        anchors.fill:    parent
        anchors.margins: 6
        spacing:         8

        // ── Left section ─────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 4

            // Widgets here
        }

        Item { Layout.fillWidth: true }

        // ── Center section ───────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            spacing: 8

            // Widgets here
        }

        Item { Layout.fillWidth: true }

        // ── Right section ────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: 4
            spacing: 8

            AudioWidget {
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.audioClicked(root.screen)
            }

            NetworkWidget {
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.wifiClicked(root.screen)
            }

            BluetoothWidget {
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.bluetoothClicked(root.screen)
            }

            LanguageWidget {
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.languageClicked(root.screen)
            }
            FanWidget {
                id: fanWidget
                onClicked: root.fanClicked(root.screen)
            }
        }
    }
}


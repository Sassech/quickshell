import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Widgets"

PanelWindow {
    id: root

    signal languageClicked(var screen)
    signal wifiClicked(var screen)
    signal bluetoothClicked(var screen)
    signal audioClicked(var screen)

    anchors {
        bottom: true
        left:   true
        right:  true
    }

    implicitHeight: 35
    color:          Theme.cardBg2

    WlrLayershell.layer: WlrLayer.Bottom

    RowLayout {
        anchors.fill:    parent
        anchors.margins: 6
        spacing:         8

        // ── LADO IZQUIERDO ────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 4

            // Widgets izquierda aquí
        }

        Item { Layout.fillWidth: true }

        // ── CENTRO ────────────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            spacing: 8

            // Widgets centro aquí
        }

        Item { Layout.fillWidth: true }

        // ── LADO DERECHO ──────────────────────────────────────────────────
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
        }
    }
}


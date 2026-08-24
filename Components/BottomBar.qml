// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import QtQuick.Layouts
import "../Widgets"

PanelWindow {
    id: root

    anchors {
        bottom: true
        left:   true
        right:  true
    }

    implicitHeight: 30
    color:          Theme.cardBg2

    // No explicit WlrLayershell.layer: inherits default Layer.Top, consistent with TopBar so the bottom bar
    // renders above windows instead of competing with overlays in the Bottom layer.

    RowLayout {
        anchors.fill:    parent
        anchors.margins: 5
        spacing:         8

        Row {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 4

        }

        Item { Layout.fillWidth: true }

        Row {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            spacing: 8

        }

        Item { Layout.fillWidth: true }

        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: 4
            spacing: 8

            AudioWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            NetworkWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            BluetoothWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            LanguageWidget {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}


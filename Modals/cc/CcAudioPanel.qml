pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../Components"

Rectangle {
    id: root

    implicitWidth: 320
    implicitHeight: audioDevCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
        border.width: 1
    }

    required property var audioSinks
    required property var audioSources

    signal closeRequested()
    signal setDefaultSink(var entry)
    signal setDefaultSource(var entry)

    Column {
        id: audioDevCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 8

        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Audio Devices"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: aCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: aCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Text {
            text: "Salidas de audio"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
        }

        Column {
            width: parent.width; spacing: 4

            Repeater {
                model: root.audioSinks

                Rectangle {
                    id: sinkRow
                    required property var modelData
                    property bool hov: false
                    width: parent.width; height: 38; radius: 8
                    color: modelData.active
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : (hov ? Theme.surface2 : Theme.surface3)
                    border.color: sinkRow.modelData.active ? Theme.accent : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        visible: sinkRow.modelData.active
                        width: 3; height: 18; radius: 2
                        anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                        spacing: 8
                        Text {
                            text: sinkRow.modelData.icon; font.pixelSize: 14
                            color: sinkRow.modelData.active ? Theme.accent : Theme.muted2
                        }
                        Text {
                            Layout.fillWidth: true
                            text: sinkRow.modelData.label
                            font.pixelSize: 11; color: Theme.text; elide: Text.ElideRight
                        }
                        Text {
                            visible: sinkRow.modelData.active
                            text: "󰄬"; font.pixelSize: 12; color: Theme.accent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: sinkRow.hov = true
                        onExited:  sinkRow.hov = false
                        onClicked: { if (!sinkRow.modelData.active) root.setDefaultSink(sinkRow.modelData) }
                    }
                }
            }

            Text {
                visible: root.audioSinks.length === 0
                text: "No hay salidas disponibles"
                font.pixelSize: 10; color: Theme.muted2
            }
        }

        Text {
            text: "Entradas de audio"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.muted1
        }

        Column {
            width: parent.width; spacing: 4

            Repeater {
                model: root.audioSources

                Rectangle {
                    id: sourceRow
                    required property var modelData
                    property bool hov: false
                    width: parent.width; height: 38; radius: 8
                    color: modelData.active
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : (hov ? Theme.surface2 : Theme.surface3)
                    border.color: sourceRow.modelData.active ? Theme.accent : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        visible: sourceRow.modelData.active
                        width: 3; height: 18; radius: 2
                        anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                        spacing: 8
                        Text {
                            text: sourceRow.modelData.icon; font.pixelSize: 14
                            color: sourceRow.modelData.active ? Theme.accent : Theme.muted2
                        }
                        Text {
                            Layout.fillWidth: true
                            text: sourceRow.modelData.label
                            font.pixelSize: 11; color: Theme.text; elide: Text.ElideRight
                        }
                        Text {
                            visible: sourceRow.modelData.active
                            text: "󰄬"; font.pixelSize: 12; color: Theme.accent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: sourceRow.hov = true
                        onExited:  sourceRow.hov = false
                        onClicked: { if (!sourceRow.modelData.active) root.setDefaultSource(sourceRow.modelData) }
                    }
                }
            }

            Text {
                visible: root.audioSources.length === 0
                text: "No hay entradas disponibles"
                font.pixelSize: 10; color: Theme.muted2
            }
        }
    }
}

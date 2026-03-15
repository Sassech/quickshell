import QtQuick
import "../Components"

Rectangle {
    id: root
    radius: 8
    color: Theme.surface2
    implicitWidth: 190
    implicitHeight: 28

    // Accent left border
    Rectangle {
        width: 3
        height: parent.height * 0.6
        radius: 2
        color: Theme.accent2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 7
    }

    Row {
        id: innerRow
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 4
        spacing: 6

        // Time section: HH:mm + seconds
        Row {
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: timeText
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                font.family: "monospace"
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(), "HH:mm")
            }

            Text {
                id: secsText
                color: Theme.muted2
                font.pixelSize: 10
                font.family: "monospace"
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                text: Qt.formatDateTime(new Date(), ":ss")
            }
        }

        // Separator dot
        Rectangle {
            width: 3
            height: 3
            radius: 2
            color: Theme.muted3
            anchors.verticalCenter: parent.verticalCenter
        }

        // Date section
        Text {
            id: dateText
            color: Theme.muted1
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(new Date(), "ddd dd MMM")
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date()
            timeText.text = Qt.formatDateTime(now, "HH:mm")
            secsText.text = Qt.formatDateTime(now, ":ss")
            dateText.text = Qt.formatDateTime(now, "ddd dd MMM")
        }
    }
}

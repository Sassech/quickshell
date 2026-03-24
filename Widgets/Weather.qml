import QtQuick
import Quickshell
import "../Components"

Rectangle {
    id: root

    radius: 8
    color: Theme.surface2
    implicitWidth: weatherRow.implicitWidth + 16
    implicitHeight: 28

    // ── Datos del provider ───────────────────────────────────────────────
    property string temperature: weatherProvider.hasData
        ? Math.round(weatherProvider.temperature) + "°"
        : "--"
    property int weatherCode: weatherProvider.weatherCode
    property bool isDay: weatherProvider.isDay
    property string weatherIcon: weatherHelpers.wmoIcon(weatherCode, isDay)

    // ── Provider instance ─────────────────────────────────────────────────
    WeatherProvider {
        id: weatherProvider
    }
    
    WeatherHelpers {
        id: weatherHelpers
    }

    // ── Contenido ─────────────────────────────────────────────────────────
    Row {
        id: weatherRow
        anchors.centerIn:              parent
        anchors.horizontalCenterOffset: 4
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.weatherIcon
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color:          Theme.text
            font.pixelSize: 13
            font.bold:      true
            text:           root.temperature
        }
    }

    signal clicked()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

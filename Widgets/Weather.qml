import QtQuick
import "../Components"

Rectangle {
    id: root

    radius: 8
    color: Theme.surface2
    implicitWidth: weatherRow.implicitWidth + 16
    implicitHeight: 28

    // Datos del provider (singleton)
    property string temperature: WeatherProvider.hasData
        ? Math.round(WeatherProvider.temperature) + "°"
        : "--"
    property int weatherCode: WeatherProvider.weatherCode
    property bool isDay: WeatherProvider.isDay
    property string weatherIcon: weatherHelpers.wmoIcon(weatherCode, isDay)

    WeatherHelpers {
        id: weatherHelpers
    }

    // Gate de visibilidad
    Component.onCompleted: WeatherProvider._anyConsumerVisible = true
    Component.onDestruction: WeatherProvider._anyConsumerVisible = false

    // Contenido
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

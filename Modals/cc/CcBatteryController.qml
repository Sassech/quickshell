// Controlador de batería — bindings reactivos a UPower (sin polling)
import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: root

    property var  _upowerDev:      UPower.displayDevice

    property bool _batAvailableUP: _upowerDev ? _upowerDev.isPresent && _upowerDev.isLaptopBattery : false
    property real _batPctUP:       _upowerDev ? _upowerDev.percentage * 100 : 0
    property bool _batChargingUP:  _upowerDev ? (_upowerDev.state === UPowerDeviceState.Charging ||
                                                  _upowerDev.state === UPowerDeviceState.PendingCharge) : false
    property bool _batFullUP:      _upowerDev ? _upowerDev.state === UPowerDeviceState.FullyCharged : false
    property real _batHealthUP:    _upowerDev ? (_upowerDev.healthSupported ? _upowerDev.healthPercentage : 0) : 0
    property real _batCapWhUP:     _upowerDev ? _upowerDev.energyCapacity    : 0
    property real _batEnergyUP:    _upowerDev ? _upowerDev.energy            : 0
    property real _batChangeRate:  _upowerDev ? _upowerDev.changeRate        : 0
    property real _batTimeEmpty:   _upowerDev ? _upowerDev.timeToEmpty       : 0
    property real _batTimeFull:    _upowerDev ? _upowerDev.timeToFull        : 0
}

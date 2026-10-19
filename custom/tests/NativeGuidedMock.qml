import QtQuick

MockVehicle {
    property int missionCalls: 0
    property bool flying: false
    property bool landing: false
    property bool fixedWing: false
    property bool airShip: false
    property bool multiRotor: false
    property bool vtol: false
    property bool vtolInFwdFlight: false
    property bool inFwdFlight: false
    property bool initialConnectComplete: true
    property bool guidedModeSupported: true
    property bool takeoffVehicleSupported: false
    property bool roiModeSupported: false
    property bool orbitModeSupported: false
    property bool haveFWSpeedLimits: false
    property bool haveMRSpeedLimits: false
    property int sensorsPresentBits: 0
    property int rcRSSI: 100
    property string rtlFlightMode: "RTL"
    property string smartRTLFlightMode: "SmartRTL"
    property string landFlightMode: "Land"
    property QtObject healthAndArmingCheckReport: QtObject {
        property bool supported: false
        property bool canArm: true
        property bool canTakeoff: false
        property bool canStartMission: true
    }
    function startMission() { missionCalls++; }
    function forceArm() { armed = true; }
}

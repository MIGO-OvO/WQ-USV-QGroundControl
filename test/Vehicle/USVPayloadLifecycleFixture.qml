import QtQuick
import USV

Item {
    width: 800
    height: 600
    property alias commands: commands
    property alias taskPanel: taskPanel
    property alias operations: state

    function startSample() { commands.send(31010); }
    function pauseSample() { commands.send(31012); }
    function startSurvey() { commands.send(31015); }
    function confirmStopped() {
        commands.confirmPhysicalStop(state.vehicle);
        state.vehicle.usvSafetyLocked = false;
    }

    QtObject {
        id: state
        property var vehicle: testVehicle
        property var payload: testFacts
        property bool connected: true
        property bool hasPayload: true
        property bool payloadOnline: true
        property bool validSignal: true
        property bool baselineSet: true
        property bool payloadFault: false
        property bool payloadWorking: payloadStatus === 1
        property int payloadStatus: payload.status.rawValue
        property bool hasMission: true
        property bool taskExecuting: false
        property string samplingText: payloadStatus === 11 ? qsTr("已暂停") : qsTr("采样中")
        property string modeText: "Hold"
        property string waypointText: "03 / 08"
        property string stepText: "1 / 2"
        property string loopText: "1 / 1"
        property string sampleCountText: "1"
        property string alertText: ""
        property int phaseIndex: 2
        property var observedStages: [2]
        function fresh(field) { return payload.freshFields.indexOf(field) >= 0; }
        function factNumber(fact, fallback) { return fact ? fact.rawValue : fallback; }
    }
    USVPayloadCommandController { id: commands; operations: state }
    USVOperationsTheme { id: testTheme }
    QtObject {
        id: safety
        property var commandController: commands
        readonly property bool safetyLocked: state.vehicle && state.vehicle.usvSafetyLocked
    }
    USVCurrentTaskPanel {
        id: taskPanel
        width: 360
        operations: state
        controller: safety
        theme: testTheme
    }
}

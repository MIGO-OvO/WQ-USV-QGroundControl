import QtQuick
import QtQuick.Controls
import USV

Item {
    width: 800
    height: 600
    property alias commands: commands
    property alias taskPanel: taskPanel
    property alias operations: state
    property alias cockpit: safety
    property alias detectorButton: detectorButton
    property alias stopButton: stopButton
    Button { id: detectorButton; enabled: commands.allowed(31018); onClicked: commands.send(31018) }
    Button { id: stopButton; enabled: commands.allowed(31011); onClicked: commands.send(31011) }

    function startSample() { commands.send(31010); }
    function pauseSample() { commands.send(31012); }
    function startSurvey() { commands.send(31015); }
    function stopSample() { commands.send(31011); }
    function stopDetector() { commands.send(31019); }
    function emergencyStop() { safety.emergencyStop(state.vehicle); }
    function expireReceipt() {
        commands.request = Object.assign({}, commands.request, { deadline: 0 });
        commands.expire();
    }
    function confirmStopped() {
        commands.confirmPhysicalStop(state.vehicle);
        state.vehicle.usvSafetyLocked = false;
        safety.emergencyPhase = "idle";
    }

    QtObject {
        id: state
        property var vehicle: testVehicle
        property var payload: testFacts
        property var guidedController: null
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
    USVPayloadCommandController { id: commands; operations: state; safetyLocked: safety.safetyLocked }
    USVOperationsTheme { id: testTheme }
    USVCockpitController {
        id: safety
        operations: state
        theme: testTheme
        commandController: commands
    }
    USVCurrentTaskPanel {
        id: taskPanel
        width: 360
        operations: state
        controller: safety
        theme: testTheme
    }
}

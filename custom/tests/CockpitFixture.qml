import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import USV

ApplicationWindow {
    id: mainWindow

    property real fontFactor: 1
    property bool pipVisible: false
    property string currentScenario: "sampling"
    property alias cockpit: layer
    property alias mockVehicle: mock
    property alias otherVehicle: other
    readonly property var allFields: ["voltage", "absorbance", "pumpX", "pumpY", "pumpZ", "pumpA", "status", "packetCount", "stepCurrent", "stepTotal", "loopCurrent", "loopTotal", "sampleCount", "pidError", "pidMode", "baselineSet", "referenceVoltage", "baselineVoltage", "spectrometerValid", "jetsonTemp", "detectorTemp", "jetsonCpu", "jetsonMemory", "detectorHeap"]

    function scenario(name) {
        currentScenario = name;
        layer.activeVehicle = mock;
        mock.armed = true;
        mock.flightMode = "Hold";
        mock.vehicleLinkManager.communicationLost = false;
        mock.gps.lock = {rawValue: name === "offline" ? 1 : 3};
        mock.payload.linkActive = {rawValue: name === "offline" ? 0 : 1};
        mock.payload.freshFields = allFields.concat(["adsState", "protocolVersion"]);
        mock.payload.status = {rawValue: name === "ready" || name === "signal" || name === "baseline" ? 0 : name === "paused" ? 11 : name === "fault" ? 3 : 1};
        mock.payload.spectrometerValid = {rawValue: name === "signal" ? 0 : 1};
        mock.payload.baselineSet = {rawValue: name === "signal" || name === "baseline" ? 0 : 1};
        mock.payload.voltage = {rawValue: 1.842};
        mock.payload.absorbance = {rawValue: 0.1264};
        mock.payload.stepCurrent = {rawValue: 4};
        mock.payload.stepTotal = {rawValue: 12};
        mock.payload.sampleCount = {rawValue: 2};
        guided.missionController.currentMissionIndex = 3;
        layer.commands.reset();
        layer.controller.vehicleSafety = [];
        mock.usvSafetyLocked = false;
        other.usvSafetyLocked = false;
        reconnected.usvSafetyLocked = false;
        layer.controller.emergencyPhase = "idle";
        layer.controller.propulsionPending = false;
        layer.controller.payloadPending = false;
        layer.controller.emergencyTarget = null;
        layer.controller.feedback = "";
        guided.confirming = name === "confirmation";
        const controls = findItem(layer, "usvCockpitControlPanel");
        controls.devicesExpanded = name === "devices";
        const task = findItem(layer, "usvCurrentTaskPanel");
        task.diagnostics = name === "diagnostics";
        task.expanded = name !== "collapsed";
        if (name === "emergency" || name === "partial" || name === "timeout") {
            layer.controller.emergencyStop(mock);
            mock.mavCommandResult(1, 1, 400, 0, 0);
            if (name === "emergency") mock.mavCommandResult(1, 191, 31011, 0, 0);
            if (name === "timeout") layer.controller.expireEmergencyRequest();
        }
        if (name === "disconnected") mock.vehicleLinkManager.communicationLost = true;
        if (name === "missing-fields") mock.payload.freshFields = ["status"];
    }
    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children) {
            const found = findItem(child, name);
            if (found) return found;
        }
        return null;
    }
    function verifyBehavior() {
        const checks = [];
        function check(value, description) { if (!value) throw new Error(description); checks.push(description); }
        function accepted() {
            const request = layer.commands.request;
            mock.payload.payloadEventReceived(Object.assign({}, request, {
                seq: 1, phase: "request", outcome: "accepted", reason: "", attempt_id: "", preflight_phase: ""
            }));
        }
        scenario("ready");
        const commands = layer.commands, controller = layer.controller, ops = layer.operations;
        check(commands.allowed(31010), "ready telemetry allows manual sampling");
        scenario("offline");
        check(ops.connected && !ops.gpsReady && !ops.payloadOnline, "GPS and payload loss do not invent flight-controller loss");
        check(ops.voltageText === "—" && ops.absorbanceText === "—" && ops.stepText === "—", "offline measurements and counters masked");
        check(!commands.allowed(31010) && commands.allowed(31011), "offline payload blocks starts but retains stop");
        scenario("missing-fields");
        check(ops.voltageText === "—" && ops.sampleCountText === "—" && !ops.pumpFeedbackValid, "single fresh field cannot validate other values");
        check(!commands.allowed(31010), "missing measurement facts block manual sample");
        scenario("signal");
        commands.send(31018, 0);
        check(commands.pendingCommand === 31018 && mock.lastComponent === 191, "signal command routes to component 191");
        mock.mavCommandResult(2, 191, 31018, 0, 0);
        mock.mavCommandResult(1, 1, 31018, 0, 0);
        check(commands.pendingCommand === 31018, "other system and wrong component ACKs ignored");
        mock.mavCommandResult(1, 191, 31018, 5, 0);
        check(commands.pendingCommand === 31018, "in-progress is not completion");
        mock.mavCommandResult(1, 191, 31018, 0, 0);
        check(commands.pendingCommand === 31018, "standard ACK alone does not confirm request identity");
        accepted();
        check(commands.awaitedCommand === 31018 && !commands.allowed(31010), "accepted ACK waits for measurement telemetry");
        mock.payload.spectrometerValid = {rawValue: 1};
        mock.payload.receive("spectrometerValid");
        mock.payload.receive("voltage");
        check(!commands.busy, "valid signal completes telemetry wait");
        commands.send(31017, 0);
        mock.mavCommandResult(1, 191, 31017, 0, 0);
        accepted();
        check(commands.awaitedCommand === 31017 && !commands.allowed(31010), "baseline ACK cannot authorize sampling");
        mock.payload.baselineSet = {rawValue: 1};
        mock.payload.receive("baselineSet");
        mock.payload.status = {rawValue: 0};
        check(commands.allowed(31010), "baseline fact enables ready state");
        commands.send(31010, 0);
        mock.mavCommandResult(1, 191, 31010, 0, 0);
        accepted();
        const calls = mock.commandCalls;
        commands.send(31010, 0);
        check(mock.commandCalls === calls, "duplicate sampling is blocked while waiting");
        mock.payload.status = {rawValue: 1};
        mock.payload.receive("status");
        commands.send(31012, 0);
        mock.mavCommandResult(1, 191, 31012, 0, 0);
        accepted();
        check(commands.awaitedCommand === 31012, "pause waits for actual paused status");
        mock.payload.status = {rawValue: 11};
        mock.payload.receive("status");
        check(commands.allowed(31013), "paused telemetry permits resume");
        scenario("ready");
        guided.confirming = true;
        const cancellations = nativeConfirm.cancellations;
        controller.emergencyStop(mock);
        check(!guided.confirming && nativeConfirm.cancellations === cancellations + 1, "emergency cancels an already open native confirmation");
        check(controller.safetyLocked && controller.emergencyPending && mock.emergencyCalls > 0 && mock.lastCommand === 31011, "emergency locks actions before sending both stops");
        check(mock.usvSafetyLocked, "emergency synchronizes the vehicle-level joystick and command gate");
        for (const command of [31010, 31013, 31014, 31015, 31017, 31018]) check(!commands.allowed(command), "emergency blocks conflicting payload command " + command);
        mock.mavCommandResult(1, 191, 400, 0, 0);
        mock.mavCommandResult(2, 1, 400, 0, 0);
        check(controller.propulsionPending, "emergency ignores wrong vehicle and propulsion component");
        mock.mavCommandResult(1, 1, 400, 0, 0);
        check(controller.emergencyPhase === "partial" && controller.payloadPending, "partial ACK remains visible and locked");
        mock.mavCommandResult(1, 191, 31011, 0, 0);
        accepted();
        check(controller.emergencyPhase === "accepted" && controller.safetyLocked && !controller.canVerifyStop, "accepted stops do not imply actual stop");
        check(!controller.customActionAllowed({command: 31010, targetComponent: 191}, mock), "native action menu cannot bypass sampling safety latch");
        check(controller.customActionAllowed({command: 31011, targetComponent: 191}, mock), "native action menu retains safe payload stop");
        controller.executeCustomAction({command: 31011, targetComponent: 191, param1: 0}, mock);
        check(commands.pendingCommand === 31011 && mock.lastComponent === 191, "native payload action shares receipt and duplicate tracking");
        commands.reset();
        commands.send(31019, 0);
        check(controller.emergencyPhase === "accepted", "ordinary command feedback does not erase emergency receipt");
        const confirmations = guided.confirmations;
        controller.startMission(); controller.returnHome(); controller.confirmMode("Auto");
        check(guided.confirmations === confirmations, "emergency blocks navigation start, RTL and mode changes");
        layer.activeVehicle = other;
        check(!controller.emergencyPending && !commands.busy && controller.emergencyPhase === "idle", "switching clears old wait and receipt from new vessel");
        layer.activeVehicle = mock;
        check(controller.safetyLocked && controller.emergencyPhase === "accepted", "returning to original vessel preserves its safety latch");
        layer.activeVehicle = null;
        layer.activeVehicle = reconnected;
        check(controller.safetyLocked && controller.emergencyPhase === "accepted", "reconnected vehicle object with same system ID retains safety latch");
        check(controller.isVehicleLocked(mock) && !controller.isVehicleLocked(other), "safety lookup covers reconnected system ID without locking another vessel");
        layer.activeVehicle = mock;
        mock.armed = false;
        mock.payload.status = {rawValue: 12};
        check(controller.canVerifyStop, "disarmed and ended telemetry permits on-site verification");
        controller.releaseSafety(mock, false);
        check(controller.safetyLocked, "state alone cannot release safety lock");
        controller.releaseSafety(other, true);
        check(controller.safetyLocked, "verification for another vessel is rejected");
        controller.releaseSafety(mock, true);
        check(!controller.safetyLocked, "explicit on-site verification releases only current vessel");
        check(!mock.usvSafetyLocked, "on-site verification releases the vehicle-level latch");
        scenario("ready");
        controller.emergencyStop(mock);
        controller.expireEmergencyRequest();
        check(controller.emergencyPhase === "timeout" && controller.safetyLocked, "emergency timeout retains safety lock");
        scenario("ready");
        controller.emergencyStop(mock);
        mock.mavCommandResult(1, 1, 400, 2, 0);
        mock.mavCommandResult(1, 191, 31011, 0, 0);
        check(controller.emergencyPhase === "failed" && controller.safetyLocked, "one rejected stop cannot become success");
        scenario("ready");
        controller.emergencyStop(mock);
        mock.vehicleLinkManager.communicationLost = true;
        check(!controller.emergencyPending && controller.safetyLocked && !commands.allowed(31011), "disconnect cancels waits and preserves emergency lock");
        scenario("sampling");
        check(ops.waypointText === "03 / 08" && ops.stepText === "4 / 12" && ops.sampleCountText === "2", "waypoint, step and sample count are independent");
        check(ops.observedStages.indexOf(0) < 0 && ops.observedStages.indexOf(1) < 0, "sampling cannot manufacture prior phase evidence");
        scenario("ready");
        controller.startMission();
        check(guided.lastAction === guided.actionContinueMission, "native Guided controller handles mission confirmation");
        return JSON.stringify(checks);
    }
    function inspectGeometry() {
        const rectangles = [];
        const childBounds = [];
        for (const name of ["usvCurrentTaskPanel", "usvEmergencyStopPanel", "usvCockpitControlPanel", "usvRealtimeDataStrip"]) {
            const item = findItem(layer, name);
            if (!item.visible) continue;
            const p = item.mapToItem(mainWindow.contentItem, 0, 0);
            rectangles.push({name: name, x: p.x, y: p.y, width: item.width, height: item.height});
            for (const childName of ["usvTaskHeader", "usvTaskBody", "usvControlHeader", "usvControlBody"]) {
                const child = findItem(item, childName);
                if (child && child.visible) childBounds.push({name: childName, parent: name, x: child.x, y: child.y, width: child.width, height: child.height});
            }
        }
        return JSON.stringify({panels: rectangles, childBounds: childBounds, toolbarHeight: toolbar.height,
            instrument: {x: instruments.x, y: instruments.y, width: instruments.width, height: instruments.height},
            pip: pipVisible ? {x: pip.x, y: pip.y, width: pip.width, height: pip.height} : null,
            insets: {left: layer.totalToolInsets.leftEdgeCenterInset, right: layer.totalToolInsets.rightEdgeCenterInset, top: layer.totalToolInsets.topEdgeCenterInset, bottom: layer.totalToolInsets.bottomEdgeCenterInset}});
    }

    function prepareKeyboardNavigation() {
        scenario("ready");
        findItem(layer, "usvCockpitControlPanel").devicesExpanded = true;
        findItem(layer, "usvControlBody").contentY = 0;
        mainWindow.contentItem.forceActiveFocus();
        return JSON.stringify({ready: true});
    }
    function inspectKeyboardFocus() {
        const body = findItem(layer, "usvControlBody");
        const focused = mainWindow.activeFocusItem;
        let ancestor = focused;
        while (ancestor && ancestor !== body.contentItem)
            ancestor = ancestor.parent;
        if (!ancestor || !focused)
            return JSON.stringify({inside: false});
        const top = focused.mapToItem(body, 0, 0).y;
        return JSON.stringify({inside: true, top: top, bottom: top + focused.height, height: body.height, contentY: body.contentY});
    }

    width: 1280
    height: 720
    visible: true
    color: "#718e82"
    onFontFactorChanged: ScreenTools.fontFactor = fontFactor

    MockVehicle { id: mock }
    MockVehicle { id: other; Component.onCompleted: other.id = 2 }
    MockVehicle { id: reconnected }
    QtObject {
        id: globals
        readonly property var activeVehicle: layer.activeVehicle
        property var guidedControllerFlyView: guided
    }
    QtObject {
        id: guided
        property var safetyController: null
        property bool singleMissionEntry: false
        property var confirmDialog: nativeConfirm
        property QtObject missionController: QtObject { property bool containsItems: true; property int missionItemCount: 9; property int currentMissionIndex: 3 }
        property bool showStartMission: false
        property bool showContinueMission: true
        property bool showRTL: true
        property bool confirming: false
        property int confirmations: 0
        property int lastAction: 0
        property int actionContinueMission: 1
        property int actionStartMission: 2
        property int actionRTL: 3
        property int actionSetFlightMode: 4
        function confirmAction(action, data) { confirmations++; lastAction = action; }
    }
    QtObject {
        id: nativeConfirm
        property int cancellations: 0
        function confirmCancelled() { cancellations++; guided.confirming = false; }
    }
    Rectangle {
        id: mapSurface
        anchors.fill: parent
        color: "#688d83"
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.6; height: parent.height * 0.9; radius: height / 2; color: "#477c80"; rotation: -10 }
        QGCLabel { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.65; text: qsTr("原生 QML 验证 · 模拟遥测 / 示意水域"); color: "#d3ece6"; font.pointSize: ScreenTools.smallFontPointSize }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                ctx.strokeStyle = "#e6ba60"; ctx.lineWidth = 3; ctx.setLineDash([8, 5]);
                ctx.beginPath(); ctx.moveTo(width * 0.45, height * 0.53); ctx.lineTo(width * 0.58, height * 0.38); ctx.lineTo(width * 0.65, height * 0.57); ctx.lineTo(width * 0.54, height * 0.78); ctx.stroke();
                ctx.setLineDash([]); ctx.strokeStyle = "#70bdff"; ctx.beginPath(); ctx.moveTo(width * 0.56, height * 0.78); ctx.lineTo(width * 0.45, height * 0.53); ctx.stroke();
            }
        }
        USVCockpitIcon { x: parent.width * 0.45 - width / 2; y: parent.height * 0.53 - height / 2; width: 36; height: 36; name: "boat"; color: "#b8e3ff" }
    }
    USVFlyViewToolBar { id: toolbar; guidedValueSlider: null; utmspSliderTrigger: false; _guidedController: guided }
    Rectangle {
        id: strip
        x: 7; y: toolbar.height + 12; width: 48; height: 145; color: "#202c31"; radius: 5
        Column { anchors.centerIn: parent; spacing: 16; QGCLabel { text: qsTr("任务"); color: "white" } QGCLabel { text: "+"; color: "white" } QGCLabel { text: "−"; color: "white" } }
    }
    Rectangle {
        id: pip
        x: 7; y: mainWindow.height - height - 7; width: ScreenTools.defaultFontPixelWidth * 28; height: width * 0.6; color: "#28333a"; visible: mainWindow.pipVisible
        QGCLabel { anchors.centerIn: parent; text: qsTr("原生 PIP 避让区域"); color: "white" }
    }
    Column {
        id: instruments
        x: mainWindow.width - width - 14; y: mainWindow.height - height - 14
        width: compass.implicitWidth + compass.extraInset
        spacing: 8
        QGCLabel { text: "0.0 m/s     084°"; color: "white"; font.bold: true }
        IntegratedCompassAttitude { id: compass; x: extraInset; vehicle: mock }
    }
    Item {
        id: widgetBounds
        x: 7; y: toolbar.height + 7; width: mainWindow.width - 14; height: mainWindow.height - y - 7
    }
    QGCToolInsets {
        id: nativeInsets
        topEdgeCenterInset: toolbar.height
        leftEdgeTopInset: strip.width + 14
        leftEdgeCenterInset: leftEdgeTopInset
        rightEdgeBottomInset: instruments.width + 14
        bottomEdgeRightInset: instruments.height + 14
        bottomEdgeCenterInset: bottomEdgeRightInset
        leftEdgeBottomInset: mainWindow.pipVisible ? pip.width + 14 : 0
        bottomEdgeLeftInset: mainWindow.pipVisible ? pip.height + 14 : 0
    }
    USVFlyViewCustomLayer {
        id: layer
        anchors.fill: widgetBounds
        _guidedController: guided
        activeVehicle: mock
        mapControl: mapSurface
        parentToolInsets: nativeInsets
        onActiveVehicleChanged: QGroundControl.multiVehicleManager.activeVehicle = activeVehicle
    }
    Component.onCompleted: QGroundControl.multiVehicleManager.activeVehicle = mock
}

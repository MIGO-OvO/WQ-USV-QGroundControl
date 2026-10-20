import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import USV

ApplicationWindow {
    id: mainWindow

    property var workflow: null
    property bool pipVisible: false
    property real fontFactor: 1
    property string mapImage: ""

    function check(ok, message, checks) {
        if (!ok)
            throw new Error(message);
        checks.push(message);
    }
    function scenario(name) {
        layer.activeVehicle = mock;
        mock.vehicleLinkManager.communicationLost = name === "disconnected";
        mock.payload.linkActive = {rawValue: name === "payload-offline" ? 0 : 1};
        mock.payload.status = {rawValue: name === "preparing" ? 8 : name === "sampling" ? 1 : name === "paused" ? 11 : name === "fault" ? 3 : 0};
        mock.payload.spectrometerValid = {rawValue: name === "signal" ? 0 : 1};
        mock.payload.baselineSet = {rawValue: name === "signal" || name === "baseline" ? 0 : 1};
        if (workflow) {
            workflow.commands.reset();
            workflow.emergencyController.feedback = "";
            workflow.emergencyController.clearEmergencyRequest();
            workflow.expanded = name !== "collapsed" && name !== "collapsed-fault";
            workflow.detailSection = name === "devices" ? "devices" : name === "diagnostics" ? "diagnostics" : "";
            if (name === "collapsed-fault")
                mock.payload.status = {rawValue: 3};
            if (name === "accepted") {
                mock.payload.spectrometerValid = {rawValue: 0};
                mock.payload.baselineSet = {rawValue: 0};
                workflow.send(31018);
                mock.mavCommandResult(1, 191, 31018, 0, 0);
            }
        }
    }
    function verifyBehavior() {
        const checks = [];
        const cmd = workflow.commands;
        const ops = workflow.operations;
        scenario("signal");
        check(workflow.preparationStep === 1 && workflow.mainCommand === 31018, "signal is first preparation action", checks);
        check(workflow.signalText === "—" && workflow.absorbanceText === "—", "invalid measurements masked", checks);
        workflow.send(31018);
        check(cmd.pendingCommand === 31018 && mock.lastComponent === 191, "signal command targets component 191", checks);
        mock.mavCommandResult(2, 191, 31018, 0, 0);
        check(cmd.pendingCommand === 31018, "other vehicle ACK ignored", checks);
        mock.mavCommandResult(1, 191, 31017, 0, 0);
        check(cmd.pendingCommand === 31018, "unrelated ACK ignored", checks);
        mock.mavCommandResult(1, 191, 31018, 5, 0);
        check(cmd.pendingCommand === 31018, "in-progress ACK remains pending", checks);
        mock.mavCommandResult(1, 191, 31018, 0, 0);
        check(cmd.pendingCommand === 0 && !cmd.busy, "accepted start ends the send wait", checks);
        const calls = mock.commandCalls;
        workflow.send(31018);
        check(mock.commandCalls === calls, "duplicate start prevented during telemetry wait", checks);
        check(cmd.allowed(31011) && cmd.allowed(31019), "stops remain available while waiting", checks);
        mock.payload.spectrometerValid = {rawValue: 1};
        check(!cmd.busy && workflow.mainCommand === 31017, "valid telemetry advances to baseline", checks);
        workflow.send(31017);
        mock.mavCommandResult(1, 191, 31017, 0, 0);
        check(!cmd.busy && !cmd.allowed(31010), "baseline ACK alone cannot enable sampling", checks);
        mock.payload.baselineSet = {rawValue: 1};
        check(!cmd.busy && workflow.mainCommand === 31010 && cmd.allowed(31010), "baseline Fact enables manual sampling", checks);
        workflow.send(31010);
        mock.mavCommandResult(1, 191, 31010, 0, 0);
        check(!cmd.busy && !cmd.allowed(31010), "sample ACK cannot trigger duplicate sampling", checks);
        mock.payload.status = {rawValue: 1};
        check(!cmd.busy && workflow.mainCommand === 31012, "sampling telemetry offers pause", checks);
        workflow.send(31012);
        mock.mavCommandResult(1, 191, 31012, 0, 0);
        check(!cmd.busy && !cmd.allowed(31013), "pause ACK ends the wait; resume needs paused status", checks);
        mock.payload.status = {rawValue: 11};
        check(!cmd.busy && workflow.mainCommand === 31013, "paused status offers resume", checks);
        scenario("preparing");
        check(workflow.mainCommand === 31011 && workflow.mainText === qsTr("停止采样准备"), "preparation offers normal stop", checks);
        check(!cmd.allowed(31012) && cmd.allowed(31011), "preparation cannot pause but can stop", checks);
        workflow.send(31011);
        check(cmd.pendingCommand === 31011 && mock.lastCommand === 31011, "normal stop sent during preparation", checks);
        const stopCalls = mock.commandCalls;
        workflow.send(31011);
        check(mock.commandCalls === stopCalls, "pending stop is not duplicated", checks);
        mock.mavCommandResult(1, 191, 31011, 0, 0);
        check(!cmd.busy || cmd.pendingCommand === 31011, "stop ACK ends the wait without claiming the state", checks);
        mock.payload.status = {rawValue: 13};
        check(!cmd.busy && !cmd.warning, "confirmed hold after stop clears the wait", checks);
        scenario("signal");
        workflow.send(31018);
        cmd.expire();
        check(!cmd.busy && cmd.warning, "ACK timeout offers state check without completion", checks);
        workflow.send(31018);
        mock.mavCommandResult(1, 191, 31018, 2, 0);
        check(!cmd.busy && cmd.warning && !ops.validSignal, "rejected command cannot advance preparation", checks);
        workflow.send(31018);
        mock.mavCommandResult(1, 191, 31018, 0, 0);
        cmd.expireTelemetry();
        check(!cmd.busy && cmd.warning && !ops.validSignal, "telemetry timeout keeps actual state and permits retry", checks);
        scenario("signal");
        workflow.send(31018);
        layer.activeVehicle = other;
        check(!cmd.busy && cmd.feedback.length === 0, "vehicle switch clears command tracking", checks);
        mock.mavCommandResult(1, 191, 31018, 0, 0);
        check(!cmd.busy, "previous vehicle ACK cannot affect current vehicle", checks);
        scenario("signal");
        workflow.send(31018);
        mock.vehicleLinkManager.communicationLost = true;
        check(!cmd.busy && !cmd.allowed(31011), "disconnect cancels wait and disables commands", checks);
        scenario("payload-offline");
        check(!cmd.allowed(31010) && cmd.allowed(31011) && workflow.signalText === "—", "stale payload is hidden while safety stop remains available", checks);
        scenario("fault");
        check(!cmd.allowed(31010) && ops.alertText.length > 0, "fault blocks start and exposes alert", checks);
        scenario("ready");
        const emergency = workflow.emergencyController;
        emergency.emergencyStop(mock);
        check(mock.emergencyCalls > 0 && mock.lastCommand === 31011, "emergency stops propulsion and sampling", checks);
        mock.mavCommandResult(1, 1, 400, 0, 0);
        mock.mavCommandResult(1, 191, 31011, 0, 0);
        check(!emergency.propulsionStopPending && !emergency.payloadStopPending && emergency.feedbackWarning, "accepted emergency still requests actual-state check", checks);
        scenario("ready");
        return JSON.stringify(checks);
    }
    function inspectGeometry() {
        const p = workflow.mapToItem(mainWindow.contentItem, 0, 0);
        return JSON.stringify({x: p.x, y: p.y, width: workflow.width, height: workflow.height,
            maxHeight: workflow.maxHeight, expanded: workflow.expanded, compact: workflow.compact,
            instrument: {x: instruments.x, y: instruments.y + toolbar.height, width: instruments.width, height: instruments.height},
            pip: pipVisible ? {x: pip.x, y: pip.y + toolbar.height, width: pip.width, height: pip.height} : null});
    }
    function findItem(item, name) {
        if (item.objectName === name)
            return item;
        for (let child of item.children) {
            const found = findItem(child, name);
            if (found)
                return found;
        }
        return null;
    }
    function inspectDetailVisibility() {
        const body = findItem(workflow, "workflowBody");
        const actions = findItem(workflow, "workflowDetailActions");
        const controls = findItem(workflow, workflow.detailSection === "devices" ? "workflowDeviceControls" : "workflowDiagnosticsContent");
        const actionPosition = actions.mapToItem(body, 0, 0);
        const rectangles = [];
        for (let child of controls.children) {
            if (!child.visible || !child.height)
                continue;
            const position = child.mapToItem(body, 0, 0);
            rectangles.push({name: child.objectName, y: position.y, height: child.height});
        }
        return JSON.stringify({bodyHeight: body.height, returnY: actionPosition.y,
            returnHeight: actions.height, contentY: body.contentY, controls: rectangles});
    }

    color: "#a8b59e"
    visible: true
    width: 1280
    height: 720
    onFontFactorChanged: ScreenTools.fontFactor = fontFactor

    MockVehicle { id: mock }
    MockVehicle { id: other; Component.onCompleted: other.id = 2 }
    QtObject {
        id: globals
        readonly property var activeVehicle: layer.activeVehicle
        property var guidedControllerFlyView: null
    }
    Rectangle {
        id: toolbar
        color: "#222222"
        width: parent.width
        height: ScreenTools.defaultFontPixelHeight * 3.1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2
            spacing: ScreenTools.defaultFontPixelWidth * 3
            QGCLabel { text: "QGC"; color: "white"; font.bold: true }
            QGCLabel { text: "就绪"; color: "white"; font.bold: true }
            QGCLabel { text: "Hold"; color: "white" }
            Item { Layout.fillWidth: true }
            QGCLabel { text: qsTr("离屏验证 · 模拟遥测"); color: "#aaaaaa" }
            QGCLabel { text: "GPS 18    78%"; color: "white" }
        }
    }
    Item {
        id: mapSurface
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        Image {
            anchors.fill: parent
            source: mainWindow.mapImage
            fillMode: Image.PreserveAspectCrop
            visible: source.toString().length > 0
        }
        Canvas {
            anchors.fill: parent
            visible: mainWindow.mapImage.length === 0
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "#8bafb1";
                ctx.beginPath();
                ctx.ellipse(width * 0.10, height * 0.12, width * 0.64, height * 1.10);
                ctx.fill();
                ctx.strokeStyle = "#e5d49d";
                ctx.lineWidth = 4;
                ctx.beginPath();
                ctx.moveTo(width * 0.26, height * 0.72);
                ctx.lineTo(width * 0.41, height * 0.26);
                ctx.lineTo(width * 0.60, height * 0.31);
                ctx.lineTo(width * 0.70, height * 0.69);
                ctx.stroke();
            }
        }
        Rectangle {
            x: ScreenTools.defaultFontPixelWidth
            y: ScreenTools.defaultFontPixelWidth
            width: ScreenTools.defaultFontPixelWidth * 6
            height: ScreenTools.defaultFontPixelHeight * 8
            radius: 4
            color: "#222222"
            Column {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelHeight
                QGCLabel { text: qsTr("任务"); color: "white" }
                QGCLabel { text: qsTr("返航"); color: "white" }
                QGCLabel { text: qsTr("采样"); color: "#86ceff" }
            }
        }
        Rectangle {
            id: pip
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: ScreenTools.defaultFontPixelWidth
            width: ScreenTools.defaultFontPixelWidth * 28
            height: width * 0.6
            color: "#1d252b"
            visible: mainWindow.pipVisible
            QGCLabel { anchors.centerIn: parent; color: "white"; text: qsTr("视频占位 / 原生 PIP 区域") }
        }
        Column {
            id: instruments
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
            width: compass.implicitWidth + compass.extraInset
            spacing: ScreenTools.defaultFontPixelWidth
            QGCLabel { text: "0.0 m/s     128 m"; color: "white"; font.bold: true }
            IntegratedCompassAttitude {
                id: compass
                x: extraInset
                vehicle: mock
            }
        }
        QGCToolInsets {
            id: insets
            leftEdgeTopInset: ScreenTools.defaultFontPixelWidth * 7
            leftEdgeCenterInset: leftEdgeTopInset
            leftEdgeBottomInset: mainWindow.pipVisible ? pip.width + ScreenTools.defaultFontPixelWidth * 2 : 0
            rightEdgeBottomInset: instruments.width + ScreenTools.defaultFontPixelWidth * 1.5
            bottomEdgeRightInset: instruments.height + ScreenTools.defaultFontPixelWidth * 1.5
            bottomEdgeCenterInset: bottomEdgeRightInset
            bottomEdgeLeftInset: mainWindow.pipVisible ? pip.height + ScreenTools.defaultFontPixelWidth * 2 : 0
        }
        USVFlyViewCustomLayer {
            id: layer
            anchors.fill: parent
            _guidedController: null
            activeVehicle: mock
            parentToolInsets: insets
        }
    }
}

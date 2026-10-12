import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import USV

ApplicationWindow {
    id: fixture

    property alias actionObject: actions
    property string mapImage: ""
    property alias mockVehicle: mock
    property alias operations: model
    property alias panelObject: panel
    property alias payloadCommands: commands
    property alias tabIndex: panel.currentTab

    function scenario(name) {
        actions.clearEmergencyRequest();
        actions.feedback = "";
        mock.armed = name !== "unarmed-auto";
        mock.flightMode = "Auto";
        mock.vehicleLinkManager.communicationLost = name === "disconnected";
        mock.payload.status = {
            rawValue: name === "fault" ? 3 : 1
        };
        mock.payload.linkActive = {
            rawValue: name === "payload-offline" ? 0 : 1
        };
        mock.gps.lock = {
            rawValue: name === "no-gps" ? 1 : 3
        };
        if (name === "task-feedback") {
            actions.startMission();
            const originalFeedback = actions.feedback;
            mock.mavCommandResult(1, 1, 400, 2, 0);
            mock.mavCommandResult(1, 191, 31011, 2, 0);
            if (actions.feedback !== originalFeedback)
                throw new Error("Unrelated command result replaced task feedback");
        } else if (name === "emergency-accepted") {
            actions.emergencyStop(mock);
            mock.mavCommandResult(1, 1, 400, 0, 0);
            mock.mavCommandResult(1, 191, 31011, 0, 0);
        }
    }
    function verify() {
        const checks = [];
        function check(ok, description) {
            if (!ok)
                throw new Error(description);
            checks.push(description);
        }
        check(model.connected && model.payloadOnline, "connected telemetry");
        check(model.gpsReady, "GPS fix recognized");
        check(model.taskExecuting && model.taskText === qsTr("自动执行"), "armed Auto is executing");
        mock.armed = false;
        check(model.autoMode && !model.taskExecuting && model.taskText === qsTr("待解锁"), "disarmed Auto is waiting for arming");
        mock.armed = true;
        check(panel.width <= fixture.width * 0.32 + 1, "map retains at least 68 percent width");
        check(panel.y >= header.height, "panel below status bar");
        check(panel.y + panel.height < actions.y, "panel above controls");
        check(commands.allowed(31011), "stop remains available");
        mock.payload.status = {
            rawValue: 0
        };
        check(commands.allowed(31010), "ready point sample can start");
        mock.payload.baselineSet = {
            rawValue: 0
        };
        check(!commands.allowed(31010), "missing baseline blocks sampling");
        mock.payload.baselineSet = {
            rawValue: 1
        };
        mock.payload.spectrometerValid = {
            rawValue: 0
        };
        check(!commands.allowed(31010), "invalid signal blocks sampling");
        mock.payload.spectrometerValid = {
            rawValue: 1
        };
        commands.send(31010, 0);
        check(commands.pendingCommand === 31010 && mock.lastCommand === 31010 && mock.lastComponent === 191, "command targets companion");
        check(!commands.allowed(31015), "pending command blocks another start");
        mock.mavCommandResult(1, 191, 31018, 0, 0);
        check(commands.pendingCommand === 31010, "late ACK cannot clear another command");
        mock.mavCommandResult(1, 191, 31010, 5, 0);
        check(commands.pendingCommand === 31010, "in-progress ACK is not completion");
        mock.mavCommandResult(1, 191, 31010, 0, 0);
        check(commands.pendingCommand === 0 && !commands.warning, "accepted ACK clears pending");
        mock.payload.linkActive = {
            rawValue: 0
        };
        check(!commands.allowed(31010) && commands.allowed(31011), "payload lost blocks start but preserves stop");
        check(model.payloadMetric("voltage", 3, " V") === "—", "stale payload values hidden");
        mock.vehicleLinkManager.communicationLost = true;
        check(!model.connected && !model.gpsReady && !commands.allowed(31011), "FCU lost masks state and disables commands");
        check(model.metric(mock.groundSpeed, 1, "", model.connected) === "—", "stale speed hidden");
        mock.vehicleLinkManager.communicationLost = false;
        mock.payload.linkActive = {
            rawValue: 1
        };
        mock.payload.status = {
            rawValue: 3
        };
        check(model.payloadFault && model.alertText.length > 0 && !commands.allowed(31010), "sampling failure remains visible");
        mock.gps.lock = {
            rawValue: 2
        };
        check(!model.gpsReady, "2D fix is not navigation-ready");
        const requested = guided.requestedAction;
        actions.startMission();
        check(guided.requestedAction === requested, "no GPS blocks task request");
        mock.gps.lock = {
            rawValue: 3
        };
        mock.payload.status = {
            rawValue: 1
        };
        actions.startMission();
        check(guided.requestedAction === guided.actionContinueMission, "start uses QGC confirmation");
        const taskFeedback = actions.feedback;
        mock.mavCommandResult(1, 1, 400, 2, 0);
        mock.mavCommandResult(1, 191, 31011, 2, 0);
        check(actions.feedback === taskFeedback, "unrelated arm and payload-stop rejection cannot replace task feedback");
        const emergencyCalls = mock.emergencyCalls;
        actions.emergencyStop(otherMock);
        check(mock.emergencyCalls === emergencyCalls, "stale emergency dialog cannot command another vehicle");
        actions.emergencyStop(mock);
        check(actions.emergencyTargetVehicle === mock && actions.propulsionStopPending && actions.payloadStopPending && mock.emergencyCalls === emergencyCalls + 1 && mock.lastCommand === 31011, "confirmed emergency tracks both commands");
        const emergencyFeedback = actions.feedback;
        mock.mavCommandResult(2, 1, 400, 2, 0);
        mock.mavCommandResult(1, 1, 31011, 2, 0);
        check(actions.feedback === emergencyFeedback && actions.propulsionStopPending && actions.payloadStopPending, "wrong vehicle and component results are ignored");
        mock.mavCommandResult(1, 1, 400, 5, 0);
        check(actions.propulsionStopPending, "emergency in-progress ACK stays pending");
        mock.mavCommandResult(1, 1, 400, 0, 0);
        check(!actions.propulsionStopPending && actions.payloadStopPending, "propulsion acceptance waits for companion response");
        const acceptedFeedback = actions.feedback;
        mock.mavCommandResult(1, 1, 400, 2, 0);
        check(actions.feedback === acceptedFeedback, "completed emergency ignores a later arm result");
        mock.mavCommandResult(1, 191, 31011, 0, 0);
        check(!actions.payloadStopPending && actions.emergencyTargetVehicle === null && actions.feedback.indexOf(qsTr("已接受")) >= 0 && actions.feedback.indexOf(qsTr("实际停止")) >= 0, "accepted emergency still requires physical-state verification");
        actions.emergencyStop(mock);
        mock.mavCommandResult(1, 1, 400, 2, 0);
        mock.mavCommandResult(1, 191, 31011, 0, 0);
        check(actions.emergencyHadFailure && actions.feedback.indexOf(qsTr("未确认执行")) >= 0, "companion acceptance cannot hide propulsion rejection");
        actions.emergencyStop(mock);
        actions.expireEmergencyRequest();
        check(!actions.propulsionStopPending && !actions.payloadStopPending && actions.emergencyTargetVehicle === null && actions.feedback.indexOf(qsTr("响应超时")) >= 0, "emergency timeout clears pending with a warning");
        const timeoutFeedback = actions.feedback;
        mock.mavCommandResult(1, 1, 400, 0, 0);
        check(actions.feedback === timeoutFeedback, "late response cannot replace timeout feedback");
        actions.emergencyStop(mock);
        model.vehicle = otherMock;
        check(!actions.propulsionStopPending && !actions.payloadStopPending && actions.emergencyTargetVehicle === null && actions.feedback === "", "vehicle switch clears emergency request");
        model.vehicle = mock;
        actions.feedback = "";
        return JSON.stringify(checks);
    }

    height: 720
    title: "WQ-USV UI preview — simulated telemetry"
    visible: true
    width: 1280

    USVOperationsTheme {
        id: theme

    }
    MockVehicle {
        id: mock

        visible: false
    }
    MockVehicle {
        id: otherMock

        visible: false
    }
    QtObject {
        id: mission

        property bool containsItems: true
        property int currentMissionIndex: 3
        property int missionItemCount: 9
    }
    QtObject {
        id: guided

        property int actionContinueMission: 13
        property int actionRTL: 1
        property int actionSetFlightMode: 26
        property int actionStartMission: 12
        property var missionController: mission
        property int requestedAction: 0
        property bool showContinueMission: true
        property bool showRTL: true
        property bool showStartMission: false

        function confirmAction(action, data) {
            requestedAction = action;
        }
    }
    USVOperationsState {
        id: model

        guidedController: guided
        missionController: mission
        vehicle: mock
    }
    USVPayloadCommandController {
        id: commands

        operations: model
    }
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: fixture.mapImage
        sourceClipRect: Qt.rect(150, 100, 2050, 1240)
        visible: fixture.mapImage.length > 0
    }
    Rectangle {
        anchors.fill: parent
        color: theme.raised
        visible: fixture.mapImage.length === 0
    }
    Rectangle {
        id: header

        color: theme.surface
        height: theme.line * 3.5
        width: parent.width

        RowLayout {
            anchors.fill: parent
            anchors.margins: theme.unit
            spacing: theme.gap

            QGCLabel {
                color: theme.text
                font.bold: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.15
                text: "WQ-USV"
            }
            USVSystemStatusBar {
                Layout.fillHeight: true
                Layout.fillWidth: true
                operations: model
                theme: theme
            }
        }
    }
    USVOperationsPanel {
        id: panel

        anchors.bottom: actions.top
        anchors.margins: theme.unit * 0.75
        anchors.right: parent.right
        anchors.top: header.bottom
        objectName: "operationsPanel"
        operations: model
        theme: theme
        width: model.panelWidth(fixture.width, theme.unit)
    }
    USVActionBar {
        id: actions

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: theme.unit * 0.75
        availableWidth: fixture.width - theme.unit * 1.5
        objectName: "actionBar"
        operations: model
        theme: theme
    }
    QGCLabel {
        anchors.left: parent.left
        anchors.margins: theme.gap
        anchors.top: header.bottom
        color: theme.text
        font.bold: true
        padding: theme.unit
        text: qsTr("UI 预览 · 模拟遥测")

        background: Rectangle {
            color: theme.surface
            radius: theme.radius
        }
    }
}

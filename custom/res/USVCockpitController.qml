import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    required property var operations
    required property var theme
    property var commandController: null
    readonly property var vehicle: operations.vehicle
    readonly property bool safetyLocked: emergencyPhase !== "idle"
    readonly property bool emergencyPending: propulsionPending || payloadPending
    readonly property bool canVerifyStop: operations.connected && !emergencyPending && (!commandController || !commandController.stopsPending) && safetyLocked && !vehicle.armed && operations.payloadOnline && [0, 3, 9, 12, 13].indexOf(operations.payloadStatus) >= 0
    // Why the only recovery entry is unavailable. Shown instead of hiding it.
    readonly property string verifyBlockedReason: {
        if (canVerifyStop)
            return "";
        if (!safetyLocked)
            return "";
        if (!operations.connected)
            return qsTr("等待无人船连接");
        if (emergencyPending)
            return qsTr("停止命令仍在处理中");
        if (commandController && commandController.stopsPending)
            return qsTr("停止回执仍在处理中");
        if (vehicle.armed)
            return qsTr("飞控仍处于解锁状态，请先停止推进");
        if (!operations.payloadOnline)
            return qsTr("载荷遥测中断，无法确认采样装置状态");
        if ([0, 3, 9, 12, 13].indexOf(operations.payloadStatus) < 0)
            return qsTr("载荷仍在工作（状态 %1），请先停止采样").arg(operations.payloadStatus);
        return qsTr("等待停止证据");
    }
    property string emergencyPhase: "idle"
    property string propulsionReceipt: ""
    property string payloadReceipt: ""
    property bool propulsionPending: false
    property bool payloadPending: false
    property var emergencyTarget: null
    property var trackedVehicle: null
    property int trackedVehicleId: -1
    property var vehicleSafety: []
    property bool initialized: false
    property string feedback: ""
    property bool feedbackWarning: false
    property string expectedMode: ""
    readonly property string emergencyTitle: emergencyPhase === "sending" ? qsTr("急停发送中") : emergencyPhase === "partial" ? qsTr("部分命令已接受") : emergencyPhase === "accepted" ? qsTr("停止命令已接受") : emergencyPhase === "failed" ? qsTr("急停未获完整确认") : emergencyPhase === "timeout" ? qsTr("急停响应超时") : ""

    signal emergencyIssued()

    function switchVehicle() {
        if (trackedVehicleId >= 0 && safetyLocked) {
            const records = vehicleSafety.filter(record => record.vehicleId !== trackedVehicleId);
            records.push({vehicleId: trackedVehicleId, phase: emergencyPending ? "failed" : emergencyPhase,
                propulsion: propulsionPending ? qsTr("切船前未获确认") : propulsionReceipt,
                payload: payloadPending ? qsTr("切船前未获确认") : payloadReceipt});
            vehicleSafety = records;
        }
        emergencyTimeout.stop();
        modeTimeout.stop();
        emergencyDialog.close();
        verifyDialog.close();
        emergencyTarget = null;
        propulsionPending = false;
        payloadPending = false;
        feedback = "";
        expectedMode = "";
        trackedVehicle = vehicle;
        trackedVehicleId = vehicle ? vehicle.id : -1;
        const record = vehicleSafety.find(entry => entry.vehicleId === trackedVehicleId);
        const retainedLock = !!vehicle && vehicle.usvSafetyLocked;
        emergencyPhase = record ? record.phase : retainedLock ? "failed" : "idle";
        propulsionReceipt = record ? record.propulsion : retainedLock ? qsTr("上次急停尚未核验") : "";
        payloadReceipt = record ? record.payload : retainedLock ? qsTr("请核对载荷停止状态") : "";
        if (safetyLocked && vehicle)
            vehicle.usvSafetyLocked = true;
    }
    function requestEmergencyStop() {
        if (!operations.connected || emergencyPending)
            return;
        emergencyDialog.targetVehicle = vehicle;
        emergencyDialog.open();
    }
    function emergencyStop(targetVehicle) {
        if (!operations.connected || targetVehicle !== vehicle || emergencyPending)
            return;
        expectedMode = "";
        feedback = "";
        modeTimeout.stop();
        emergencyTarget = targetVehicle;
        emergencyPhase = "sending";
        propulsionPending = true;
        payloadPending = operations.hasPayload;
        propulsionReceipt = qsTr("等待飞控回执");
        payloadReceipt = operations.hasPayload ? qsTr("等待采样回执") : qsTr("载荷未接入");
        emergencyIssued();
        if (operations.guidedController && operations.guidedController.confirmDialog)
            operations.guidedController.confirmDialog.confirmCancelled();
        emergencyTimeout.restart();
        targetVehicle.emergencyStop();
        if (operations.hasPayload) {
            if (commandController)
                commandController.send(31011);
            else
                targetVehicle.sendCommand(191, 31011, true);
        }
    }
    function emergencyResult(vehicleId, targetComponent, command, ackResult, failureCode) {
        if (!emergencyTarget || emergencyTarget !== vehicle || vehicleId !== emergencyTarget.id)
            return;
        const propulsion = command === 400 && targetComponent === emergencyTarget.defaultComponentId && propulsionPending;
        const payload = command === 31011 && targetComponent === 191 && payloadPending;
        if (!propulsion && !payload)
            return;
        if (ackResult === 5 && failureCode === 0)
            return;
        const accepted = ackResult === 0 && failureCode === 0;
        if (propulsion) {
            propulsionPending = false;
            propulsionReceipt = accepted ? qsTr("飞控命令已接受") : qsTr("飞控停止未确认");
        }
        if (payload) {
            payloadPending = false;
            payloadReceipt = accepted ? qsTr("采样命令已接受") : qsTr("采样停止未确认");
        }
        if (!accepted || emergencyPhase === "failed")
            emergencyPhase = "failed";
        else
            emergencyPhase = emergencyPending ? "partial" : "accepted";
        if (!emergencyPending) {
            emergencyTimeout.stop();
            emergencyTarget = null;
        }
    }
    function expireEmergencyRequest() {
        if (!emergencyPending)
            return;
        if (propulsionPending) propulsionReceipt = qsTr("飞控回执超时");
        if (payloadPending) payloadReceipt = qsTr("采样回执超时");
        propulsionPending = false;
        payloadPending = false;
        emergencyTarget = null;
        emergencyPhase = "timeout";
        emergencyTimeout.stop();
    }
    function requestVerifyStop() {
        if (!canVerifyStop)
            return;
        verifyDialog.targetVehicle = vehicle;
        onsiteCheck.checked = false;
        verifyDialog.open();
    }
    function releaseSafety(targetVehicle, onsiteVerified) {
        if (targetVehicle !== vehicle || !canVerifyStop || !onsiteVerified)
            return;
        vehicleSafety = vehicleSafety.filter(record => record.vehicleId !== vehicle.id);
        targetVehicle.usvSafetyLocked = false;
        if (commandController)
            commandController.confirmPhysicalStop(targetVehicle);
        emergencyPhase = "idle";
        propulsionReceipt = "";
        payloadReceipt = "";
        feedbackWarning = false;
        feedback = qsTr("已确认设备停止，操作锁定已解除；解锁仍需飞控检查");
    }
    function confirmMode(mode) {
        if (!operations.connected || safetyLocked || !operations.guidedController || !vehicle.flightModeSetAvailable || !mode)
            return;
        operations.guidedController.confirmAction(operations.guidedController.actionSetFlightMode, mode);
        feedbackWarning = false;
        feedback = qsTr("请在顶部确认模式切换");
    }
    function pauseNavigation() {
        if (!operations.connected || safetyLocked || !vehicle.pauseVehicleSupported)
            return;
        expectedMode = vehicle.pauseFlightMode;
        feedbackWarning = false;
        feedback = qsTr("等待飞控进入保持模式");
        modeTimeout.restart();
        vehicle.pauseVehicle();
    }
    function startMission() {
        const guided = operations.guidedController;
        if (!operations.connected || safetyLocked || operations.payloadWorking || operations.payloadStatus === 11 || !operations.gpsReady || !guided)
            return;
        if (guided.showContinueMission)
            guided.confirmAction(guided.actionContinueMission);
        else if (guided.showStartMission)
            guided.confirmAction(guided.actionStartMission);
        else
            return;
        feedbackWarning = false;
        feedback = qsTr("请在顶部确认航行任务");
    }
    function returnHome() {
        const guided = operations.guidedController;
        if (operations.connected && !safetyLocked && operations.gpsReady && guided && guided.showRTL)
            guided.confirmAction(guided.actionRTL);
    }

    onVehicleChanged: { if (initialized) switchVehicle(); }
    onSafetyLockedChanged: { if (safetyLocked && vehicle) vehicle.usvSafetyLocked = true; }
    Component.onCompleted: { switchVehicle(); initialized = true; }

    function isVehicleLocked(targetVehicle) {
        return !!targetVehicle && (targetVehicle.usvSafetyLocked || (targetVehicle === vehicle ? safetyLocked : vehicleSafety.some(record => record.vehicleId === targetVehicle.id)));
    }

    function customActionAllowed(action, targetVehicle) {
        if (!action || targetVehicle !== vehicle || !operations.connected)
            return false;
        if (action.targetComponent === 191 && action.command >= 31010 && action.command <= 31019)
            return !!commandController && commandController.allowed(action.command);
        return !isVehicleLocked(targetVehicle);
    }
    function executeCustomAction(action, targetVehicle) {
        if (!customActionAllowed(action, targetVehicle))
            return;
        if (action.targetComponent === 191 && action.command >= 31010 && action.command <= 31019)
            commandController.send(action.command, action.param1);
        else
            action.sendTo(targetVehicle);
    }

    Connections {
        target: root.operations
        function onConnectedChanged() {
            if (!root.operations.connected && root.emergencyPending) {
                root.expireEmergencyRequest();
                root.emergencyPhase = "failed";
            }
        }
    }
    Connections {
        target: root.vehicle
        ignoreUnknownSignals: true
        function onUsvSafetyLockedChanged() {
            if (root.vehicle && root.vehicle.usvSafetyLocked && root.emergencyPhase === "idle")
                root.emergencyPhase = "failed";
        }
        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            root.emergencyResult(vehicleId, targetComponent, command, ackResult, failureCode);
        }
        function onFlightModeChanged() {
            if (root.expectedMode && root.vehicle && root.vehicle.flightMode === root.expectedMode) {
                root.feedback = qsTr("飞控已进入保持模式");
                root.feedbackWarning = false;
                root.expectedMode = "";
                modeTimeout.stop();
            }
        }
    }
    Timer {
        id: emergencyTimeout
        interval: 15000
        onTriggered: root.expireEmergencyRequest()
    }
    Timer {
        id: modeTimeout
        interval: 5000
        onTriggered: {
            root.expectedMode = "";
            root.feedbackWarning = true;
            root.feedback = qsTr("保持模式未确认，请核对飞控状态");
        }
    }
    Dialog {
        id: emergencyDialog
        property var targetVehicle: null
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: parent ? Math.min(root.theme.unit * 58, parent.width * 0.9) : root.theme.unit * 58
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0
        padding: root.theme.gap
        objectName: "usvEmergencyDialog"
        background: Rectangle { color: root.theme.panel; radius: root.theme.radius; border.color: root.theme.danger }
        contentItem: ColumnLayout {
            spacing: root.theme.gap
            QGCLabel { color: root.theme.text; font.bold: true; font.pointSize: ScreenTools.defaultFontPointSize * 1.2; text: qsTr("确认紧急停止 · 无人船 %1").arg(emergencyDialog.targetVehicle ? emergencyDialog.targetVehicle.id : "—") }
            QGCLabel { Layout.fillWidth: true; color: root.theme.text; wrapMode: Text.WordWrap; text: qsTr("停止推进电机并取消当前采样。船舶可能随水流漂移，请确认周边环境。") }
            RowLayout {
                Layout.fillWidth: true
                USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("取消"); onClicked: emergencyDialog.close() }
                USVOperationsButton {
                    Layout.fillWidth: true
                    theme: root.theme
                    destructive: true
                    text: qsTr("发出紧急停止")
                    enabled: root.operations.connected && emergencyDialog.targetVehicle === root.vehicle && !root.emergencyPending
                    onClicked: { root.emergencyStop(emergencyDialog.targetVehicle); emergencyDialog.close(); }
                }
            }
        }
    }
    Dialog {
        id: verifyDialog
        property var targetVehicle: null
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: parent ? Math.min(root.theme.unit * 58, parent.width * 0.9) : root.theme.unit * 58
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0
        padding: root.theme.gap
        background: Rectangle { color: root.theme.panel; radius: root.theme.radius; border.color: root.theme.warning }
        contentItem: ColumnLayout {
            spacing: root.theme.gap
            QGCLabel { color: root.theme.text; font.bold: true; text: qsTr("核验停止 · 无人船 %1").arg(verifyDialog.targetVehicle ? verifyDialog.targetVehicle.id : "—") }
            QGCLabel { Layout.fillWidth: true; color: root.theme.text; wrapMode: Text.WordWrap; text: qsTr("飞控已返回未解锁，载荷已停止或已结束本次任务。泵角度不能证明电机停止，请现场核验。解除锁定后需重新启动分光并建立基线才能再次采样。") }
            CheckBox { id: onsiteCheck; Layout.fillWidth: true; text: qsTr("已现场确认推进与采样装置停止"); palette.windowText: root.theme.text }
            RowLayout {
                Layout.fillWidth: true
                USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("取消"); onClicked: verifyDialog.close() }
                USVOperationsButton {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: qsTr("解除操作锁定")
                    enabled: onsiteCheck.checked && root.canVerifyStop && verifyDialog.targetVehicle === root.vehicle
                    onClicked: { root.releaseSafety(verifyDialog.targetVehicle, onsiteCheck.checked); verifyDialog.close(); }
                }
            }
        }
    }
}

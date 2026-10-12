import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    readonly property int _payloadCompId: 191
    property real availableWidth: parent ? parent.width : implicitWidth
    property bool emergencyHadFailure: false
    property var emergencyTargetVehicle: null
    property string expectedMode: ""
    property string feedback: ""
    property bool feedbackWarning: false
    required property var operations
    property bool payloadStopPending: false
    property bool propulsionStopPending: false
    property var theme: _theme
    property var vehicle: operations ? operations.vehicle : null

    function clearEmergencyRequest() {
        emergencyTargetVehicle = null;
        propulsionStopPending = false;
        payloadStopPending = false;
        emergencyHadFailure = false;
        if (emergencyTimeout)
            emergencyTimeout.stop();
    }
    function confirmMode(mode) {
        if (!operations.connected || !operations.guidedController || !vehicle.flightModeSetAvailable || !mode)
            return;
        operations.guidedController.confirmAction(operations.guidedController.actionSetFlightMode, mode);
        feedbackWarning = false;
        feedback = qsTr("请在顶部确认模式切换；实际模式以飞控返回为准");
    }
    function emergencyResult(vehicleId, targetComponent, command, ackResult, failureCode) {
        if (!emergencyTargetVehicle || emergencyTargetVehicle !== vehicle || vehicleId !== emergencyTargetVehicle.id)
            return;
        const propulsionResult = command === 400 && propulsionStopPending;
        const payloadResult = targetComponent === _payloadCompId && command === 31011 && payloadStopPending;
        if (!propulsionResult && !payloadResult)
            return;
        if (ackResult === 5 && failureCode === 0) {
            if (!emergencyHadFailure)
                feedback = qsTr("紧急停止处理中，请核对设备实际状态");
            emergencyTimeout.restart();
            return;
        }
        if (propulsionResult)
            propulsionStopPending = false;
        if (payloadResult)
            payloadStopPending = false;
        emergencyHadFailure = emergencyHadFailure || ackResult !== 0 || failureCode !== 0;
        feedbackWarning = true;
        feedback = emergencyHadFailure ? qsTr("停止命令未确认执行，请核对设备状态与链路") : propulsionStopPending || payloadStopPending ? qsTr("已接受部分停止命令，等待其他设备响应；请核对实际停止") : qsTr("停止命令已接受，请核对推进电机与采样装置实际停止");
        if (!propulsionStopPending && !payloadStopPending) {
            emergencyTimeout.stop();
            emergencyTargetVehicle = null;
        }
    }
    function emergencyStop(targetVehicle) {
        if (!operations.connected || targetVehicle !== vehicle || propulsionStopPending || payloadStopPending)
            return;
        expectedMode = "";
        modeTimeout.stop();
        emergencyTargetVehicle = targetVehicle;
        propulsionStopPending = true;
        payloadStopPending = operations.hasPayload;
        emergencyHadFailure = false;
        feedbackWarning = true;
        feedback = qsTr("已发送紧急停止，等待设备响应；请核对实际停止");
        emergencyTimeout.restart();
        // Reuse QGC's emergency disarm and existing companion cancellation.
        // Set pending first: QGC may report a queue rejection synchronously.
        vehicle.emergencyStop();
        if (operations.hasPayload)
            vehicle.sendCommand(_payloadCompId, 31011, true);
    }
    function expireEmergencyRequest() {
        if (!propulsionStopPending && !payloadStopPending)
            return;
        clearEmergencyRequest();
        feedbackWarning = true;
        feedback = qsTr("紧急停止响应超时，请核对推进电机与采样装置实际状态");
    }
    function pauseNavigation() {
        if (!operations.connected || !vehicle.pauseVehicleSupported)
            return;
        feedbackWarning = false;
        feedback = qsTr("暂停航行发送中，等待飞控进入保持模式");
        expectedMode = vehicle.pauseFlightMode;
        modeTimeout.restart();
        vehicle.pauseVehicle();
    }
    function startMission() {
        const controller = operations.guidedController;
        if (!operations.connected || !operations.gpsReady || !controller)
            return;
        if (controller.showContinueMission)
            controller.confirmAction(controller.actionContinueMission);
        else if (controller.showStartMission)
            controller.confirmAction(controller.actionStartMission);
        else
            return;
        feedbackWarning = false;
        feedback = qsTr("请在顶部确认开始任务；解锁检查由飞控执行");
    }

    border.color: theme.divider
    border.width: 1
    color: theme.surface
    height: implicitHeight
    implicitHeight: actionRow.implicitHeight + theme.unit * 2 + (feedback.length ? feedbackLabel.implicitHeight + theme.unit : 0)
    radius: theme.radius
    width: Math.max(0, availableWidth)

    onVehicleChanged: {
        if (emergencyDialog)
            emergencyDialog.close();
        feedback = "";
        expectedMode = "";
        if (modeTimeout)
            modeTimeout.stop();
        clearEmergencyRequest();
    }

    USVOperationsTheme {
        id: _theme

    }
    Connections {
        function onFlightModeChanged() {
            if (root.expectedMode && root.vehicle && root.vehicle.flightMode === root.expectedMode) {
                root.feedback = qsTr("飞控已进入保持模式；采样状态见右侧面板");
                root.feedbackWarning = false;
                root.expectedMode = "";
                modeTimeout.stop();
            }
        }
        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            root.emergencyResult(vehicleId, targetComponent, command, ackResult, failureCode);
        }

        ignoreUnknownSignals: true
        target: root.vehicle
    }
    Timer {
        id: emergencyTimeout

        interval: 10000

        onTriggered: root.expireEmergencyRequest()
    }
    Timer {
        id: modeTimeout

        interval: 5000

        onTriggered: {
            root.expectedMode = "";
            root.feedbackWarning = true;
            root.feedback = qsTr("未确认进入保持模式，请检查飞控状态");
        }
    }
    Flow {
        id: actionRow

        spacing: root.theme.unit
        width: Math.max(0, parent.width - root.theme.unit * 2)
        x: root.theme.unit
        y: root.theme.unit

        Row {
            id: modeButtons

            spacing: root.theme.unit * 0.5

            USVOperationsButton {
                checked: root.operations.connected && root.vehicle.flightMode === root.vehicle.stabilizedFlightMode
                enabled: root.operations.connected && root.vehicle.flightModeSetAvailable && !!root.operations.guidedController
                helpText: qsTr("切换到固件提供的手动驾驶模式")
                text: qsTr("手动")

                onClicked: root.confirmMode(root.vehicle.stabilizedFlightMode)
            }
            USVOperationsButton {
                checked: root.operations.autoMode
                enabled: root.operations.connected && root.operations.hasMission && root.operations.gpsReady && root.vehicle.flightModeSetAvailable && !!root.operations.guidedController && root.vehicle.armed
                helpText: qsTr("切换到自动任务模式；未解锁时请使用开始任务")
                text: qsTr("自动")

                onClicked: root.confirmMode(root.vehicle.missionFlightMode)
            }
        }
        Item {
            height: root.theme.controlHeight
            width: Math.max(0, (actionRow.width - modeButtons.width - taskButtons.width - emergencyButton.width - actionRow.spacing * 4) / 2)
        }
        Row {
            id: taskButtons

            spacing: root.theme.unit

            USVOperationsButton {
                enabled: root.operations.connected && root.operations.gpsReady && !!root.operations.guidedController && (root.operations.guidedController.showStartMission || root.operations.guidedController.showContinueMission)
                helpText: qsTr("沿用 QGC 任务与解锁检查，确认后开始航线")
                primary: true
                text: root.operations.guidedController && root.operations.guidedController.showContinueMission ? qsTr("继续任务") : qsTr("开始任务")

                onClicked: root.startMission()
            }
            USVOperationsButton {
                enabled: root.operations.connected && root.vehicle.armed && root.vehicle.pauseVehicleSupported && !root.operations.holdMode
                helpText: qsTr("切换保持模式，暂停航行")
                text: qsTr("暂停")

                onClicked: root.pauseNavigation()
            }
            USVOperationsButton {
                enabled: root.operations.connected && root.operations.gpsReady && !!root.operations.guidedController && root.operations.guidedController.showRTL
                helpText: qsTr("通过 QGC 确认并返回起航位置")
                text: qsTr("返航")

                onClicked: root.operations.guidedController.confirmAction(root.operations.guidedController.actionRTL)
            }
        }
        Item {
            height: root.theme.controlHeight
            width: Math.max(0, (actionRow.width - modeButtons.width - taskButtons.width - emergencyButton.width - actionRow.spacing * 4) / 2)
        }
        USVOperationsButton {
            id: emergencyButton

            destructive: true
            enabled: root.operations.connected
            helpText: qsTr("确认后停止推进电机并取消当前采样")
            text: qsTr("紧急停止")

            onClicked: {
                emergencyDialog.targetVehicle = root.vehicle;
                emergencyDialog.open();
            }
        }
    }
    QGCLabel {
        id: feedbackLabel

        anchors.left: parent.left
        anchors.margins: root.theme.unit
        anchors.right: parent.right
        anchors.top: actionRow.bottom
        color: root.feedbackWarning ? root.theme.warning : root.theme.secondary
        font.pointSize: ScreenTools.defaultFontPointSize * 0.95
        text: root.feedback
        visible: text.length > 0
        wrapMode: Text.WordWrap
    }
    Dialog {
        id: emergencyDialog

        property var targetVehicle: null

        closePolicy: Popup.CloseOnEscape
        modal: true
        padding: root.theme.gap
        parent: Overlay.overlay
        width: Math.min(root.theme.unit * 58, parent.width * 0.9)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        background: Rectangle {
            border.color: root.theme.danger
            border.width: 1
            color: root.theme.surface
            radius: root.theme.radius
        }
        contentItem: ColumnLayout {
            spacing: root.theme.gap

            QGCLabel {
                color: root.theme.text
                font.bold: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.35
                text: qsTr("确认紧急停止")
            }
            QGCLabel {
                Layout.fillWidth: true
                color: root.theme.text
                text: qsTr("停止推进电机并取消当前采样。船舶可能随水流漂移，请确认周边环境。")
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true

                USVOperationsButton {
                    Layout.fillWidth: true
                    text: qsTr("取消")

                    onClicked: emergencyDialog.close()
                }
                USVOperationsButton {
                    Layout.fillWidth: true
                    destructive: true
                    enabled: root.operations.connected && emergencyDialog.targetVehicle === root.vehicle && !root.propulsionStopPending && !root.payloadStopPending
                    text: qsTr("发出紧急停止")

                    onClicked: {
                        root.emergencyStop(emergencyDialog.targetVehicle);
                        emergencyDialog.close();
                    }
                }
            }
        }
    }
}

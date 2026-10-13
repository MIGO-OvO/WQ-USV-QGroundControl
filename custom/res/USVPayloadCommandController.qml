import QtQuick

import "USVFlyViewLayout.js" as USVLayout

Item {
    id: root

    readonly property int _payloadCompId: 191
    property int awaitedCommand: 0
    readonly property bool busy: pendingCommand !== 0 || awaitedCommand !== 0
    readonly property bool canStartPointSample: operations.payloadStatus === USVLayout.StatusIdle || operations.payloadStatus === USVLayout.StatusSamplingDone || operations.payloadStatus === USVLayout.StatusHoldNoMission
    property string feedback: ""
    required property var operations
    property int pendingCommand: 0
    property double pendingSince: 0
    readonly property bool ready: operations.payloadOnline && operations.validSignal && operations.baselineSet
    property bool warning: false

    function allowed(command) {
        if (!operations.connected || !operations.hasPayload)
            return false;
        if (command === 31011 || command === 31016 || command === 31019)
            return pendingCommand !== command;
        if (pendingCommand || awaitedCommand || !operations.payloadOnline || operations.payloadFault)
            return false;
        if (command === 31018 || command === 31014)
            return !operations.payloadWorking;
        if (command === 31017)
            return operations.validSignal && !operations.payloadWorking;
        if (command === 31010)
            return ready && canStartPointSample;
        if (command === 31015)
            return ready && canStartPointSample;
        if (command === 31012)
            return operations.payloadStatus === USVLayout.StatusSampling;
        if (command === 31013)
            return ready && operations.payloadStatus === USVLayout.StatusPaused;
        return false;
    }
    function commandName(command) {
        switch (command) {
        case 31010:
            return qsTr("点采样");
        case 31011:
            return qsTr("停止采样");
        case 31012:
            return qsTr("暂停采样");
        case 31013:
            return qsTr("恢复采样");
        case 31014:
            return qsTr("校准泵组");
        case 31015:
            return qsTr("走航检测");
        case 31016:
            return qsTr("停止走航");
        case 31017:
            return qsTr("设基线");
        case 31018:
            return qsTr("启动信号");
        case 31019:
            return qsTr("停止信号");
        default:
            return qsTr("载荷命令");
        }
    }
    function commandTimeoutFor(command) {
        if (command === 31018)
            return 40000;
        if (command === 31011 || command === 31016 || command === 31019)
            return 15000;
        return 5000;
    }
    function expire() {
        if (!pendingCommand)
            return;
        warning = true;
        feedback = commandName(pendingCommand) + qsTr("响应超时，请核对实际状态");
        pendingCommand = 0;
        timeout.stop();
    }
    function send(command, param1) {
        if (!allowed(command))
            return;
        awaitedCommand = 0;
        telemetryTimeout.stop();
        pendingCommand = command;
        pendingSince = Date.now();
        warning = false;
        feedback = commandName(command) + qsTr("发送中，等待载荷响应");
        timeout.restart();
        operations.vehicle.sendCommand(_payloadCompId, command, true, param1 || 0);
    }

    function telemetryMatches(command) {
        if (!operations.payloadOnline)
            return false;
        const status = operations.payloadStatus;
        switch (command) {
        case 31018: return operations.validSignal;
        case 31017: return operations.baselineSet;
        case 31010: return status !== USVLayout.StatusIdle && status !== USVLayout.StatusSamplingDone && status !== USVLayout.StatusHoldNoMission;
        case 31012: return status === USVLayout.StatusPaused;
        case 31013: return status !== USVLayout.StatusPaused;
        case 31014: return status === USVLayout.StatusCalibrating;
        case 31015: return status === USVLayout.StatusSurveying;
        case 31011: return status === USVLayout.StatusIdle || status === USVLayout.StatusAborted || status === USVLayout.StatusHoldNoMission || status === USVLayout.StatusSamplingDone;
        case 31016: return status !== USVLayout.StatusSurveying;
        case 31019: return !operations.validSignal;
        default: return true;
        }
    }
    function observeTelemetry() {
        if (!awaitedCommand || !telemetryMatches(awaitedCommand))
            return;
        feedback = operations.payloadFault ? qsTr("载荷返回异常状态，请检查设备") : commandName(awaitedCommand) + qsTr("已收到状态更新；结果以遥测为准");
        warning = operations.payloadFault;
        awaitedCommand = 0;
        telemetryTimeout.stop();
    }
    function expireTelemetry() {
        if (!awaitedCommand)
            return;
        warning = true;
        feedback = commandName(awaitedCommand) + qsTr("已接受，但未收到状态更新；请核对设备后重试");
        awaitedCommand = 0;
        telemetryTimeout.stop();
    }
    function reset() {
        pendingCommand = 0;
        awaitedCommand = 0;
        feedback = "";
        warning = false;
        timeout.stop();
        telemetryTimeout.stop();
    }
    Connections {
        function onVehicleChanged() {
            root.reset();
        }
        function onConnectedChanged() {
            if (!root.operations.connected)
                root.reset();
        }
        function onPayloadOnlineChanged() {
            root.observeTelemetry();
        }
        function onValidSignalChanged() {
            root.observeTelemetry();
        }
        function onBaselineSetChanged() {
            root.observeTelemetry();
        }
        function onPayloadStatusChanged() {
            root.observeTelemetry();
        }

        target: root.operations
    }
    Connections {
        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            if (!root.operations.vehicle || vehicleId !== root.operations.vehicle.id || targetComponent !== root._payloadCompId || command !== root.pendingCommand)
                return;
            if (ackResult === 5 && failureCode === 0) {
                root.feedback = root.commandName(command) + qsTr("处理中");
                timeout.restart();
                return;
            }
            root.warning = ackResult !== 0 || failureCode !== 0;
            root.feedback = root.commandName(command) + (root.warning ? qsTr("未确认执行，请核对状态") : qsTr("已接受；执行状态见遥测"));
            root.pendingCommand = 0;
            timeout.stop();
            if (!root.warning && !root.telemetryMatches(command)) {
                root.awaitedCommand = command;
                root.feedback = root.commandName(command) + qsTr("已接受，等待遥测更新");
                telemetryTimeout.restart();
            }
        }

        ignoreUnknownSignals: true
        target: root.operations.vehicle
    }
    Timer {
        id: timeout

        interval: root.commandTimeoutFor(root.pendingCommand)

        onTriggered: root.expire()
    }
    Timer {
        id: telemetryTimeout

        interval: root.awaitedCommand === 31018 ? 12000 : 8000

        onTriggered: root.expireTelemetry()
    }
}

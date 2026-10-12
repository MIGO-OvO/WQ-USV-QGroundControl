import QtQuick

import "USVFlyViewLayout.js" as USVLayout

Item {
    id: root

    readonly property int _payloadCompId: 191
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
            return true;
        if (pendingCommand || !operations.payloadOnline || operations.payloadFault)
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
        pendingCommand = command;
        pendingSince = Date.now();
        warning = false;
        feedback = commandName(command) + qsTr("发送中，等待载荷响应");
        timeout.restart();
        operations.vehicle.sendCommand(_payloadCompId, command, true, param1 || 0);
    }

    Connections {
        function onVehicleChanged() {
            root.pendingCommand = 0;
            root.feedback = "";
            timeout.stop();
        }

        target: root.operations
    }
    Connections {
        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            if (targetComponent !== root._payloadCompId || command !== root.pendingCommand)
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
        }

        ignoreUnknownSignals: true
        target: root.operations.vehicle
    }
    Timer {
        id: timeout

        interval: root.pendingCommand === 31018 ? 10000 : 5000

        onTriggered: root.expire()
    }
}

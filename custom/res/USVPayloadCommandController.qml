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
    property bool safetyLocked: false
    property var request: null
    property var requestVehicle: null
    property var history: []
    property int transportTick: 0
    readonly property bool protocolReady: operations.fresh("protocolVersion") && operations.factNumber(operations.payload ? operations.payload.protocolVersion : null, 0) === 1
    readonly property bool stopsPending: {
        transportTick;
        return !!operations.vehicle && [31011, 31016, 31019].some(command => operations.vehicle.isMavCommandPending(_payloadCompId, command));
    }

    function now() {
        return operations.payload ? operations.payload.monotonicMs() : 0;
    }
    function lockUnknown() {
        if (requestVehicle)
            requestVehicle.usvSafetyLocked = true;
    }
    function archiveRequest() {
        if (request)
            history = history.concat([request]).slice(-16);
    }

    function allowed(command) {
        if (!operations.connected || !operations.hasPayload)
            return false;
        if (command === 31011 || command === 31016 || command === 31019)
            return pendingCommand !== command && !operations.vehicle.isMavCommandPending(_payloadCompId, command);
        if (safetyLocked || operations.vehicle.usvSafetyLocked || !protocolReady || stopsPending)
            return false;
        const observedStart = command === 31017 && request && request.command === 31018 && request.observed && !request.terminal;
        if (((pendingCommand || awaitedCommand) && !observedStart) || !operations.payloadOnline || operations.payloadFault || operations.payloadStatus < 0 || operations.payloadStatus > USVLayout.StatusSurveying)
            return false;
        if (operations.vehicle.isMavCommandPending(_payloadCompId, command))
            return false;
        if (command === 31018 || command === 31014)
            return !operations.payloadWorking && operations.payloadStatus !== USVLayout.StatusPaused;
        if (command === 31017)
            return operations.validSignal && !operations.payloadWorking && operations.payloadStatus !== USVLayout.StatusPaused;
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
        if (!request || (!pendingCommand && !awaitedCommand))
            return;
        warning = true;
        request = Object.assign({}, request, { unknown: true });
        feedback = request.command === 31018 && request.observed
                ? qsTr("已观察到新有效信号，但命令回执未确认；可核验后设置基线")
                : commandName(request.command) + qsTr("执行结果未知；请停止并核验设备");
        if (!(request.command === 31018 && request.observed))
            lockUnknown();
        pendingCommand = 0;
        awaitedCommand = 0;
        timeout.stop();
    }
    function send(command, param1) {
        if (!allowed(command))
            return;
        const identity = protocolReady && operations.payload ? operations.payload.allocateRequest() : {};
        if ((!identity.session || !identity.request) && [31011, 31016, 31019].indexOf(command) < 0) {
            warning = true;
            feedback = qsTr("无法持久化请求身份；已禁止新动作");
            return;
        }
        archiveRequest();
        const baseline = {};
        for (const field of ["status", "spectrometerValid", "voltage", "baselineSet", "adsState"])
            baseline[field] = operations.payload ? operations.payload.fieldSequence(field) : 0;
        request = Object.assign({}, identity, { command: command, seq: 0, ack: null, observed: false,
                               accepted: false, terminal: null, unknown: false, baseline: baseline,
                               stages: [], deadline: now() + commandTimeoutFor(command) });
        requestVehicle = operations.vehicle;
        awaitedCommand = 0;
        pendingCommand = command;
        pendingSince = now();
        warning = false;
        feedback = commandName(command) + qsTr("发送中，等待载荷响应");
        timeout.restart();
        operations.vehicle.sendCommand(_payloadCompId, command, true, param1 || 0, 0, identity.request || 0, identity.session || 0);
    }

    function telemetryMatches(command) {
        if (!operations.payloadOnline || !request || !operations.payload)
            return false;
        const field = command === 31018 ? "spectrometerValid" : command === 31017 ? "baselineSet" : command === 31019 ? "adsState" : "status";
        if (!operations.fresh(field) || operations.payload.fieldSequence(field) <= request.baseline[field])
            return false;
        const status = operations.payloadStatus;
        switch (command) {
        case 31018: return operations.validSignal && operations.payload.fieldSequence("voltage") > request.baseline.voltage;
        case 31017: return operations.baselineSet;
        case 31010: return [USVLayout.StatusSampling, USVLayout.StatusDetecting, USVLayout.StatusWaitingStable].indexOf(status) >= 0;
        case 31012: return status === USVLayout.StatusPaused;
        case 31013: return status === USVLayout.StatusSampling || status === USVLayout.StatusDetecting;
        case 31014: return status === USVLayout.StatusCalibrating;
        case 31015: return status === USVLayout.StatusSurveying;
        case 31011: return status === USVLayout.StatusIdle || status === USVLayout.StatusAborted || status === USVLayout.StatusHoldNoMission || status === USVLayout.StatusSamplingDone;
        case 31016: return [USVLayout.StatusIdle, USVLayout.StatusSamplingDone, USVLayout.StatusAborted, USVLayout.StatusHoldNoMission].indexOf(status) >= 0;
        case 31019: return operations.factNumber(operations.payload.adsState, -1) === 1;
        default: return true;
        }
    }
    function observeTelemetry() {
        if (!request || request.terminal || !telemetryMatches(request.command))
            return;
        request = Object.assign({}, request, { observed: true });
        warning = !request.accepted;
        feedback = request.accepted ? commandName(request.command) + qsTr("请求已接受，已观察到新状态；不代表任务完成")
                                    : commandName(request.command) + qsTr("已观察到新状态，等待关联回执");
        if (request.accepted) {
            pendingCommand = 0;
            awaitedCommand = 0;
            timeout.stop();
        }
    }
    function observeEvent(event) {
        const matches = candidate => candidate && candidate.session === event.session && candidate.request === event.request
                && candidate.command === event.command && candidate.sender_system === event.sender_system && candidate.sender_component === event.sender_component;
        if (!matches(request)) {
            history = history.map(candidate => matches(candidate) && event.seq > candidate.seq
                    ? Object.assign({}, candidate, { seq: event.seq, terminal: event.phase === "terminal" ? event : candidate.terminal }) : candidate);
            return;
        }
        const nextSurveyAttempt = request.command === 31015 && request.terminal
                && request.terminal.outcome === "succeeded" && event.attempt_id
                && event.attempt_id !== request.terminal.attempt_id
                && (event.phase === "progress" || event.phase === "terminal");
        if (event.seq <= request.seq || (request.terminal && !nextSurveyAttempt))
            return;
        if (nextSurveyAttempt)
            request = Object.assign({}, request, { terminal: null });
        request = Object.assign({}, request, { seq: event.seq, stages: request.stages.concat([event]).slice(-16) });
        if (event.phase === "terminal") {
            request = Object.assign({}, request, { terminal: event });
            pendingCommand = 0;
            awaitedCommand = 0;
            timeout.stop();
            warning = event.outcome !== "succeeded";
            feedback = warning ? qsTr("任务未成功：%1；准备阶段：%2").arg(event.reason).arg(event.preflight_phase || "—")
                               : commandName(request.command) + qsTr("已完成；软件清理结果已记录");
            if (event.cleanup_failed || event.outcome === "failed")
                lockUnknown();
        } else if (event.phase === "request") {
            if (event.outcome === "accepted") {
                request = Object.assign({}, request, { accepted: true });
                pendingCommand = 0;
                awaitedCommand = request.command;
                feedback = commandName(request.command) + qsTr("关联请求已接受，等待新状态");
                observeTelemetry();
            } else {
                warning = true;
                feedback = qsTr("请求未确认执行：%1").arg(event.reason);
                pendingCommand = 0;
                awaitedCommand = 0;
                timeout.stop();
                if (event.outcome !== "rejected")
                    lockUnknown();
            }
        } else if (event.phase === "progress") {
            feedback = event.preflight_phase ? qsTr("设备准备：%1").arg(event.preflight_phase) : qsTr("执行阶段：%1").arg(event.state || "—");
        }
    }
    function observeAck(command, ackResult, failureCode) {
        if (!request || request.command !== command || request.terminal)
            return;
        request = Object.assign({}, request, { ack: { result: ackResult, failure: failureCode } });
        // Standard ACK lacks request identity. Keep it as evidence only; never
        // complete a newer request or overwrite a correlated terminal with it.
        if (!request.accepted) {
            warning = ackResult !== 0 && ackResult !== 5 || failureCode !== 0;
            feedback = commandName(command) + qsTr("收到标准回执，仍待关联结果");
        }
    }
    function reset() {
        if (request && !request.terminal && (pendingCommand || awaitedCommand || request.command === 31010 || request.command === 31015)) {
            lockUnknown();
            request = Object.assign({}, request, { unknown: true });
        }
        archiveRequest();
        request = null;
        requestVehicle = null;
        pendingCommand = 0;
        awaitedCommand = 0;
        feedback = history.length ? qsTr("连接或无人船已切换；旧请求结果保留，禁止自动续跑") : "";
        warning = history.length > 0;
        timeout.stop();
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
        target: root.operations.payload
        ignoreUnknownSignals: true
        function onFreshnessChanged() { root.observeTelemetry(); }
        function onPayloadEventReceived(event) { root.observeEvent(event); }
    }
    Connections {
        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            if (!root.operations.vehicle || vehicleId !== root.operations.vehicle.id || targetComponent !== root._payloadCompId)
                return;
            root.observeAck(command, ackResult, failureCode);
        }

        ignoreUnknownSignals: true
        target: root.operations.vehicle
    }
    Timer {
        id: timeout
        interval: 250
        repeat: true
        onTriggered: { if (root.request && root.now() >= root.request.deadline) root.expire(); }
    }
    Timer {
        interval: 250
        running: root.operations.connected
        repeat: true
        onTriggered: root.transportTick++
    }
}

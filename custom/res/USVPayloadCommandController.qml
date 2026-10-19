import QtQuick

import "USVFlyViewLayout.js" as USVLayout

Item {
    id: root

    readonly property int _payloadCompId: 191
    property int awaitedCommand: 0
    readonly property bool busy: pendingCommand !== 0 || awaitedCommand !== 0
    readonly property bool canStartPointSample: operations.payloadStatus === USVLayout.StatusIdle || operations.payloadStatus === USVLayout.StatusSamplingDone || operations.payloadStatus === USVLayout.StatusHoldNoMission
    property string commandFeedback: ""
    readonly property string feedback: {
        const failed = activeFailure();
        return failed ? terminalFeedback(failed.terminal) : commandFeedback;
    }
    required property var operations
    property int pendingCommand: 0
    property double pendingSince: 0
    readonly property bool ready: operations.payloadOnline && operations.validSignal && operations.baselineSet
    property bool commandWarning: false
    readonly property bool warning: taskFailed || commandWarning
    property bool safetyLocked: false
    property var request: null
    property var activeTask: null
    readonly property bool taskFailed: !!activeFailure()
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
    function lockUnknown(candidate) {
        const targetVehicle = (candidate || request || {}).vehicle;
        if (targetVehicle)
            targetVehicle.usvSafetyLocked = true;
    }
    function sameRequest(left, right) {
        return !!left && !!right && left.vehicle === right.vehicle && left.session === right.session && left.request === right.request
                && left.command === right.command && left.sender_system === right.sender_system && left.sender_component === right.sender_component;
    }
    function archive(candidate) {
        if (candidate)
            history = history.filter(record => !sameRequest(record, candidate)).concat([candidate]).slice(-16);
    }
    function archiveRequest() {
        archive(request);
    }
    function physicalCommand(command) {
        return command === 31010 || command === 31014 || command === 31015;
    }
    function stopCommand(command) {
        return command === 31011 || command === 31016 || command === 31019;
    }
    function movesOutputs(command) {
        return physicalCommand(command) || command === 31013;
    }
    // A correlated request-phase result is a complete answer for a finite
    // command. Only acquisition-like commands keep waiting for the device to
    // reach a new state, and that state is evidence of progress, not of receipt.
    function resultKnown(candidate) {
        return !!candidate && (!!candidate.terminal || (!!candidate.accepted && !physicalCommand(candidate.command)));
    }
    function taskUnfinished(candidate) {
        if (!candidate || !physicalCommand(candidate.command) || candidate.physicalStopVerified)
            return false;
        if (!candidate.terminal || candidate.terminal.cleanup_failed)
            return true;
        return candidate.command === 31015 && candidate.terminal.outcome === "succeeded" && !candidate.surveyStopped;
    }
    function activeFailure() {
        const task = activeTask && activeTask.vehicle === operations.vehicle ? activeTask : null;
        if (task && !task.physicalStopVerified && task.terminal
                && (task.terminal.cleanup_failed || task.terminal.outcome === "failed"))
            return task;
        if (!operations.vehicle)
            return null;
        for (let index = history.length - 1; index >= 0; --index) {
            const record = history[index];
            if (record.vehicle === operations.vehicle && !record.physicalStopVerified && record.terminal
                    && (record.terminal.cleanup_failed || record.terminal.outcome === "failed"))
                return record;
        }
        return null;
    }
    function saveRequest(candidate) {
        request = candidate;
        if (sameRequest(activeTask, candidate))
            activeTask = candidate;
    }
    function terminalFeedback(event) {
        return qsTr("任务未成功：%1；准备阶段：%2").arg(event.reason).arg(event.preflight_phase || "—");
    }
    function confirmPhysicalStop(targetVehicle) {
        const failed = activeFailure();
        history = history.map(record => record.vehicle === targetVehicle && (physicalCommand(record.command) || stopCommand(record.command))
                              ? Object.assign({}, record, { physicalStopVerified: true, retired: true }) : record);
        if (activeTask && activeTask.vehicle === targetVehicle) {
            archive(Object.assign({}, activeTask, { physicalStopVerified: true, retired: true }));
            activeTask = null;
        }
        // The verified stop answers this request; retire it so a late accepted,
        // progress or terminal can no longer reopen the wait or re-lock.
        if (request && request.vehicle === targetVehicle) {
            archive(Object.assign({}, request, { physicalStopVerified: true, retired: true }));
            request = null;
            pendingCommand = 0;
            awaitedCommand = 0;
            timeout.stop();
        }
        commandWarning = !!failed;
        commandFeedback = failed && failed.terminal
                ? qsTr("上一任务失败：%1；本次停止已核验").arg(failed.terminal.reason)
                : qsTr("已核验设备停止");
    }

    function allowed(command) {
        if (!operations.connected || !operations.hasPayload)
            return false;
        // Stop paths stay reachable while a lock, an unknown result or an old
        // protocol version is still being resolved. Hiding them would hide the
        // only exit the operator has.
        if (stopCommand(command))
            return pendingCommand !== command && !operations.vehicle.isMavCommandPending(_payloadCompId, command);
        if (safetyLocked || operations.vehicle.usvSafetyLocked || !protocolReady || stopsPending)
            return false;
        const observedStart = command === 31017 && request && request.command === 31018 && request.observed && !request.terminal;
        if (((pendingCommand || awaitedCommand) && !observedStart) || !operations.payloadOnline || operations.payloadStatus < 0 || operations.payloadStatus > USVLayout.StatusSurveying)
            return false;
        // A current device fault forbids motion, not device recovery: starting
        // the detector or re-baselining is how the operator clears it.
        if (operations.payloadFault && movesOutputs(command))
            return false;
        if (operations.vehicle.isMavCommandPending(_payloadCompId, command))
            return false;
        if (physicalCommand(command) && activeTask && activeTask.vehicle === operations.vehicle && taskUnfinished(activeTask))
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
        // Receipt window: how long the backend may take to answer at all.
        if (command === 31018)
            return 40000;
        if (stopCommand(command))
            return 15000;
        return 5000;
    }
    function progressTimeoutFor(command) {
        // Silence window while the command is genuinely executing. Renewed only
        // by a correlated event for this request, never by a local heartbeat.
        if (stopCommand(command))
            return 15000;
        if (command === 31018)
            return 30000;
        if (physicalCommand(command))
            return 60000;
        return 15000;
    }
    function expire() {
        if (!request || (!pendingCommand && !awaitedCommand))
            return;
        if (request.terminal)
            return;
        if (now() < request.deadline)
            return;
        if (resultKnown(request)) {
            // The command has an answer; the device state is a separate,
            // asynchronous fact and must not turn a success into an unknown.
            commandWarning = false;
            commandFeedback = request.command === 31018
                    ? qsTr("启动已确认，等待有效数据")
                    : commandName(request.command) + qsTr("已接受，等待设备状态更新");
            pendingCommand = 0;
            awaitedCommand = 0;
            timeout.stop();
            return;
        }
        commandWarning = true;
        saveRequest(Object.assign({}, request, { unknown: true }));
        commandFeedback = request.command === 31018 && request.observed
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
            commandWarning = true;
            commandFeedback = qsTr("无法持久化请求身份；已禁止新动作");
            return;
        }
        archiveRequest();
        const baseline = {};
        for (const field of ["status", "spectrometerValid", "voltage", "baselineSet", "adsState"])
            baseline[field] = operations.payload ? operations.payload.fieldSequence(field) : 0;
        request = Object.assign({}, identity, { command: command, seq: 0, ack: null, observed: false,
                               accepted: false, executing: false, terminal: null, unknown: false, baseline: baseline,
                               vehicle: operations.vehicle, attemptId: "", latestEvent: null,
                               stages: [], deadline: now() + commandTimeoutFor(command) });
        if (physicalCommand(command))
            activeTask = request;
        awaitedCommand = 0;
        pendingCommand = command;
        pendingSince = now();
        commandWarning = false;
        commandFeedback = commandName(command) + qsTr("发送中，等待载荷响应");
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
        saveRequest(Object.assign({}, request, { observed: true }));
        const executionProven = request.accepted || request.executing;
        commandWarning = !executionProven;
        commandFeedback = executionProven ? commandName(request.command) + qsTr("已确认进入执行并观察到新状态；不代表任务完成")
                                    : commandName(request.command) + qsTr("已观察到新状态，等待关联回执");
        if (executionProven) {
            pendingCommand = 0;
            awaitedCommand = 0;
            timeout.stop();
            if (request.command === 31016 && activeTask && activeTask.command === 31015
                    && activeTask.vehicle === operations.vehicle)
                activeTask = Object.assign({}, activeTask, { surveyStopped: true });
        }
    }
    function observeEvent(event) {
        // Identity is scoped to the captured Vehicle, not the currently selected
        // command. Pause/resume must not retire a physical acquisition.
        const matches = candidate => candidate && candidate.vehicle === operations.vehicle
                && candidate.session === event.session && candidate.request === event.request && candidate.command === event.command
                && candidate.sender_system === event.sender_system && candidate.sender_component === event.sender_component;
        const current = matches(request);
        const task = matches(activeTask);
        // Several stop buttons may be in flight at once. Keep every unfinished
        // request correlatable so a later result updates its own record instead
        // of being dropped (or overwriting the newest feedback).
        const unfinished = history.find(record => matches(record) && !record.retired
                          && !record.terminal && !record.physicalStopVerified);
        // A physical task lost by a reconnect is re-attached to activeTask; a
        // secondary stop request only updates its own history record.
        const retainedTask = !activeTask && unfinished && physicalCommand(unfinished.command) ? unfinished : null;
        if (!current && !task && !unfinished)
            return;
        const candidate = current ? request : task ? activeTask : unfinished;
        if (candidate.retired)
            return;
        const nextSurveyAttempt = candidate.command === 31015 && candidate.terminal
                && candidate.terminal.outcome === "succeeded" && event.attempt_id
                && event.attempt_id !== candidate.terminal.attempt_id
                && (event.phase === "progress" || event.phase === "terminal");
        if (event.seq <= candidate.seq || (candidate.terminal && !nextSurveyAttempt)
                || (candidate.attemptId && event.attempt_id && candidate.attemptId !== event.attempt_id && !nextSurveyAttempt)
                || (event.phase === "progress" && event.outcome !== ""))
            return;
        const progressAt = now();
        const updated = Object.assign({}, candidate, { seq: event.seq, latestEvent: event,
            attemptId: event.attempt_id || candidate.attemptId,
            terminal: nextSurveyAttempt ? null : candidate.terminal,
            deadline: event.phase === "progress" ? progressAt + progressTimeoutFor(candidate.command) : candidate.deadline,
            stages: candidate.stages.concat([event]).slice(-16) });
        if (event.phase === "progress")
            updated.executing = true;
        if (event.phase === "request" && event.outcome === "accepted")
            updated.accepted = true;
        if (event.phase === "terminal")
            updated.terminal = event;
        if (current)
            request = updated;
        if (task || retainedTask)
            activeTask = updated;
        history = history.map(record => sameRequest(record, updated) ? updated : record);
        if (event.phase === "terminal") {
            if (current) {
                pendingCommand = 0;
                awaitedCommand = 0;
                timeout.stop();
            }
            if (current || task) {
                commandWarning = event.outcome !== "succeeded";
                commandFeedback = commandWarning ? terminalFeedback(event)
                                   : commandName(updated.command) + qsTr("已完成；软件清理结果已记录");
            }
            // Only a failure with unproven output shutdown escalates to the
            // vessel lock. A cancelled physical run was stopped by the stop
            // path, and a measurement command never moved anything.
            if (event.cleanup_failed
                    || (event.outcome === "failed" && physicalCommand(updated.command)))
                lockUnknown(updated);
        } else if (current && event.phase === "request") {
            if (event.outcome === "accepted") {
                pendingCommand = 0;
                const settled = !physicalCommand(request.command);
                if (settled) {
                    // The command answered. A missing follow-up state is
                    // reported as pending evidence, never as an unknown command
                    // that locks the whole vessel.
                    awaitedCommand = 0;
                    timeout.stop();
                    commandWarning = false;
                    commandFeedback = request.command === 31018
                            ? qsTr("启动已确认，等待有效数据")
                            : commandName(request.command) + qsTr("已接受，等待设备状态更新");
                } else {
                    awaitedCommand = request.command;
                    commandFeedback = commandName(request.command) + qsTr("关联请求已接受，等待新状态");
                }
                observeTelemetry();
            } else {
                commandWarning = true;
                commandFeedback = qsTr("请求未确认执行：%1").arg(event.reason);
                pendingCommand = 0;
                awaitedCommand = 0;
                timeout.stop();
                if (event.outcome !== "rejected")
                    lockUnknown();
                else if (task)
                    activeTask = null;
            }
        } else if (event.phase === "progress") {
            commandFeedback = event.preflight_phase ? qsTr("设备准备：%1").arg(event.preflight_phase) : qsTr("执行阶段：%1").arg(event.state || "—");
            if (current) {
                pendingCommand = 0;
                awaitedCommand = request.command;
                timeout.restart();
                observeTelemetry();
            }
        }
    }
    function observeAck(command, ackResult, failureCode) {
        if (!request || request.command !== command || request.terminal)
            return;
        saveRequest(Object.assign({}, request, { ack: { result: ackResult, failure: failureCode } }));
        // Standard ACK lacks request identity. Keep it as evidence only; never
        // complete a newer request or overwrite a correlated terminal with it.
        if (!request.accepted && !request.executing) {
            commandWarning = ackResult !== 0 && ackResult !== 5 || failureCode !== 0;
            commandFeedback = commandName(command) + qsTr("收到标准回执，仍待关联结果");
        }
    }
    function reset() {
        if (request && !request.terminal && (pendingCommand || awaitedCommand || taskUnfinished(request))) {
            lockUnknown();
            request = Object.assign({}, request, { unknown: true });
        }
        archiveRequest();
        if (taskUnfinished(activeTask)) {
            lockUnknown(activeTask);
            archive(Object.assign({}, activeTask, { unknown: true }));
        }
        activeTask = null;
        request = null;
        pendingCommand = 0;
        awaitedCommand = 0;
        commandFeedback = history.length ? qsTr("连接或无人船已切换；旧请求结果保留，禁止自动续跑") : "";
        commandWarning = history.length > 0;
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
        onTriggered: root.expire()
    }
    Timer {
        interval: 250
        running: root.operations.connected
        repeat: true
        onTriggered: root.transportTick++
    }
}

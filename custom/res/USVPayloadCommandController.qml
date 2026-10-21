import QtQuick

import "USVFlyViewLayout.js" as USVLayout

Item {
    id: root

    readonly property int _payloadCompId: 191
    readonly property bool busy: pendingCommand !== 0
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
    readonly property bool protocolReady: operations.fresh("protocolVersion") && operations.factNumber(operations.payload ? operations.payload.protocolVersion : null, 0) === 1
    readonly property bool stopsPending: {
        return !!operations.vehicle && [31011, 31016, 31019].some(command => transportPending(command));
    }

    function transportPending(command) {
        return !!operations.vehicle && operations.vehicle.pendingMavCommands.indexOf(_payloadCompId + ":" + command) >= 0;
    }
    function executingFeedback(command) {
        return command === 31014 ? qsTr("正在校准") : physicalCommand(command) ? qsTr("正在采样") : qsTr("等待设备状态");
    }
    function now() {
        return operations.payload ? operations.payload.monotonicMs() : 0;
    }
    // The vessel-wide lock is reserved for a physical state this client cannot
    // confirm: an unconfirmed output shutdown or a lost link while a task may
    // still be running. An unanswered command is only an unanswered command.
    function lockUnknown(candidate, source) {
        const targetVehicle = (candidate || request || {}).vehicle;
        if (targetVehicle)
            targetVehicle.usvSafetyLockSource = source || "outputs";
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
    // command. An accepted acquisition-like command answers the request too:
    // whether the task then runs, pauses or fails is the device state's job.
    function resultKnown(candidate) {
        return !!candidate && (!!candidate.terminal || !!candidate.accepted);
    }
    function taskUnfinished(candidate) {
        if (!candidate || !physicalCommand(candidate.command) || candidate.physicalStopVerified || candidate.retired)
            return false;
        if (!candidate.terminal || candidate.terminal.cleanup_failed)
            return true;
        return candidate.command === 31015 && candidate.terminal.outcome === "succeeded" && !candidate.surveyStopped;
    }
    function activeFailure() {
        const task = activeTask && activeTask.vehicle === operations.vehicle ? activeTask : null;
        if (task && !task.physicalStopVerified && task.terminal
                && (task.terminal.cleanup_failed || !task.retired && task.terminal.outcome === "failed"))
            return task;
        if (!operations.vehicle)
            return null;
        for (let index = history.length - 1; index >= 0; --index) {
            const record = history[index];
            if (record.vehicle === operations.vehicle && !record.physicalStopVerified && record.terminal
                    && (record.terminal.cleanup_failed || !record.retired && record.terminal.outcome === "failed"))
                return record;
        }
        return null;
    }
    function saveRequest(candidate) {
        request = candidate;
        if (sameRequest(activeTask, candidate))
            activeTask = candidate;
    }
    function applyTaskStop(stop) {
        const task = activeTask;
        if (!stop || !stop.accepted || stop.retired || stop.terminal
                || !sameRequest(task, stop.stopTarget) || task.retired || task.physicalStopVerified
                || (stop.command !== 31011 && (stop.command !== 31016 || task.command !== 31015)))
            return;
        // The captured task identity survives moving this STOP into history.
        // Only status newer than its result may finish that task.
        activeTask = Object.assign({}, task, { stoppedByRequest: stop.command,
            surveyStopped: task.surveyStopped || stop.command === 31016,
            evidenceStatus: Math.max(task.evidenceStatus || 0, stop.evidenceStatus || 0) });
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
            timeout.stop();
        }
        commandWarning = !!failed;
        commandFeedback = failed && failed.terminal
                ? qsTr("上一任务失败：%1；本次停止已核验").arg(failed.terminal.reason)
                : qsTr("已核验设备停止");
    }
    function payloadIdle() {
        return [USVLayout.StatusIdle, USVLayout.StatusSamplingDone,
                USVLayout.StatusHoldNoMission].indexOf(operations.payloadStatus) >= 0;
    }
    function recoverCommunication() {
        const target = operations.vehicle;
        if (!target || !operations.connected || target.usvSafetyLockSource !== "communication"
                || transportPending(31011))
            return;
        const statusSeq = idleReading();
        const confirmed = [request].concat(history).some(record => record && record.vehicle === target
                && record.command === 31011 && record.communicationRecovery && record.accepted
                && !record.retired && !record.terminal && statusSeq > record.evidenceStatus);
        if (!confirmed)
            return;
        confirmPhysicalStop(target);
        target.usvSafetyLocked = false;
        commandWarning = false;
        commandFeedback = qsTr("采样输出停止已确认，通信锁定已解除");
    }
    // An idle reading with its own receive sequence. The sequence is a client
    // receive counter, so an unchanged USV_STAT value still produces a new one:
    // the reading alone says "the payload looks idle now", never "this task
    // ended". It is only half of the evidence used below.
    function idleReading() {
        if (!operations.payloadOnline || !operations.payload || !operations.fresh("status"))
            return -1;
        if (!payloadIdle())
            return -1;
        return operations.payload.fieldSequence("status");
    }
    // Why a task may be treated as finished by the current device state.
    // Every path needs its own closing evidence, all of it already tracked:
    //   * the run reached its own terminal (one attempt only for 31015);
    //   * the payload was really seen running and now reports idle;
    //   * the survey schedule was stopped by 31016;
    function convergenceEvidence(task, statusSeq) {
        if (!task || !physicalCommand(task.command) || task.retired || task.physicalStopVerified)
            return false;
        const known = task.evidenceStatus !== undefined ? task.evidenceStatus
                                                        : (task.baseline ? task.baseline.status : 0);
        if (statusSeq <= known)
            return false;
        if (task.command === 31015) {
            // One attempt's terminal, including a successful one, does not end
            // the survey schedule; only its own stop result does.
            return !!task.surveyStopped || !!task.stoppedByRequest
                    || (!!task.terminal && task.terminal.outcome !== "succeeded");
        }
        if (task.terminal)
            return true;
        if (task.stoppedByRequest)
            return true;
        if (task.observed)
            return true;
        return false;
    }
    // The current device state decides what is allowed now, but only evidence
    // that this task ended may retire it. It keeps its reason in history and
    // stops blocking preparation.
    function reconcileState() {
        const task = activeTask && activeTask.vehicle === operations.vehicle ? activeTask : null;
        if (!task)
            return;
        const statusSeq = idleReading();
        if (statusSeq < 0 || !convergenceEvidence(task, statusSeq))
            return;
        archive(Object.assign({}, task, { stoppedByCurrentState: true, retired: true }));
        if (sameRequest(request, task)) {
            request = Object.assign({}, request, { retired: true });
            pendingCommand = 0;
            timeout.stop();
        }
        activeTask = null;
        commandWarning = false;
        commandFeedback = qsTr("设备已停止，可以重新准备");
    }
    function unresolvedMotion() {
        return taskUnfinished(activeTask && activeTask.vehicle === operations.vehicle ? activeTask : null);
    }
    function blockedReason(command) {
        if (allowed(command))
            return "";
        if (!operations.connected)
            return qsTr("等待无人船连接");
        if (!operations.hasPayload)
            return qsTr("载荷未接入");
        if (stopCommand(command))
            return transportPending(command)
                    ? qsTr("同类停止仍在处理中") : qsTr("当前不可用");
        if (safetyLocked || operations.vehicle.usvSafetyLocked)
            return operations.vehicle.usvSafetyLockSource === "communication"
                    ? qsTr("通信中断后，请停止采样并等待状态同步") : qsTr("操作已锁定，请先核验设备停止");
        if (!protocolReady)
            return qsTr("等待载荷协议能力汇报");
        if (stopsPending)
            return qsTr("停止命令仍在处理中");
        if (pendingCommand)
            return qsTr("上一条命令仍在等待回执");
        if (!operations.payloadOnline || operations.payloadStatus < 0 || operations.payloadStatus > USVLayout.StatusSurveying)
            return qsTr("载荷遥测不可用");
        if (operations.payloadFault && movesOutputs(command))
            return qsTr("当前载荷故障：%1").arg(operations.payloadFault);
        if (physicalCommand(command) && unresolvedMotion())
            return qsTr("上次任务尚未确认结束，请先停止");
        if (command === 31018 || command === 31014)
            return operations.payloadStatus === USVLayout.StatusPaused ? qsTr("设备处于暂停状态") : qsTr("设备仍在作业");
        if (command === 31017)
            return operations.validSignal ? qsTr("设备仍在作业") : qsTr("尚无有效信号，无法设置基线");
        if (command === 31010 || command === 31015)
            return !canStartPointSample ? qsTr("当前状态不支持启动采样")
                                        : qsTr("缺少有效信号或基线");
        return qsTr("当前状态不可用");
    }
    // Disabled controls explain the missing condition instead of hiding it.
    function helpTextFor(command, fallback) {
        const reason = blockedReason(command);
        return reason.length ? reason : fallback;
    }

    function allowed(command) {
        if (!operations.connected || !operations.hasPayload)
            return false;
        // Stop paths stay reachable while a lock, an unanswered command or an
        // old protocol version is still being resolved. Hiding them would hide
        // the only exit the operator has.
        if (stopCommand(command))
            return !transportPending(command);
        if (safetyLocked || operations.vehicle.usvSafetyLocked || !protocolReady || stopsPending)
            return false;
        const observedStart = command === 31017 && request && request.command === 31018 && request.observed && !request.terminal;
        if ((pendingCommand && !observedStart) || !operations.payloadOnline || operations.payloadStatus < 0 || operations.payloadStatus > USVLayout.StatusSurveying)
            return false;
        // A current device fault forbids motion, not device recovery: starting
        // the detector or re-baselining is how the operator clears it.
        if (operations.payloadFault && movesOutputs(command))
            return false;
        if (transportPending(command))
            return false;
        if (physicalCommand(command) && unresolvedMotion())
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
    function acceptedFeedback(command) {
        if (command === 31018)
            return qsTr("启动已确认，等待有效数据");
        if (stopCommand(command))
            return qsTr("已完成");
        return executingFeedback(command);
    }
    function settleReceipt() {
        // The command answered. The device state is a separate, asynchronous
        // fact: it updates the task, it does not re-open this send.
        commandWarning = false;
        commandFeedback = acceptedFeedback(request.command);
        pendingCommand = 0;
        timeout.stop();
    }
    function expire() {
        if (!request || !pendingCommand || request.terminal)
            return;
        if (resultKnown(request)) {
            settleReceipt();
            return;
        }
        if (now() < request.deadline || transportPending(request.command))
            return;
        // End only this send wait. Nothing here proves the vessel is idle, so
        // nothing is locked and no new request is invented. A periodic Idle
        // still cannot prove that the unanswered START never ran.
        commandWarning = true;
        saveRequest(Object.assign({}, request, {
                                      unacknowledged: true }));
        commandFeedback = qsTr("响应超时");
        pendingCommand = 0;
        timeout.stop();
    }
    function send(command, param1) {
        if (!allowed(command))
            return;
        const identity = protocolReady && operations.payload ? operations.payload.allocateRequest() : {};
        if ((!identity.session || !identity.request) && [31011, 31016, 31019].indexOf(command) < 0) {
            commandWarning = true;
            commandFeedback = qsTr("无法分配请求关联标识；已禁止新动作");
            return;
        }
        archiveRequest();
        const baseline = {};
        for (const field of ["status", "spectrometerValid", "voltage", "baselineSet", "adsState"])
            baseline[field] = operations.payload ? operations.payload.fieldSequence(field) : 0;
        request = Object.assign({}, identity, { command: command, seq: 0, ack: null, observed: false,
                               accepted: false, executing: false, terminal: null, unknown: false, baseline: baseline,
                               // Receive sequence of the newest fact we hold about
                               // this task; an idle reading older than it proves nothing.
                               evidenceStatus: baseline.status, surveyStopped: false,
                               stopTarget: stopCommand(command) ? activeTask : null,
                               vehicle: operations.vehicle, attemptId: "", latestEvent: null,
                               stages: [], deadline: now() + commandTimeoutFor(command) });
        request.communicationRecovery = command === 31011 && !!identity.session
                && operations.vehicle.usvSafetyLockSource === "communication";
        if (physicalCommand(command))
            activeTask = request;
        pendingCommand = command;
        pendingSince = now();
        commandWarning = false;
        commandFeedback = qsTr("等待响应");
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
        recoverCommunication();
        applyTaskStop(request);
        reconcileState();
        if (!request || request.retired || request.terminal || !telemetryMatches(request.command))
            return;
        // A compatible STOP has no USVE1. Preserve its final standard result;
        // later device readings cannot demand an event or erase a rejection.
        const compatible = !request.session || !request.request;
        if (compatible && request.ack && !request.accepted)
            return;
        // This reading is the running evidence for the task, and it is also the
        // newest status fact the task holds: only a later idle may end it.
        const statusSeq = operations.payload ? operations.payload.fieldSequence("status") : 0;
        saveRequest(Object.assign({}, request, { observed: true,
                                                 evidenceStatus: Math.max(request.evidenceStatus || 0, statusSeq) }));
        const executionProven = request.accepted || request.executing;
        commandWarning = !executionProven;
        commandFeedback = executionProven ? executingFeedback(request.command)
                                    : qsTr("等待响应");
        if (executionProven) {
            pendingCommand = 0;
            timeout.stop();
        }
    }
    function observeEvent(event) {
        // Identity is scoped to the captured Vehicle, not the currently selected
        // command. Pause/resume must not retire a physical acquisition. A
        // request without an identity can never be correlated.
        const matches = candidate => !!candidate && candidate.vehicle === operations.vehicle
                && !!candidate.session && !!candidate.request
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
        if (candidate.retired) {
            // A retired reference keeps its history only: a late terminal can
            // neither re-open a wait nor re-lock the vessel.
            history = history.map(record => sameRequest(record, candidate)
                                  ? Object.assign({}, record, { lateEvent: event }) : record);
            return;
        }
        const nextSurveyAttempt = candidate.command === 31015 && candidate.terminal
                && candidate.terminal.outcome === "succeeded" && event.attempt_id
                && event.attempt_id !== candidate.terminal.attempt_id
                && (event.phase === "progress" || event.phase === "terminal");
        if (event.seq <= candidate.seq || (candidate.terminal && !nextSurveyAttempt)
                || (candidate.attemptId && event.attempt_id && candidate.attemptId !== event.attempt_id && !nextSurveyAttempt)
                || (event.phase === "progress" && event.outcome !== ""))
            return;
        const updated = Object.assign({}, candidate, { seq: event.seq, latestEvent: event,
            attemptId: event.attempt_id || candidate.attemptId,
            terminal: nextSurveyAttempt ? null : candidate.terminal,
            // A correlated answer is newer than every status reading already
            // received: only an idle reading after it may end this task.
            evidenceStatus: Math.max(candidate.evidenceStatus || 0,
                                     operations.payload ? operations.payload.fieldSequence("status") : 0),
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
        if (event.phase === "request" && event.outcome === "accepted")
            applyTaskStop(updated);
        if (event.phase === "terminal") {
            if (current) {
                pendingCommand = 0;
                timeout.stop();
            }
            if (current || task) {
                commandWarning = event.outcome !== "succeeded";
                commandFeedback = commandWarning ? terminalFeedback(event)
                                   : qsTr("已完成");
            }
            // Only an unconfirmed output shutdown escalates to the vessel lock.
            // A failed run whose stop was confirmed is history, not a lock.
            if (event.cleanup_failed)
                lockUnknown(updated);
        } else if (current && event.phase === "request") {
            if (event.outcome === "accepted") {
                settleReceipt();
                observeTelemetry();
            } else {
                commandWarning = true;
                commandFeedback = qsTr("操作失败：%1").arg(event.reason);
                pendingCommand = 0;
                timeout.stop();
                // The request never became work, so it must not keep blocking
                // the next attempt as if it were a running task.
                if (task && !event.cleanup_failed) {
                    archive(Object.assign({}, task, { retired: true }));
                    activeTask = null;
                }
                if (event.cleanup_failed)
                    lockUnknown();
            }
        } else if (event.phase === "progress") {
            commandFeedback = executingFeedback(updated.command);
            if (current) {
                pendingCommand = 0;
                timeout.stop();
                observeTelemetry();
            }
        }
    }
    function observeAck(command, ackResult, failureCode) {
        if (!request || request.command !== command || request.retired || request.terminal)
            return;
        const correlated = !!request.session && !!request.request;
        if (!correlated && request.ack && (request.ack.result !== 5 || request.ack.failure !== 0))
            return;  // A final compatible result cannot be replaced by a late ACK.
        saveRequest(Object.assign({}, request, { ack: { result: ackResult, failure: failureCode } }));
        recoverCommunication();
        if (!request)
            return;
        if (request.accepted || request.executing)
            return;  // A correlated answer already settled this request.
        if (correlated) {
            // Correlated requests have their own event; the standard ACK stays
            // evidence and must not complete or reject them.
            commandWarning = ackResult !== 0 && ackResult !== 5 || failureCode !== 0;
            commandFeedback = qsTr("等待响应");
            return;
        }
        // Compatible STOP clients get only the standard ACK. It is this
        // request's answer, matched by command, target component and the one
        // in-flight request, and it ends the wait instead of a USVE1 event
        // that this path will never receive.
        if (ackResult === 5 && failureCode === 0) {
            commandWarning = false;
            commandFeedback = commandName(command) + qsTr("处理中");
            return;
        }
        const accepted = ackResult === 0 && failureCode === 0;
        if (accepted)
            saveRequest(Object.assign({}, request, { accepted: true,
                evidenceStatus: operations.payload ? operations.payload.fieldSequence("status") : 0 }));
        commandWarning = !accepted;
        pendingCommand = 0;
        timeout.stop();
        commandFeedback = accepted ? acceptedFeedback(command)
                                   : commandName(command) + qsTr("未获确认：标准回执 %1").arg(ackResult);
        if (accepted)
            observeTelemetry();
    }
    function reset() {
        // A stop from before this disconnect cannot recover the new unknown
        // state. Only a request issued after reconnect may do so.
        history = history.map(record => Object.assign({}, record, { communicationRecovery: false }));
        if (request)
            saveRequest(Object.assign({}, request, { communicationRecovery: false }));
        // A lost link with a task that may still be running is the one case
        // this client cannot answer on its own.
        if (request && !request.terminal && pendingCommand && physicalCommand(request.command)
                && !request.physicalStopVerified) {
            lockUnknown(null, "communication");
            request = Object.assign({}, request, { unknown: true });
        }
        archiveRequest();
        if (taskUnfinished(activeTask)) {
            lockUnknown(activeTask, "communication");
            archive(Object.assign({}, activeTask, { unknown: true }));
        }
        activeTask = null;
        request = null;
        pendingCommand = 0;
        commandFeedback = history.length ? qsTr("连接或无人船已切换，请确认设备状态") : "";
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

}

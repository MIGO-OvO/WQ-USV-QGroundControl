import QtQuick
import QtTest
import "../res"
import "../res/USVFlyViewLayout.js" as Status

Item {
    id: root
    width: 640
    height: 480

    Component {
        id: controllerComponent
        USVPayloadCommandController { }
    }
    Component {
        id: vehicleComponent
        QtObject {
            property int id: 1
            property bool usvSafetyLocked: false
            property var pending: []
            property var sent: []
            signal mavCommandResult(int vehicleId, int targetComponent, int command, int result, int failure)
            function isMavCommandPending(component, command) { return pending.indexOf(command) >= 0; }
            function sendCommand(component, command, showError, p1, p2, p3, p4) {
                sent = sent.concat([{command: command, request: p3, session: p4}]);
            }
        }
    }
    Component {
        id: payloadComponent
        QtObject {
            property var protocolVersion: ({ rawValue: 1 })
            property var adsState: ({ rawValue: 3 })
            property var sequences: ({})
            property int nextRequest: 0
            property double clock: 1000
            signal freshnessChanged()
            signal payloadEventReceived(var event)
            function monotonicMs() { return clock; }
            function fieldSequence(field) { return sequences[field] || 0; }
            function receive(field) {
                sequences[field] = fieldSequence(field) + 1;
                freshnessChanged();
            }
            function allocateRequest() {
                return {session: 10, request: ++nextRequest, sender_system: 255, sender_component: 190};
            }
        }
    }
    Component {
        id: operationsComponent
        QtObject {
            property var vehicle
            property var payload
            property bool connected: true
            property bool hasPayload: true
            property bool payloadOnline: true
            property bool validSignal: true
            property bool baselineSet: true
            property bool payloadFault: false
            property bool payloadWorking: false
            property int payloadStatus: Status.StatusIdle
            function fresh(field) { return payloadOnline; }
            function factNumber(fact, fallback) { return fact ? fact.rawValue : fallback; }
        }
    }

    TestCase {
        name: "USVPayloadCommandController"
        when: windowShown
        property var vehicle
        property var payload
        property var operations
        property var controller

        function init() {
            vehicle = createTemporaryObject(vehicleComponent, root);
            payload = createTemporaryObject(payloadComponent, root);
            operations = createTemporaryObject(operationsComponent, root, {vehicle: vehicle, payload: payload});
            controller = createTemporaryObject(controllerComponent, root, {operations: operations});
            verify(!!controller, "Component exists");
        }
        function event(seq, phase, outcome, extra) {
            return Object.assign({}, controller.request, {v: 1, tcp_session: 1, seq: seq, phase: phase, outcome: outcome,
                reason: "", attempt_id: "11111111111111111111111111111111", preflight_phase: ""}, extra || {});
        }
        function startSample() {
            controller.send(31010);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            operations.payloadStatus = Status.StatusSampling;
            payload.receive("status");
            return Object.assign({}, controller.request);
        }
        function pauseSample() {
            controller.send(31012);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            operations.payloadStatus = Status.StatusPaused;
            payload.receive("status");
        }
        function test_correlatedProgressProvesExecutionWithoutAccepted() {
            controller.send(31010);
            operations.payloadStatus = Status.StatusSampling;
            payload.receive("status");
            payload.payloadEventReceived(event(2, "progress", "", {state: "running"}));
            const deadline = controller.request.deadline;
            payload.clock = deadline + 1;
            wait(350);
            compare(controller.request.unknown, false);
            compare(controller.busy, false);
            compare(controller.request.accepted, false);
            compare(controller.request.terminal, null);
            compare(vehicle.usvSafetyLocked, false);
        }
        function test_progressStillRequiresNewTelemetryAndTerminal() {
            controller.send(31010);
            payload.payloadEventReceived(event(2, "progress", "", {state: "running"}));
            compare(controller.busy, false);
            compare(controller.request.observed, false);
            compare(controller.request.terminal, null);
            payload.clock = controller.request.deadline + 1;
            wait(350);
            // Ending the send wait must not invent an idle vessel or a lock.
            compare(controller.request.unknown, false);
            compare(controller.request.unacknowledged, undefined);
            compare(vehicle.usvSafetyLocked, false);
        }
        function test_invalidProgressCannotProveExecution() {
            controller.send(31010);
            operations.payloadStatus = Status.StatusSampling;
            payload.receive("status");
            payload.payloadEventReceived(event(2, "progress", "running", {state: "running"}));
            compare(controller.busy, true);
            compare(controller.request.seq, 0);
            compare(controller.request.executing, false);
        }
        function test_sampleFailureRemainsVisibleAfterPause() {
            const sampling = startSample();
            pauseSample();
            payload.payloadEventReceived(Object.assign({}, sampling, {
                seq: 3, phase: "terminal", outcome: "failed", reason: "spectrometer_saturated",
                preflight_phase: "injection", cleanup_failed: true
            }));
            compare(vehicle.usvSafetyLocked, true);
            compare(controller.warning, true);
            verify(controller.feedback.indexOf("spectrometer_saturated") >= 0);
            compare(controller.activeTask.terminal.cleanup_failed, true);
            payload.payloadEventReceived(event(2, "request", "accepted"));
            vehicle.mavCommandResult(1, 191, 31012, 0, 0);
            verify(controller.feedback.indexOf("spectrometer_saturated") >= 0);
            compare(controller.allowed(31013), false);
            compare(controller.allowed(31011), true);
        }
        function test_resumeDoesNotRetireSampleBeforeDisconnect() {
            const sampling = startSample();
            pauseSample();
            controller.send(31013);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            operations.payloadStatus = Status.StatusSampling;
            payload.receive("status");
            compare(controller.busy, false);
            operations.connected = false;
            compare(vehicle.usvSafetyLocked, true);
            const original = controller.history.find(record => record.request === sampling.request);
            verify(!!original);
            compare(original.unknown, true);
            compare(controller.activeTask, null);
        }
        function test_calibrationObservedThenDisconnectLocksVehicle() {
            controller.send(31014);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            operations.payloadStatus = Status.StatusCalibrating;
            payload.receive("status");
            compare(controller.busy, false);
            operations.connected = false;
            compare(vehicle.usvSafetyLocked, true);
            compare(controller.history[0].unknown, true);
        }
        function test_reconnectKeepsLateTaskFailureVisibleWithoutReplaying() {
            const sampling = startSample();
            pauseSample();
            const sent = vehicle.sent.length;
            operations.connected = false;
            operations.connected = true;
            payload.payloadEventReceived(Object.assign({}, sampling, {
                seq: 3, phase: "terminal", outcome: "failed", reason: "late_cleanup_failure", cleanup_failed: true
            }));
            compare(vehicle.sent.length, sent);
            compare(vehicle.usvSafetyLocked, true);
            verify(controller.feedback.indexOf("late_cleanup_failure") >= 0);
            compare(controller.activeTask.terminal.cleanup_failed, true);
        }
        function test_knownFailureStaysVisibleForItsVehicleUntilVerified() {
            const sampling = startSample();
            pauseSample();
            payload.payloadEventReceived(Object.assign({}, sampling, {
                seq: 3, phase: "terminal", outcome: "failed", reason: "retained_first_failure", cleanup_failed: true
            }));
            operations.connected = false;
            verify(controller.feedback.indexOf("retained_first_failure") >= 0);
            const other = createTemporaryObject(vehicleComponent, root, {id: 2});
            operations.vehicle = other;
            verify(controller.feedback.indexOf("retained_first_failure") < 0);
            operations.vehicle = vehicle;
            verify(controller.feedback.indexOf("retained_first_failure") >= 0);
            controller.confirmPhysicalStop(vehicle);
            // The failure is acknowledged, not erased: the receipt says both.
            verify(controller.feedback.indexOf("retained_first_failure") >= 0);
            verify(controller.feedback.indexOf(qsTr("本次停止已核验")) >= 0);
        }
        function test_verifiedPhysicalStopRetiresDisconnectedTask() {
            const sampling = startSample();
            operations.connected = false;
            controller.confirmPhysicalStop(vehicle);
            vehicle.usvSafetyLocked = false;
            operations.connected = true;
            payload.payloadEventReceived(Object.assign({}, sampling, {
                seq: 3, phase: "terminal", outcome: "failed", reason: "late_verified_failure", cleanup_failed: true
            }));
            compare(vehicle.usvSafetyLocked, false);
            compare(controller.activeTask, null);
            compare(controller.history[0].physicalStopVerified, true);
        }
        function test_switchVehicleIsolatesOldTaskEvents() {
            const sampling = startSample();
            pauseSample();
            const other = createTemporaryObject(vehicleComponent, root, {id: 2});
            const otherPayload = createTemporaryObject(payloadComponent, root);
            operations.payload = otherPayload;
            operations.vehicle = other;
            compare(vehicle.usvSafetyLocked, true);
            compare(other.usvSafetyLocked, false);
            controller.observeEvent(Object.assign({}, sampling, {
                seq: 4, phase: "terminal", outcome: "failed", reason: "old_vehicle_failure", cleanup_failed: true
            }));
            compare(other.usvSafetyLocked, false);
            verify(controller.feedback.indexOf("old_vehicle_failure") < 0);
        }
        function test_attemptBindingAndFirstTerminalAreRetained() {
            startSample();
            payload.payloadEventReceived(event(2, "progress", "", {state: "running"}));
            payload.payloadEventReceived(event(3, "terminal", "failed", {reason: "wrong_attempt", attempt_id: "22222222222222222222222222222222"}));
            compare(controller.request.terminal, null);
            payload.payloadEventReceived(event(4, "terminal", "failed", {reason: "first_failure", cleanup_failed: true}));
            payload.payloadEventReceived(event(5, "terminal", "succeeded", {reason: "late_success"}));
            compare(controller.request.terminal.reason, "first_failure");
            compare(controller.request.terminal.cleanup_failed, true);
        }
        function test_oldTerminalCannotStopOrFailNewAttempt() {
            const old = startSample();
            payload.payloadEventReceived(event(2, "terminal", "cancelled", {reason: "operator_stop"}));
            operations.payloadStatus = Status.StatusIdle;
            payload.receive("status");
            controller.send(31010);
            const current = controller.request.request;
            verify(current !== old.request);
            payload.payloadEventReceived(Object.assign({}, old, {seq: 5, phase: "terminal", outcome: "failed", cleanup_failed: true}));
            compare(controller.request.request, current);
            compare(controller.request.terminal, null);
            compare(vehicle.usvSafetyLocked, false);
        }
        function test_sameValueTelemetryBeforeAck() {
            controller.send(31018);
            controller.observeTelemetry();
            compare(controller.request.observed, false);
            payload.receive("spectrometerValid");
            compare(controller.request.observed, false);
            payload.receive("voltage");
            compare(controller.request.observed, true);
            compare(controller.allowed(31017), true);
            compare(controller.request.accepted, false);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            compare(controller.busy, false);
            compare(controller.request.terminal, null);
        }
        function test_standardAckCannotCompleteOrRejectRequest() {
            controller.send(31010);
            for (const ack of [0, 0, 5, 2])
                vehicle.mavCommandResult(1, 191, 31010, ack, 0);
            compare(controller.busy, true);
            compare(controller.request.accepted, false);
            payload.payloadEventReceived(event(2, "terminal", "failed", {reason: "spectrometer_stale"}));
            payload.payloadEventReceived(event(3, "request", "accepted"));
            vehicle.mavCommandResult(1, 191, 31010, 0, 0);
            compare(controller.request.terminal.reason, "spectrometer_stale");
            // A failed run whose outputs were confirmed stopped is history, not
            // a vessel lock; the operator can prepare again.
            compare(vehicle.usvSafetyLocked, false);
        }
        function test_wrongIdentityAndDuplicateEvent() {
            controller.send(31010);
            payload.payloadEventReceived(event(1, "request", "accepted", {session: 9}));
            payload.payloadEventReceived(event(1, "request", "accepted", {sender_component: 1}));
            compare(controller.request.seq, 0);
            payload.payloadEventReceived(event(2, "request", "accepted"));
            payload.payloadEventReceived(event(2, "request", "failed"));
            compare(controller.request.accepted, true);
            compare(controller.request.seq, 2);
        }
        function test_stopAcceptanceSettlesTheCommandButKeepsStateEvidence() {
            controller.send(31019);
            payload.receive("spectrometerValid");
            payload.receive("adsState");
            payload.payloadEventReceived(event(1, "request", "accepted"));
            // A correlated accept is the backend's stop result; the ADS state
            // is separate evidence and is still tracked.
            compare(controller.busy, false);
            verify(controller.feedback.indexOf(qsTr("已接受")) >= 0);
            compare(vehicle.usvSafetyLocked, false);
            payload.adsState = {rawValue: 1};
            payload.receive("adsState");
            compare(controller.request.observed, true);
            compare(controller.request.terminal, null);
        }
        function test_unknownProtocolAndPendingStop() {
            payload.protocolVersion = {rawValue: 0};
            compare(controller.allowed(31010), false);
            compare(controller.allowed(31011), true);
            payload.protocolVersion = {rawValue: 1};
            vehicle.pending = [31019];
            controller.transportTick++;
            compare(controller.allowed(31010), false);
        }
        function test_progressRenewsTheExecutionWindowWithinOneRun() {
            controller.send(31010);
            const receiptDeadline = controller.request.deadline;
            payload.payloadEventReceived(event(1, "request", "accepted"));
            compare(controller.busy, false, "an accepted request answers the send window");
            payload.payloadEventReceived(event(2, "progress", "", {state: "running"}));
            compare(controller.request.executing, true);
            // Past the original receipt deadline nothing reopens and nothing
            // locks: the task is executing, and its silence is not a fault.
            payload.clock = receiptDeadline + 1;
            controller.expire();
            compare(controller.request.unknown, false);
            compare(vehicle.usvSafetyLocked, false);
            compare(controller.request.terminal, null);
        }
        function test_disconnectRetainsUnknownHistoryAndLocksOldVehicle() {
            controller.send(31010);
            operations.connected = false;
            compare(controller.request, null);
            compare(controller.history.length, 1);
            compare(controller.history[0].unknown, true);
            compare(vehicle.usvSafetyLocked, true);
            const other = createTemporaryObject(vehicleComponent, root);
            operations.vehicle = other;
            operations.connected = true;
            compare(other.sent.length, 0);
        }
        function test_surveyKeepsEachAttemptTerminal() {
            controller.send(31015);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            payload.payloadEventReceived(event(2, "terminal", "succeeded"));
            payload.payloadEventReceived(event(3, "progress", "", {state: "running", attempt_id: "22222222222222222222222222222222"}));
            payload.payloadEventReceived(event(4, "terminal", "failed", {attempt_id: "22222222222222222222222222222222", reason: "spectrometer_stale"}));
            compare(controller.request.seq, 4);
            compare(controller.request.terminal.reason, "spectrometer_stale");
            compare(controller.request.stages.filter(e => e.phase === "terminal").length, 2);
        }
        function test_startSignalAckWithoutDataIsNotAnUnknownCommand() {
            controller.send(31018);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            compare(controller.busy, false);
            verify(controller.feedback.indexOf(qsTr("启动已确认，等待有效数据")) >= 0);
            compare(vehicle.usvSafetyLocked, false);
            // A detector that never delivers a frame is a measurement problem,
            // not a missing command answer.
            payload.clock = controller.request.deadline + 1;
            controller.expire();
            compare(controller.request.unknown, false);
            compare(vehicle.usvSafetyLocked, false);
            // The real frame still decides whether new data arrived.
            compare(controller.request.observed, false);
            payload.receive("spectrometerValid");
            compare(controller.request.observed, false);
            payload.receive("voltage");
            compare(controller.request.observed, true);
        }
        function test_currentFaultBlocksMotionButKeepsRecoveryReachable() {
            operations.payloadStatus = Status.StatusFault;
            operations.payloadFault = true;
            payload.receive("status");
            // Recovery commands must stay reachable in Fault/Aborted.
            compare(controller.allowed(31019), true);
            compare(controller.allowed(31018), true);
            compare(controller.allowed(31017), true);
            // Motion still needs a recovered device.
            compare(controller.allowed(31010), false);
            compare(controller.allowed(31015), false);
            // Stops are never blocked by the lock or by a stale protocol.
            vehicle.usvSafetyLocked = true;
            controller.safetyLocked = true;
            compare(controller.allowed(31011), true);
            compare(controller.allowed(31019), true);
        }
        function test_verifiedStopRetiresALateTerminal() {
            controller.send(31010);
            const unknownTask = Object.assign({}, controller.request);
            operations.connected = false;
            controller.confirmPhysicalStop(vehicle);
            vehicle.usvSafetyLocked = false;
            operations.connected = true;
            payload.payloadEventReceived(Object.assign({}, unknownTask, {
                seq: 9, phase: "terminal", outcome: "failed", reason: "very_late_failure", cleanup_failed: true
            }));
            // A retired request keeps its history but cannot re-lock the vessel.
            compare(vehicle.usvSafetyLocked, false);
            compare(controller.activeTask, null);
            const record = controller.history.find(r => r.request === unknownTask.request);
            verify(!!record);
            compare(record.retired, true);
            compare(record.physicalStopVerified, true);
        }
        function test_twoStopsKeepTheirOwnResults() {
            controller.send(31011);
            const first = Object.assign({}, controller.request);
            controller.send(31019);
            const second = Object.assign({}, controller.request);
            verify(first.request !== second.request);
            payload.payloadEventReceived(Object.assign({}, first, {
                seq: 2, phase: "terminal", outcome: "cancelled", reason: "operator_stop"
            }));
            // The newest request is not replaced by another stop's result.
            compare(controller.request.request, second.request);
            const record = controller.history.find(r => r.request === first.request);
            verify(!!record);
            compare(record.terminal.reason, "operator_stop");
            compare(controller.busy, true);
        }
        function test_recoveredDeviceAllowsANewSampleCycle() {
            operations.payloadStatus = Status.StatusFault;
            operations.payloadFault = true;
            payload.receive("status");
            controller.send(31010);
            compare(controller.request, null, "motion must stay blocked while the payload reports a fault");
            // After verify + backend recovery the same command becomes available.
            vehicle.usvSafetyLocked = false;
            controller.safetyLocked = false;
            operations.payloadStatus = Status.StatusIdle;
            operations.payloadFault = false;
            payload.receive("status");
            compare(controller.allowed(31010), true);
        }
        function test_acceptedJustBeforeTheReceiptDeadlineNeedsNoSecondSend() {
            controller.send(31015);
            // 4.9 s: the accept lands inside the 5 s receipt window.
            payload.clock = controller.request.deadline - 100;
            payload.payloadEventReceived(event(1, "request", "accepted"));
            compare(controller.busy, false);
            compare(vehicle.usvSafetyLocked, false);
            verify(controller.feedback.indexOf(qsTr("已接受")) >= 0);
            // 5.4 s: the new survey state is simply late; it must not lock nor
            // be reported as an unanswered command.
            payload.clock = controller.request.deadline + 400;
            operations.payloadStatus = Status.StatusSurveying;
            payload.receive("status");
            compare(vehicle.usvSafetyLocked, false);
            compare(controller.activeTask.observed, true);
            verify(controller.feedback.indexOf(qsTr("未收到回执")) < 0);
            compare(vehicle.sent.length, 1, "no automatic START may be re-sent");
        }
        function test_unansweredReceiptKeepsTheTaskButNotTheVessel() {
            controller.send(31010);
            const sent = vehicle.sent.length;
            payload.clock = controller.request.deadline + 1;
            controller.expire();
            compare(controller.busy, false);
            compare(controller.request.unacknowledged, true);
            verify(controller.feedback.indexOf(qsTr("未收到回执")) >= 0);
            compare(vehicle.usvSafetyLocked, false);
            // A pre-send Idle is not proof that the task did not start, so a
            // second physical start is still refused...
            compare(controller.allowed(31010), false);
            verify(controller.blockedReason(31010).length > 0);
            compare(vehicle.sent.length, sent, "no automatic START may be re-sent");
            // ...until ROS publishes a new state that says the payload is idle.
            operations.payloadStatus = Status.StatusIdle;
            payload.receive("status");
            compare(controller.activeTask, null);
            compare(controller.allowed(31010), true);
            compare(vehicle.usvSafetyLocked, false);
        }
        function test_standardAckSettlesACompatibleStopWithoutAnIdentity() {
            payload.protocolVersion = {rawValue: 0};
            controller.send(31019);
            compare(controller.busy, true);
            compare(controller.request.session, undefined);
            vehicle.mavCommandResult(1, 191, 31019, 0, 0);
            compare(controller.busy, false);
            compare(vehicle.usvSafetyLocked, false);
            verify(controller.feedback.indexOf(qsTr("已接受")) >= 0);
            // A late correlated terminal for another request cannot overwrite
            // this answer.
            payload.payloadEventReceived(event(9, "terminal", "failed", {reason: "late_other"}));
            compare(controller.request.terminal, null);
        }
        function test_stopSurveyThenStopSpectrometerBothFinishWithoutALeftoverGate() {
            controller.send(31015);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            operations.payloadStatus = Status.StatusSurveying;
            payload.receive("status");
            const surveyTask = controller.activeTask;
            verify(!!surveyTask);
            // Survey is waiting between rounds; the operator stops it and then
            // stops the detector straight away.
            controller.send(31016);
            const surveyStop = Object.assign({}, controller.request);
            payload.payloadEventReceived(Object.assign({}, surveyStop, {seq: 2, phase: "request", outcome: "accepted"}));
            compare(controller.busy, false);
            compare(controller.allowed(31019), true);
            controller.send(31019);
            const detectorStop = Object.assign({}, controller.request);
            payload.payloadEventReceived(Object.assign({}, detectorStop, {seq: 2, phase: "request", outcome: "accepted"}));
            compare(controller.busy, false);
            // ROS then publishes the stopped state for both scopes.
            operations.payloadStatus = Status.StatusIdle;
            payload.adsState = {rawValue: 1};
            payload.receive("status");
            payload.receive("adsState");
            compare(vehicle.usvSafetyLocked, false);
            compare(controller.allowed(31010), true, "no leftover survey gate may survive");
            const surveyRecord = controller.history.find(record => record.command === 31015);
            verify(!!surveyRecord);
            compare(surveyRecord.retired, true);
        }
        function test_ordinaryFailureRecoversFromCurrentStateAlone() {
            controller.send(31010);
            payload.payloadEventReceived(event(1, "request", "accepted"));
            operations.payloadStatus = Status.StatusSampling;
            payload.receive("status");
            payload.payloadEventReceived(event(2, "terminal", "failed",
                                             {reason: "spectrometer_stale", preflight_phase: "injecting"}));
            // Outputs were confirmed stopped, so this is history, not a lock.
            compare(vehicle.usvSafetyLocked, false);
            verify(controller.feedback.indexOf("spectrometer_stale") >= 0);
            // The stop confirmation arrives as the current device state.
            operations.payloadStatus = Status.StatusIdle;
            payload.receive("status");
            compare(controller.activeTask, null);
            compare(controller.allowed(31018), true, "the detector may be started again");
            verify(controller.feedback.indexOf("spectrometer_stale") >= 0);
        }
        function test_disabledControlsNameTheMissingCondition() {
            compare(controller.blockedReason(31010), "");
            operations.baselineSet = false;
            compare(controller.allowed(31010), false);
            verify(controller.blockedReason(31010).length > 0);
            compare(controller.helpTextFor(31010, "fallback"), controller.blockedReason(31010));
            // An allowed command keeps the caller's own help text.
            operations.baselineSet = true;
            compare(controller.helpTextFor(31010, "fallback"), "fallback");
            // The safety exit explains its own state instead of disappearing.
            vehicle.pending = [31019];
            controller.transportTick++;
            compare(controller.allowed(31019), false);
            verify(controller.blockedReason(31019).length > 0);
        }
    }
}

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
            return Object.assign({}, controller.request, {seq: seq, phase: phase, outcome: outcome,
                reason: "", attempt_id: "11111111111111111111111111111111", preflight_phase: ""}, extra || {});
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
            compare(vehicle.usvSafetyLocked, true);
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
        function test_stopRequiresExplicitStoppedState() {
            controller.send(31019);
            payload.receive("spectrometerValid");
            payload.receive("adsState");
            payload.payloadEventReceived(event(1, "request", "accepted"));
            compare(controller.busy, true);
            payload.adsState = {rawValue: 1};
            payload.receive("adsState");
            compare(controller.busy, false);
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
        function test_absoluteTimeoutNotExtendedByProgress() {
            controller.send(31010);
            const deadline = controller.request.deadline;
            payload.payloadEventReceived(event(1, "progress", "running"));
            payload.payloadEventReceived(event(2, "request", "accepted"));
            compare(controller.request.deadline, deadline);
            payload.clock = deadline + 1;
            tryCompare(controller, "busy", false, 1500);
            compare(controller.request.unknown, true);
            compare(vehicle.usvSafetyLocked, true);
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
            payload.payloadEventReceived(event(3, "progress", "running", {attempt_id: "22222222222222222222222222222222"}));
            payload.payloadEventReceived(event(4, "terminal", "failed", {attempt_id: "22222222222222222222222222222222", reason: "spectrometer_stale"}));
            compare(controller.request.seq, 4);
            compare(controller.request.terminal.reason, "spectrometer_stale");
            compare(controller.request.stages.filter(e => e.phase === "terminal").length, 2);
        }
    }
}

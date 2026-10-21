import QtQuick

Item {
    property bool armed: true
    property QtObject batteries: QtObject {
        property QtObject battery: QtObject {
            property var percentRemaining: ({
                    rawValue: 78
                })
        }
        property int count: 1

        function get(index) {
            return battery;
        }
    }
    property int commandCalls: 0
    property int defaultComponentId: 1
    property bool usvSafetyLocked: false
    property string usvSafetyLockSource: ""
    property string retainedSafetySource: ""
    onUsvSafetyLockSourceChanged: {
        if (usvSafetyLockSource && (retainedSafetySource === "emergency"
                || usvSafetyLockSource === "communication" && retainedSafetySource))
            usvSafetyLockSource = retainedSafetySource;
        retainedSafetySource = usvSafetyLockSource;
        usvSafetyLocked = usvSafetyLockSource.length > 0;
    }
    onUsvSafetyLockedChanged: {
        if (!usvSafetyLocked) usvSafetyLockSource = "";
        else if (!usvSafetyLockSource) usvSafetyLockSource = "emergency";
    }
    property var distanceToHome: ({
            rawValue: 86
        })
    property int emergencyCalls: 0
    property var factGroupNames: ["usvPayload"]
    property string flightMode: "Auto"
    property bool flightModeSetAvailable: true
    property QtObject gps: QtObject {
        property var courseOverGround: ({rawValue: 182})
        property var count: ({
                rawValue: 18
            })
        property var hdop: ({
                rawValue: 0.8
            })
        property var lock: ({
                rawValue: 3
            })
    }
    property var groundSpeed: ({
            rawValue: 1.2
        })
    property var heading: ({
            rawValue: 182
        })
    property var headingToHome: ({rawValue: 30})
    property var headingToNextWP: ({rawValue: 145})
    property int id: 1
    property int lastCommand: 0
    property var pendingCommands: []
    readonly property var pendingMavCommands: pendingCommands.map(entry => entry.component + ":" + entry.command)
    function isMavCommandPending(component, command) {
        return pendingCommands.some(entry => entry.component === component && entry.command === command);
    }
    property int lastComponent: 0
    property string missionFlightMode: "Auto"
    property int pauseCalls: 0
    property string pauseFlightMode: "Hold"
    property bool pauseVehicleSupported: true
    property QtObject payload: QtObject {
        property var protocolVersion: ({rawValue: 1})
        property var adsState: ({rawValue: 3})
        property var sequences: ({})
        property int nextRequest: 0
        signal freshnessChanged()
        signal payloadEventReceived(var event)
        property double clock: 1000
        function monotonicMs() { return clock; }
        function fieldSequence(field) { return sequences[field] || 0; }
        function receive(field) { sequences[field] = fieldSequence(field) + 1; freshnessChanged(); }
        function allocateRequest() { return {session: 1, request: ++nextRequest, sender_system: 255, sender_component: 190}; }
        onStatusChanged: receive("status")
        onAdsStateChanged: receive("adsState")
        onSpectrometerValidChanged: receive("spectrometerValid")
        onVoltageChanged: receive("voltage")
        onBaselineSetChanged: receive("baselineSet")
        property var freshFields: ["protocolVersion", "adsState", "voltage", "absorbance", "pumpX", "pumpY", "pumpZ", "pumpA", "status", "packetCount", "stepCurrent", "stepTotal", "loopCurrent", "loopTotal", "sampleCount", "pidError", "pidMode", "baselineSet", "referenceVoltage", "baselineVoltage", "spectrometerValid", "jetsonTemp", "detectorTemp", "jetsonCpu", "jetsonMemory", "detectorHeap"]
        property double telemetryAgeMs: 0
        property var absorbance: ({
                rawValue: 0.1157
            })
        property var baselineSet: ({
                rawValue: 1
            })
        property var baselineVoltage: ({
                rawValue: 1.078
            })
        property var detectorHeap: ({
                rawValue: 68
            })
        property var detectorTemp: ({
                rawValue: 36
            })
        property var jetsonCpu: ({
                rawValue: 24
            })
        property var jetsonMemory: ({
                rawValue: 42
            })
        property var jetsonTemp: ({
                rawValue: 48
            })
        property int lastCompid: 191
        property int lastSysid: 1
        property real latencyMs: 1000
        property var linkActive: ({
                rawValue: 1
            })
        property var loopCurrent: ({
                rawValue: 2
            })
        property var loopTotal: ({
                rawValue: 5
            })
        property var packetCount: ({
                rawValue: 1250
            })
        property var pidError: ({
                rawValue: 0.1
            })
        property var pidMode: ({
                rawValue: 1
            })
        property var pumpA: ({
                rawValue: 146.2
            })
        property var pumpX: ({
                rawValue: 0
            })
        property var pumpY: ({
                rawValue: 245.3
            })
        property var pumpZ: ({
                rawValue: 61
            })
        property var referenceVoltage: ({
                rawValue: 1.407
            })
        property int rxHeartbeat: 224
        property int rxMsgTotal: 16824
        property int rxNamedValue: 4860
        property var sampleCount: ({
                rawValue: 12
            })
        property var spectrometerValid: ({
                rawValue: 1
            })
        property var status: ({
                rawValue: 1
            })
        property var stepCurrent: ({
                rawValue: 3
            })
        property var stepTotal: ({
                rawValue: 8
            })
        property var voltage: ({
                rawValue: 1.078
            })
    }
    property var pitch: ({
            rawValue: 0.4
        })
    property var roll: ({
            rawValue: 1.0
        })
    property string stabilizedFlightMode: "Manual"
    property QtObject vehicleLinkManager: QtObject {
        property bool communicationLost: false
        property string primaryLinkName: "USV telemetry (mock)"
    }

    signal mavCommandResult(int vehicleId, int targetComponent, int command, int ackResult, int failureCode)
    onMavCommandResult: (vehicleId, targetComponent, command, ackResult, failureCode) => {
        if (vehicleId === id && ackResult !== 5)
            pendingCommands = pendingCommands.filter(entry => entry.component !== targetComponent || entry.command !== command);
    }

    function emergencyStop() {
        emergencyCalls++;
    }
    function getFactGroup(name) {
        return payload;
    }
    function pauseVehicle() {
        pauseCalls++;
    }
    function sendCommand(component, command, errors, param1, param2, param3, param4) {
        lastComponent = component;
        lastCommand = command;
        commandCalls++;
        pendingCommands = pendingCommands.concat([{component: component, command: command}]);
    }
}

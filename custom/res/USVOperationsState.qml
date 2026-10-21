import QtQuick

import QGroundControl
import QGroundControl.Controls

import "USVFlyViewLayout.js" as USVLayout

QtObject {
    id: root

    readonly property string alertText: vehicle && !connected ? qsTr("飞控连接中断，请检查通信链路") : attitudeCritical ? qsTr("船体姿态异常，请立即检查") : payloadFault ? qsTr("采样任务异常，请检查载荷；任务未确认完成") : connected && hasPayload && !payloadOnline ? qsTr("载荷遥测中断，请检查船载链路") : lowBattery ? qsTr("电池电量低，请安排返航") : ""
    readonly property bool attitudeCritical: Math.abs(roll) > 25 || Math.abs(pitch) > 20
    readonly property bool autoMode: connected && vehicle.flightMode === vehicle.missionFlightMode
    readonly property bool baselineSet: fresh("baselineSet") && factNumber(payload ? payload.baselineSet : null, 0) === 1
    readonly property var battery: vehicle && vehicle.batteries && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    readonly property real batteryPercent: connected ? factNumber(battery ? battery.percentRemaining : null, -1) : -1
    readonly property string batteryText: batteryPercent >= 0 ? Math.round(batteryPercent) + "%" : qsTr("未知")
    readonly property string batteryVoltageText: metric(battery ? battery.voltage : null, 1, " V", connected)
    readonly property bool connected: !!vehicle && !!vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
    readonly property var gps: vehicle ? vehicle.gps : null
    readonly property int gpsLock: connected ? factNumber(gps ? gps.lock : null, 0) : 0
    readonly property bool gpsReady: gpsLock >= 3
    readonly property string gpsCountText: metric(gps ? gps.count : null, 0, "", connected)
    readonly property string gpsText: !connected ? qsTr("未连接") : gpsReady ? (gpsLock === 6 ? qsTr("RTK 固定") : gpsLock === 5 ? qsTr("RTK 浮点") : qsTr("已定位")) : qsTr("未定位")
    property var guidedController: null
    readonly property bool hasMission: connected && !!missionController && missionController.containsItems
    readonly property bool hasPayload: !!vehicle && !!vehicle.factGroupNames && vehicle.factGroupNames.indexOf("usvPayload") >= 0
    readonly property bool holdMode: connected && vehicle.flightMode === vehicle.pauseFlightMode
    readonly property bool lowBattery: batteryPercent >= 0 && batteryPercent <= 20
    property var missionController: null
    readonly property int missionCount: hasMission ? Math.max(0, missionController.missionItemCount - 1) : 0
    readonly property int missionIndex: hasMission ? Math.max(0, missionController.currentMissionIndex) : 0
    // MISSION_CURRENT is an item cursor, not proof that sampling has completed.
    readonly property real missionPosition: USVLayout.missionPosition(missionIndex, missionCount)
    readonly property var payload: hasPayload ? vehicle.getFactGroup("usvPayload") : null
    readonly property bool payloadFault: payloadOnline && (payloadStatus === USVLayout.StatusFault || payloadStatus === USVLayout.StatusAborted)
    readonly property bool payloadOnline: connected && factNumber(payload ? payload.linkActive : null, 0) === 1
    readonly property int payloadStatus: fresh("status") ? factNumber(payload ? payload.status : null, -1) : -1
    readonly property bool payloadWorking: payloadOnline && USVLayout.payloadState(true, payloadStatus, true, false).showQuickActions && !payloadFault
    readonly property real pitch: connected ? factNumber(vehicle ? vehicle.pitch : null, 0) : 0
    readonly property real roll: connected ? factNumber(vehicle ? vehicle.roll : null, 0) : 0
    readonly property string samplingText: !vehicle ? qsTr("等待连接") : !hasPayload ? qsTr("载荷不可用") : !payloadOnline ? qsTr("载荷离线") : payloadStatus < 0 ? qsTr("阶段待更新") : USVLayout.statusText(payloadStatus)
    readonly property bool taskExecuting: autoMode && hasMission && vehicle.armed
    readonly property string taskText: !connected ? qsTr("未连接") : !hasMission ? qsTr("未载入任务") : !vehicle.armed ? qsTr("待解锁") : taskExecuting ? qsTr("自动执行") : holdMode ? qsTr("保持中") : qsTr("待执行")
    readonly property bool validSignal: fresh("spectrometerValid") && factNumber(payload ? payload.spectrometerValid : null, 0) === 1 && fresh("voltage")
    property var vehicle: null
    readonly property bool pumpFeedbackValid: fresh("pumpX") && fresh("pumpY") && fresh("pumpZ") && fresh("pumpA")
    readonly property string voltageText: payloadMetric("voltage", 3, "", validSignal)
    readonly property string absorbanceText: payloadMetric("absorbance", 4, "", validSignal && baselineSet)
    readonly property string stepText: pairText("stepCurrent", "stepTotal", false)
    readonly property string loopText: pairText("loopCurrent", "loopTotal", true)
    readonly property string sampleCountText: payloadMetric("sampleCount", 0, "")
    readonly property string waypointText: hasMission ? qsTr("%1 / %2").arg(missionIndex.toString().padStart(2, "0")).arg(missionCount.toString().padStart(2, "0")) : "—"
    readonly property string modeText: connected ? vehicle.flightMode : "—"
    readonly property string vehicleText: vehicle ? qsTr("无人船 %1").arg(vehicle.id.toString().padStart(2, "0")) : qsTr("等待无人船")
    readonly property string telemetryText: !payloadOnline ? qsTr("遥测离线") : !payload || payload.telemetryAgeMs < 0 ? qsTr("等待更新") : payload.telemetryAgeMs < 1000 ? qsTr("刚刚更新") : qsTr("%1 秒前更新").arg(Math.floor(payload.telemetryAgeMs / 1000))
    readonly property int phaseIndex: !payloadOnline ? -1 : payloadStatus === USVLayout.StatusNavigating ? 0 : payloadStatus === USVLayout.StatusWaypointReached || payloadStatus === USVLayout.StatusHolding || payloadStatus === USVLayout.StatusWaitingStable ? 1 : payloadStatus === USVLayout.StatusSampling || payloadStatus === USVLayout.StatusDetecting || payloadStatus === USVLayout.StatusPaused ? 2 : payloadStatus === USVLayout.StatusSamplingDone ? 3 : payloadStatus === USVLayout.StatusResumingAuto ? 4 : -1
    property var observedStages: []

    readonly property Connections phaseObserver: Connections {
        target: root
        function onVehicleChanged() { root.observedStages = []; }
        function onMissionIndexChanged() { root.observedStages = []; root.observePhase(); }
        function onPayloadOnlineChanged() { if (!root.payloadOnline) root.observedStages = []; }
        function onPhaseIndexChanged() { root.observePhase(); }
    }

    function observePhase() {
        if (phaseIndex >= 0 && observedStages.indexOf(phaseIndex) < 0)
            observedStages = observedStages.concat([phaseIndex]);
    }
    function fresh(name) {
        return payloadOnline && !!payload && !!payload.freshFields && payload.freshFields.indexOf(name) >= 0;
    }
    function pairText(currentName, totalName, unlimited) {
        if (!fresh(currentName) || !fresh(totalName))
            return "—";
        const current = factNumber(payload[currentName], NaN);
        const total = factNumber(payload[totalName], NaN);
        if (!isFinite(current) || !isFinite(total) || current < 0 || total < 0)
            return "—";
        if (!unlimited && total === 0)
            return qsTr("无步骤");
        return qsTr("%1 / %2").arg(Math.round(current)).arg(total === 0 && unlimited ? qsTr("不限") : Math.round(total));
    }

    function factNumber(fact, fallback) {
        if (!fact || fact.rawValue === undefined || fact.rawValue === null)
            return fallback;
        const value = Number(fact.rawValue);
        return isFinite(value) ? value : fallback;
    }
    function metric(fact, digits, suffix, available) {
        const value = factNumber(fact, NaN);
        return available && isFinite(value) ? value.toFixed(digits) + (suffix || "") : "—";
    }
    function panelWidth(viewportWidth, fontWidth) {
        return USVLayout.operationsPanelWidth(viewportWidth, fontWidth);
    }
    function workflowDock(viewportWidth, viewportHeight, fontWidth, insets) {
        return USVLayout.workflowDock(viewportWidth, viewportHeight, fontWidth, insets);
    }
    function payloadMetric(name, digits, suffix, available) {
        if (name.indexOf("pump") === 0 && payload && fresh(name) && factNumber(payload[name], -1) < 0)
            return qsTr("未校准");
        return metric(payload ? payload[name] : null, digits, suffix, fresh(name) && available !== false);
    }
}

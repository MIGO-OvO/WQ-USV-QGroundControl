import QtQuick

import QGroundControl
import QGroundControl.Controls

import "USVFlyViewLayout.js" as USVLayout

QtObject {
    id: root

    readonly property string alertText: vehicle && !connected ? qsTr("飞控连接中断，请检查通信链路") : attitudeCritical ? qsTr("船体姿态异常，请立即检查") : payloadFault ? qsTr("采样任务异常，请检查载荷；任务未确认完成") : connected && hasPayload && !payloadOnline ? qsTr("载荷遥测中断，请检查船载链路") : lowBattery ? qsTr("电池电量低，请安排返航") : ""
    readonly property bool attitudeCritical: Math.abs(roll) > 25 || Math.abs(pitch) > 20
    readonly property bool autoMode: connected && vehicle.flightMode === vehicle.missionFlightMode
    readonly property bool baselineSet: payloadOnline && factNumber(payload ? payload.baselineSet : null, 0) === 1
    readonly property var battery: vehicle && vehicle.batteries && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    readonly property real batteryPercent: connected ? factNumber(battery ? battery.percentRemaining : null, -1) : -1
    readonly property string batteryText: batteryPercent >= 0 ? Math.round(batteryPercent) + "%" : qsTr("未知")
    readonly property bool connected: !!vehicle && !!vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
    readonly property var gps: vehicle ? vehicle.gps : null
    readonly property int gpsLock: connected ? factNumber(gps ? gps.lock : null, 0) : 0
    readonly property bool gpsReady: gpsLock >= 3
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
    readonly property int payloadStatus: factNumber(payload ? payload.status : null, USVLayout.StatusIdle)
    readonly property bool payloadWorking: payloadOnline && USVLayout.payloadState(true, payloadStatus, true, false).showQuickActions && !payloadFault
    readonly property real pitch: connected ? factNumber(vehicle ? vehicle.pitch : null, 0) : 0
    readonly property real roll: connected ? factNumber(vehicle ? vehicle.roll : null, 0) : 0
    readonly property string samplingText: !vehicle ? qsTr("等待连接") : !hasPayload ? qsTr("载荷不可用") : !payloadOnline ? qsTr("载荷离线") : USVLayout.statusText(payloadStatus)
    readonly property bool taskExecuting: autoMode && hasMission && vehicle.armed
    readonly property string taskText: !connected ? qsTr("未连接") : !hasMission ? qsTr("未载入任务") : !vehicle.armed ? qsTr("待解锁") : taskExecuting ? qsTr("自动执行") : holdMode ? qsTr("保持中") : qsTr("待执行")
    readonly property bool validSignal: payloadOnline && factNumber(payload ? payload.spectrometerValid : null, 0) === 1
    property var vehicle: null

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
    function payloadMetric(name, digits, suffix) {
        return metric(payload ? payload[name] : null, digits, suffix, payloadOnline);
    }
}

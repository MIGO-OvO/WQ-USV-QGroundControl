import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

RowLayout {
    id: root

    required property var operations
    required property var theme
    readonly property bool compact: width < theme.unit * 150

    spacing: 0

    USVSystemStatusCell {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        theme: root.theme
        compact: root.compact
        separator: false
        title: qsTr("GPS")
        symbol: "gps"
        healthy: root.operations.gpsReady
        stateText: root.operations.gpsText
        detail: qsTr("%1 星 · HDOP %2").arg(root.operations.gpsCountText).arg(root.operations.metric(root.operations.gps ? root.operations.gps.hdop : null, 1, "", root.operations.connected))
    }

    USVSystemStatusCell {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        theme: root.theme
        compact: root.compact
        title: qsTr("通信")
        symbol: "link"
        healthy: root.operations.connected
        stateText: root.operations.connected ? qsTr("MAVLink 在线") : qsTr("飞控离线")
        detail: root.operations.vehicle && root.operations.connected ? root.operations.vehicle.vehicleLinkManager.primaryLinkName : qsTr("等待连接")
    }

    USVSystemStatusCell {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        theme: root.theme
        compact: root.compact
        title: qsTr("ROS")
        symbol: "ros"
        healthy: false
        stateText: root.operations.payloadOnline ? qsTr("节点待核验") : qsTr("载荷遥测离线")
        detail: root.operations.payloadOnline ? qsTr("载荷遥测在线") : qsTr("检查船载链路")
    }

    USVSystemStatusCell {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        theme: root.theme
        compact: root.compact
        title: qsTr("ADS")
        symbol: "signal"
        healthy: root.operations.validSignal
        stateText: root.operations.validSignal ? qsTr("信号有效") : qsTr("无有效信号")
        detail: qsTr("硬件自检未接入")
    }

    USVSystemStatusCell {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        theme: root.theme
        compact: root.compact
        title: qsTr("泵组")
        symbol: "pump"
        healthy: false
        stateText: qsTr("运行待核验")
        detail: root.operations.pumpFeedbackValid ? qsTr("角度遥测有效") : qsTr("角度遥测不可用")
    }

    USVSystemStatusCell {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        theme: root.theme
        compact: root.compact
        title: qsTr("电源")
        symbol: "battery"
        healthy: root.operations.batteryPercent > 20
        stateText: root.operations.batteryPercent >= 0 ? qsTr("%1 · %2").arg(root.operations.batteryText).arg(root.operations.batteryVoltageText) : qsTr("数据不可用")
        detail: root.operations.lowBattery ? qsTr("电量低，请安排返航") : qsTr("飞控电池遥测")
    }
}

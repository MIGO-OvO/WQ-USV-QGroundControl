import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

ColumnLayout {
    id: root

    required property var operations
    required property var theme
    readonly property var payload: operations.payload

    spacing: theme.gap

    QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; text: qsTr("船载与检测装置"); color: root.theme.secondary; font.bold: true }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("Jetson 温度"); value: root.operations.payloadMetric("jetsonTemp", 0, " °C") }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("Jetson CPU"); value: root.operations.payloadMetric("jetsonCpu", 0, "%") }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("Jetson 内存"); value: root.operations.payloadMetric("jetsonMemory", 0, "%") }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("检测装置温度"); value: root.operations.payloadMetric("detectorTemp", 0, " °C") }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("检测装置可用堆"); value: root.operations.payloadMetric("detectorHeap", 0, "%") }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.divider }
    QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; text: qsTr("通信接收统计"); color: root.theme.secondary; font.bold: true }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("接收消息"); value: root.payload ? String(root.payload.rxMsgTotal) : "—" }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("命名遥测"); value: root.payload ? String(root.payload.rxNamedValue) : "—" }
    USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("伴随心跳"); value: root.payload ? String(root.payload.rxHeartbeat) : "—" }
    QGCLabel { Layout.fillWidth: true; color: root.theme.warning; font.pointSize: root.theme.captionPointSize; wrapMode: Text.WordWrap; text: qsTr("节点健康与硬件自检：未接入") }
}

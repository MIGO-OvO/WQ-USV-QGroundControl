import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

ColumnLayout {
    id: root

    required property var operations
    required property var controller
    required property var commands
    required property var theme

    spacing: theme.unit

    QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; text: qsTr("驾驶模式"); color: root.theme.secondary }
    RowLayout {
        Layout.fillWidth: true
        USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("手动驾驶"); checked: root.operations.connected && root.operations.vehicle.flightMode === root.operations.vehicle.stabilizedFlightMode; enabled: root.operations.connected && !root.controller.safetyLocked && !!root.operations.guidedController && root.operations.vehicle.flightModeSetAvailable; onClicked: root.controller.confirmMode(root.operations.vehicle.stabilizedFlightMode) }
        USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("自动任务"); checked: root.operations.autoMode; enabled: root.operations.connected && !root.controller.safetyLocked && root.operations.gpsReady && root.operations.hasMission && root.operations.vehicle.armed && !!root.operations.guidedController && root.operations.vehicle.flightModeSetAvailable; onClicked: root.controller.confirmMode(root.operations.vehicle.missionFlightMode) }
    }
    QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; text: qsTr("检测器与泵组"); color: root.theme.secondary }
    USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("启动信号采集"); symbol: "signal"; enabled: root.commands.allowed(31018); onClicked: root.commands.send(31018, 0) }
    USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("停止信号采集"); symbol: "stop"; enabled: root.commands.allowed(31019); onClicked: root.commands.send(31019, 0) }
    USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("设置当前基线"); symbol: "baseline"; enabled: root.commands.allowed(31017); onClicked: root.commands.send(31017, 0) }
    USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("校准泵组"); symbol: "pump"; enabled: root.commands.allowed(31014); onClicked: root.commands.send(31014, 0) }
    USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("开始走航检测"); symbol: "route"; enabled: root.commands.allowed(31015); onClicked: root.commands.send(31015, 0) }
    USVOperationsButton { Layout.fillWidth: true; theme: root.theme; text: qsTr("停止走航检测"); symbol: "stop"; enabled: root.commands.allowed(31016); onClicked: root.commands.send(31016, 0) }
}

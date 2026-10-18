import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

ColumnLayout {
    id: root

    required property var operations
    required property var controller
    required property var theme

    spacing: theme.unit

    QGCLabel { font.pointSize: root.theme.bodyPointSize; color: root.theme.secondary; text: qsTr("航行任务") }
    GridLayout {
        Layout.fillWidth: true
        columns: width < root.theme.unit * 24 ? 1 : 2
        columnSpacing: root.theme.unit
        rowSpacing: root.theme.unit
        USVOperationsButton { Layout.fillWidth: true; Layout.preferredWidth: 1; theme: root.theme; symbol: "hold"; text: qsTr("保持位置"); enabled: root.operations.connected && !root.controller.safetyLocked && root.operations.vehicle.armed && root.operations.vehicle.pauseVehicleSupported && !root.operations.holdMode; helpText: qsTr("飞控进入保持模式，暂停航行"); onClicked: root.controller.pauseNavigation() }
        USVOperationsButton { Layout.fillWidth: true; Layout.preferredWidth: 1; theme: root.theme; symbol: "home"; text: qsTr("返航"); enabled: root.operations.connected && !root.controller.safetyLocked && root.operations.gpsReady && !!root.operations.guidedController && root.operations.guidedController.showRTL; helpText: qsTr("通过 QGC 确认返回起航位置"); onClicked: root.controller.returnHome() }
    }
    QGCLabel { Layout.fillWidth: true; visible: !root.operations.gpsReady; text: qsTr("GPS 定位有效后可开始航线或返航"); color: root.theme.warning; font.pointSize: root.theme.captionPointSize; wrapMode: Text.WordWrap }
}

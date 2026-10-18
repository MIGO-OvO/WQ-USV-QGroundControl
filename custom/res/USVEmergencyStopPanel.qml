import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

USVCockpitSurface {
    id: root

    required property var operations
    required property var controller
    property bool compact: false

    objectName: "usvEmergencyStopPanel"
    border.color: controller.safetyLocked ? theme.danger : theme.divider
    implicitHeight: content.implicitHeight + theme.unit * 2

    ColumnLayout {
        id: content
        x: root.theme.unit
        y: root.theme.unit
        width: Math.max(0, root.width - root.theme.unit * 2)
        spacing: root.compact ? root.theme.unit * 0.5 : root.theme.unit
        USVOperationsButton {
            Layout.fillWidth: true
            Layout.preferredHeight: root.theme.controlHeight
            font.pointSize: root.theme.headingPointSize
            theme: root.theme
            destructive: true
            symbol: "stop"
            text: root.controller.emergencyPending ? qsTr("急停响应中…") : qsTr("紧急停止")
            helpText: qsTr("停止推进电机并取消当前采样")
            enabled: root.operations.connected && !root.controller.emergencyPending
            objectName: "usvEmergencyButton"
            onClicked: root.controller.requestEmergencyStop()
        }
        QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; color: root.theme.warning; font.bold: true; text: root.controller.emergencyTitle; visible: root.controller.safetyLocked; wrapMode: Text.WordWrap; objectName: "usvEmergencyReceipt" }
        QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; color: root.theme.text; text: root.compact ? qsTr("实际停止待核验") : qsTr("实际停止待核验 · 操作已锁定"); visible: root.controller.safetyLocked; wrapMode: Text.WordWrap }
        QGCLabel { Layout.fillWidth: true; color: root.theme.secondary; font.pointSize: root.theme.captionPointSize; text: qsTr("%1\n%2").arg(root.controller.propulsionReceipt).arg(root.controller.payloadReceipt); visible: root.controller.safetyLocked && (!root.compact || !root.controller.canVerifyStop); wrapMode: Text.WordWrap }
        USVOperationsButton {
            Layout.fillWidth: true
            theme: root.theme
            text: qsTr("核验并解除锁定")
            enabled: root.controller.canVerifyStop
            visible: root.controller.canVerifyStop
            helpText: qsTr("收到未解锁与采样结束遥测后，现场确认设备停止")
            onClicked: root.controller.requestVerifyStop()
        }
    }
}

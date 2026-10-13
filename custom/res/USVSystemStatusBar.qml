import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

RowLayout {
    id: root

    required property var operations
    property var theme: _theme

    spacing: 0

    USVOperationsTheme {
        id: _theme

    }
    Repeater {
        model: [
            {
                title: qsTr("GPS"),
                value: operations.gpsText,
                ok: operations.gpsReady,
                warning: !operations.gpsReady
            },
            {
                title: qsTr("飞控连接"),
                value: operations.connected ? qsTr("在线") : operations.vehicle ? qsTr("连接中断") : qsTr("未连接"),
                ok: operations.connected,
                warning: !operations.connected
            },
            {
                title: qsTr("电池"),
                value: operations.batteryText,
                ok: operations.batteryPercent > 20,
                warning: operations.lowBattery
            },
            {
                title: qsTr("网络 / 船载链路"),
                value: operations.payloadOnline ? qsTr("遥测在线") : operations.connected ? qsTr("无载荷遥测") : qsTr("未连接"),
                ok: operations.payloadOnline,
                warning: operations.connected && !operations.payloadOnline
            },
            {
                title: qsTr("任务状态"),
                value: operations.taskText,
                ok: operations.taskExecuting,
                warning: operations.holdMode || (operations.autoMode && !operations.taskExecuting)
            }
        ]

        delegate: Item {
            required property int index
            required property var modelData

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: root.theme.unit * 10

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: root.theme.divider
                height: parent.height * 0.55
                visible: index > 0
                width: 1
            }
            ColumnLayout {
                anchors.bottomMargin: root.theme.unit * 0.6
                anchors.fill: parent
                anchors.leftMargin: root.theme.unit * 1.5
                anchors.rightMargin: root.theme.unit
                anchors.topMargin: root.theme.unit * 0.6
                spacing: root.theme.unit * 0.25

                QGCLabel {
                    Layout.fillWidth: true
                    color: root.theme.secondary
                    elide: Text.ElideRight
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                    text: modelData.title
                }
                RowLayout {
                    spacing: root.theme.unit * 0.6

                    Rectangle {
                        color: modelData.ok ? root.theme.good : modelData.warning ? root.theme.warning : root.theme.secondary
                        height: width
                        radius: width / 2
                        width: root.theme.unit * 0.8
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        color: root.theme.text
                        elide: Text.ElideRight
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                        text: modelData.value
                    }
                }
            }
        }
    }
}

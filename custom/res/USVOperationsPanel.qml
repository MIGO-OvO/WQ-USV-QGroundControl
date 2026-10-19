import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

import "USVFlyViewLayout.js" as USVLayout

Rectangle {
    id: root

    property int currentTab: 0
    required property var operations
    property var theme: _theme

    border.color: theme.divider
    border.width: 1
    clip: true
    color: theme.surface
    radius: theme.radius

    onOperationsChanged: currentTab = 0

    USVOperationsTheme {
        id: _theme

    }
    USVPayloadCommandController {
        id: commands

        operations: root.operations
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.theme.gap
        spacing: root.theme.unit

        RowLayout {
            Layout.fillWidth: true

            QGCLabel {
                Layout.fillWidth: true
                color: root.theme.text
                font.bold: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.3
                text: qsTr("作业监控")
            }
            QGCLabel {
                color: root.operations.connected ? root.theme.secondary : root.theme.warning
                font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                text: root.operations.connected ? (root.operations.vehicle.armed ? qsTr("已解锁") : qsTr("未解锁")) : qsTr("离线")
            }
        }
        TabBar {
            id: tabs

            Layout.fillWidth: true
            currentIndex: root.currentTab
            implicitHeight: root.theme.controlHeight
            implicitWidth: 0
            spacing: 0

            background: Rectangle {
                color: root.theme.surface
            }

            onCurrentIndexChanged: root.currentTab = currentIndex

            Repeater {
                model: [qsTr("系统状态"), qsTr("传感器数据"), qsTr("自动任务"), qsTr("调试信息")]

                TabButton {
                    id: tabButton

                    required property string modelData

                    Accessible.name: text
                    height: root.theme.controlHeight
                    text: modelData
                    width: tabs.width / 4

                    background: Rectangle {
                        border.color: tabButton.activeFocus ? root.theme.accent : root.theme.divider
                        border.width: tabButton.activeFocus ? 2 : 1
                        color: tabButton.checked ? root.theme.raised : root.theme.surface

                        Rectangle {
                            anchors.bottom: parent.bottom
                            color: root.theme.accent
                            height: 2
                            visible: tabButton.checked
                            width: parent.width
                        }
                    }
                    contentItem: QGCLabel {
                        color: tabButton.checked ? root.theme.text : root.theme.secondary
                        elide: Text.ElideRight
                        font.bold: tabButton.checked
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                        horizontalAlignment: Text.AlignHCenter
                        text: tabButton.text
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            color: root.operations.payloadFault || root.operations.attitudeCritical ? root.theme.danger : root.theme.warning
            font.bold: true
            text: root.operations.alertText
            visible: text.length > 0
            wrapMode: Text.WordWrap
        }
        Flickable {
            id: viewport

            Layout.fillHeight: true
            Layout.fillWidth: true
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: page.item ? page.item.implicitHeight : 0
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick

            ScrollBar.vertical: ScrollBar {
                id: scrollBar

                objectName: "operationsScrollBar"
                padding: 0
                policy: ScrollBar.AsNeeded
                width: root.theme.unit * 0.75

                background: Rectangle {
                    color: root.theme.raised
                    radius: width / 2
                }
                contentItem: Rectangle {
                    color: scrollBar.pressed ? root.theme.accent : root.theme.secondary
                    implicitHeight: root.theme.line * 2
                    implicitWidth: root.theme.unit * 0.75
                    radius: width / 2
                }
            }

            Loader {
                id: page

                objectName: "operationsContent"
                sourceComponent: root.currentTab === 0 ? systemPage : root.currentTab === 1 ? sensorPage : root.currentTab === 2 ? missionPage : debugPage
                // Reserve a separate scroll lane even when the page fits.
                width: Math.max(0, viewport.width - scrollBar.width - root.theme.unit * 0.65)

                onLoaded: viewport.contentY = 0
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            color: commands.warning ? root.theme.warning : root.theme.secondary
            font.pointSize: ScreenTools.defaultFontPointSize * 0.95
            text: commands.feedback
            visible: text.length > 0
            wrapMode: Text.WordWrap
        }
    }
    Component {
        id: systemPage

        ColumnLayout {
            spacing: root.theme.unit

            DataRow {
                labelText: qsTr("GPS 定位")
                valueColor: root.operations.gpsReady ? root.theme.good : root.theme.warning
                valueText: root.operations.gpsText
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.gap

                ColumnLayout {
                    Layout.fillWidth: true

                    QGCLabel {
                        color: root.theme.secondary
                        text: qsTr("船速")
                    }
                    RowLayout {
                        QGCLabel {
                            color: root.theme.text
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 2.4
                            text: root.operations.metric(root.operations.vehicle ? root.operations.vehicle.groundSpeed : null, 1, "", root.operations.connected)
                        }
                        QGCLabel {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: root.theme.unit * 0.5
                            color: root.theme.secondary
                            text: "m/s"
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true

                    QGCLabel {
                        color: root.theme.secondary
                        text: qsTr("航向")
                    }
                    QGCLabel {
                        color: root.theme.text
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 2.4
                        text: root.operations.metric(root.operations.vehicle ? root.operations.vehicle.heading : null, 0, "°", root.operations.connected)
                    }
                }
            }
            DataRow {
                labelText: qsTr("距返航点")
                valueText: root.operations.metric(root.operations.vehicle ? root.operations.vehicle.distanceToHome : null, 0, " m", root.operations.connected)
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("航线进度")
            }
            DataRow {
                labelText: root.operations.taskText
                valueText: root.operations.hasMission ? qsTr("任务项 %1 / %2").arg(root.operations.missionIndex).arg(root.operations.missionCount) : "—"
            }
            ProgressTrack {
                position: root.operations.missionPosition
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("自动采样")
            }
            DataRow {
                labelText: qsTr("采样状态")
                valueColor: root.operations.payloadFault ? root.theme.danger : root.operations.payloadOnline ? root.theme.accent : root.theme.warning
                valueText: root.operations.samplingText
            }
            DataRow {
                labelText: qsTr("采样步骤")
                valueText: root.operations.payloadOnline && root.operations.factNumber(root.operations.payload ? root.operations.payload.stepTotal : null, 0) > 0 ? root.operations.payloadMetric("stepCurrent", 0, "") + " / " + root.operations.payloadMetric("stepTotal", 0, "") : "—"
            }
            DataRow {
                labelText: qsTr("启动次数")
                valueText: root.operations.payloadMetric("sampleCount", 0, "")
            }
            DataRow {
                labelText: qsTr("采样准备")
                valueColor: commands.ready ? root.theme.good : root.theme.warning
                valueText: commands.ready ? qsTr("就绪") : !root.operations.payloadOnline ? qsTr("等待载荷") : !root.operations.validSignal ? qsTr("等待有效信号") : qsTr("需要设基线")
            }
            Divider {
            }
            DataRow {
                labelText: qsTr("航行模式")
                valueText: root.operations.connected ? root.operations.vehicle.flightMode : "—"
            }
            DataRow {
                labelText: qsTr("船体状态")
                valueColor: root.operations.attitudeCritical ? root.theme.danger : root.theme.text
                valueText: !root.operations.connected ? "—" : root.operations.attitudeCritical ? qsTr("姿态异常") : qsTr("姿态正常")
            }
        }
    }
    Component {
        id: sensorPage

        ColumnLayout {
            spacing: root.theme.unit

            SectionTitle {
                text: qsTr("水质传感器")
            }
            DataRow {
                labelText: qsTr("信号质量")
                valueColor: root.operations.validSignal ? root.theme.good : root.theme.warning
                valueText: root.operations.validSignal ? qsTr("有效") : qsTr("无有效测量")
            }
            DataRow {
                labelText: qsTr("吸光度")
                valueText: root.operations.validSignal ? root.operations.payloadMetric("absorbance", 4, " Abs") : "—"
            }
            DataRow {
                labelText: qsTr("检测电压")
                valueText: root.operations.validSignal ? root.operations.payloadMetric("voltage", 3, " V") : "—"
            }
            DataRow {
                labelText: qsTr("基线")
                valueColor: root.operations.baselineSet ? root.theme.good : root.theme.warning
                valueText: root.operations.baselineSet ? qsTr("已设置") : qsTr("未设置")
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("采样准备")
            }
            QGCLabel {
                Layout.fillWidth: true
                color: root.theme.secondary
                text: qsTr("先启动信号采集，待信号有效后设置基线。")
                wrapMode: Text.WordWrap
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31018)
                text: qsTr("启动信号采集")

                onClicked: commands.send(31018, 0)
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31017)
                text: qsTr("设置当前基线")

                onClicked: commands.send(31017, 0)
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31019)
                text: qsTr("停止信号采集")

                onClicked: commands.send(31019, 0)
            }
        }
    }
    Component {
        id: missionPage

        ColumnLayout {
            spacing: root.theme.unit

            SectionTitle {
                text: qsTr("自动任务")
            }
            DataRow {
                labelText: qsTr("任务状态")
                valueText: root.operations.taskText
            }
            DataRow {
                labelText: qsTr("当前任务项")
                valueText: root.operations.hasMission ? root.operations.missionIndex + " / " + root.operations.missionCount : "—"
            }
            ProgressTrack {
                position: root.operations.missionPosition
            }
            QGCLabel {
                Layout.fillWidth: true
                color: root.theme.secondary
                font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                text: qsTr("航线进度表示当前任务项位置；采样完成以载荷状态为准。")
                wrapMode: Text.WordWrap
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("采样执行")
            }
            DataRow {
                labelText: qsTr("当前阶段")
                valueText: root.operations.samplingText
            }
            DataRow {
                labelText: qsTr("采样步骤")
                valueText: root.operations.payloadMetric("stepCurrent", 0, "") + " / " + root.operations.payloadMetric("stepTotal", 0, "")
            }
            DataRow {
                labelText: qsTr("循环进度")
                valueText: !root.operations.payloadOnline ? "—" : root.operations.payloadMetric("loopCurrent", 0, "") + " / " + (root.operations.factNumber(root.operations.payload.loopTotal, 0) > 0 ? root.operations.payloadMetric("loopTotal", 0, "") : "∞")
            }
            DataRow {
                labelText: qsTr("启动次数")
                valueText: root.operations.payloadMetric("sampleCount", 0, "")
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("手动采样操作")
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31010)
                primary: true
                text: qsTr("开始点采样")

                onClicked: commands.send(31010, 0)
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31015)
                helpText: qsTr("沿用现有 5 秒走航间隔")
                text: qsTr("开始走航检测")

                onClicked: commands.send(31015, 5)
            }
            RowLayout {
                Layout.fillWidth: true

                USVOperationsButton {
                    Layout.fillWidth: true
                    enabled: commands.allowed(31012)
                    text: qsTr("暂停采样")

                    onClicked: commands.send(31012, 0)
                }
                USVOperationsButton {
                    Layout.fillWidth: true
                    enabled: commands.allowed(31013)
                    text: qsTr("恢复采样")

                    onClicked: commands.send(31013, 0)
                }
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31011)
                text: qsTr("停止采样")

                onClicked: commands.send(31011, 0)
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31016)
                text: qsTr("停止走航")

                onClicked: commands.send(31016, 0)
            }
        }
    }
    Component {
        id: debugPage

        ColumnLayout {
            spacing: root.theme.unit

            SectionTitle {
                text: qsTr("通信诊断")
            }
            DataRow {
                labelText: qsTr("飞控链路")
                valueText: root.operations.connected ? root.operations.vehicle.vehicleLinkManager.primaryLinkName : "—"
            }
            DataRow {
                labelText: qsTr("接收消息")
                valueText: root.operations.payload ? String(root.operations.payload.rxMsgTotal) : "—"
            }
            DataRow {
                labelText: qsTr("载荷字段帧")
                valueText: root.operations.payload ? String(root.operations.payload.rxNamedValue) : "—"
            }
            DataRow {
                labelText: qsTr("伴随心跳")
                valueText: root.operations.payload ? String(root.operations.payload.rxHeartbeat) : "—"
            }
            DataRow {
                labelText: qsTr("心跳到达间隔")
                valueText: root.operations.payloadOnline && root.operations.payload.rxHeartbeat > 1 ? Number(root.operations.payload.latencyMs).toFixed(0) + " ms" : "—"
            }
            DataRow {
                labelText: "SysID / CompID"
                valueText: root.operations.payload ? root.operations.payload.lastSysid + " / " + root.operations.payload.lastCompid : "—"
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("定位与姿态")
            }
            DataRow {
                labelText: qsTr("卫星数")
                valueText: root.operations.metric(root.operations.gps ? root.operations.gps.count : null, 0, "", root.operations.connected)
            }
            DataRow {
                labelText: "HDOP"
                valueText: root.operations.metric(root.operations.gps ? root.operations.gps.hdop : null, 2, "", root.operations.connected)
            }
            DataRow {
                labelText: qsTr("横滚 / 俯仰")
                valueText: root.operations.connected ? root.operations.roll.toFixed(1) + "° / " + root.operations.pitch.toFixed(1) + "°" : "—"
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("泵组与分光")
            }
            Repeater {
                model: [
                    {
                        label: qsTr("X 轴"),
                        fact: "pumpX",
                        digits: 1,
                        unit: "°"
                    },
                    {
                        label: qsTr("Y 轴"),
                        fact: "pumpY",
                        digits: 1,
                        unit: "°"
                    },
                    {
                        label: qsTr("Z 轴"),
                        fact: "pumpZ",
                        digits: 1,
                        unit: "°"
                    },
                    {
                        label: qsTr("A 轴"),
                        fact: "pumpA",
                        digits: 1,
                        unit: "°"
                    },
                    {
                        label: "PID Error",
                        fact: "pidError",
                        digits: 2,
                        unit: ""
                    },
                    {
                        label: "PID Mode",
                        fact: "pidMode",
                        digits: 0,
                        unit: ""
                    },
                    {
                        label: qsTr("参考电压"),
                        fact: "referenceVoltage",
                        digits: 3,
                        unit: " V"
                    },
                    {
                        label: qsTr("基线电压"),
                        fact: "baselineVoltage",
                        digits: 3,
                        unit: " V"
                    },
                    {
                        label: qsTr("载荷包计数"),
                        fact: "packetCount",
                        digits: 0,
                        unit: ""
                    }
                ]

                DataRow {
                    required property var modelData

                    labelText: modelData.label
                    valueText: root.operations.payloadMetric(modelData.fact, modelData.digits, modelData.unit)
                }
            }
            USVOperationsButton {
                Layout.fillWidth: true
                enabled: commands.allowed(31014)
                text: qsTr("校准泵组")

                onClicked: commands.send(31014, 0)
            }
            Divider {
            }
            SectionTitle {
                text: qsTr("船载计算与检测装置")
            }
            Repeater {
                model: [
                    {
                        label: qsTr("Jetson 温度"),
                        fact: "jetsonTemp",
                        unit: " °C"
                    },
                    {
                        label: qsTr("检测装置温度"),
                        fact: "detectorTemp",
                        unit: " °C"
                    },
                    {
                        label: qsTr("Jetson CPU"),
                        fact: "jetsonCpu",
                        unit: "%"
                    },
                    {
                        label: qsTr("Jetson 内存"),
                        fact: "jetsonMemory",
                        unit: "%"
                    },
                    {
                        label: qsTr("检测装置可用堆"),
                        fact: "detectorHeap",
                        unit: "%"
                    }
                ]

                DataRow {
                    required property var modelData

                    labelText: modelData.label
                    valueText: root.operations.factNumber(root.operations.payload ? root.operations.payload[modelData.fact] : null, -1) >= 0 ? root.operations.payloadMetric(modelData.fact, 1, modelData.unit) : "—"
                }
            }
        }
    }

    component DataRow: RowLayout {
        property string labelText
        property color valueColor: root.theme.text
        property string valueText

        Layout.fillWidth: true
        spacing: root.theme.unit

        QGCLabel {
            Layout.fillWidth: true
            color: root.theme.secondary
            elide: Text.ElideRight
            font.pointSize: ScreenTools.defaultFontPointSize
            text: parent.labelText
        }
        QGCLabel {
            color: parent.valueColor
            font.bold: true
            font.pointSize: ScreenTools.defaultFontPointSize
            text: parent.valueText
        }
    }
    component Divider: Rectangle {
        Layout.bottomMargin: root.theme.unit * 0.5
        Layout.fillWidth: true
        Layout.topMargin: root.theme.unit * 0.5
        color: root.theme.divider
        height: 1
    }
    component ProgressTrack: Rectangle {
        property real position: 0

        Layout.fillWidth: true
        color: root.theme.raised
        height: root.theme.unit * 0.75
        radius: height / 2

        Rectangle {
            color: root.theme.accent
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0, Math.min(1, parent.position))
        }
    }
    component SectionTitle: QGCLabel {
        Layout.fillWidth: true
        Layout.topMargin: root.theme.unit
        color: root.theme.text
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize * 1.05
    }
}

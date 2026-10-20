import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

import "USVFlyViewLayout.js" as USVLayout

Rectangle {
    id: root

    readonly property alias commands: commands
    readonly property bool compact: width < theme.unit * 93
    readonly property bool stacked: width < theme.unit * 62
    property string detailSection: ""
    property var emergencyController: null
    property bool expanded: true
    readonly property string feedback: emergencyController && emergencyController.feedback.length ? emergencyController.feedback : commands.feedback
    readonly property bool feedbackWarning: emergencyController && emergencyController.feedback.length ? emergencyController.feedbackWarning : commands.warning
    readonly property int mainCommand: !operations.connected || !operations.payloadOnline || operations.payloadFault ? 0 : operations.payloadStatus === USVLayout.StatusPaused ? 31013 : operations.payloadStatus === USVLayout.StatusWaitingStable ? 31011 : operations.payloadStatus === USVLayout.StatusSampling ? 31012 : operations.payloadStatus === USVLayout.StatusSurveying ? 31016 : operations.payloadWorking ? 0 : !operations.validSignal ? 31018 : !operations.baselineSet ? 31017 : commands.canStartPointSample ? 31010 : 0
    readonly property string mainText: commands.pendingCommand ? qsTr("等待命令响应") : mainCommand === 31018 ? qsTr("启动信号采集") : mainCommand === 31017 ? qsTr("设置当前基线") : mainCommand === 31010 ? qsTr("开始手动点采样") : mainCommand === 31011 ? qsTr("停止采样准备") : mainCommand === 31012 ? qsTr("暂停采样") : mainCommand === 31013 ? qsTr("恢复采样") : mainCommand === 31016 ? qsTr("停止走航检测") : operations.payloadWorking ? qsTr("设备作业中") : qsTr("等待设备就绪")
    property real maxHeight: parent ? parent.height : theme.line * 30
    required property var operations
    readonly property int preparationStep: !operations.payloadOnline ? 0 : !operations.validSignal ? 1 : !operations.baselineSet ? 2 : 3
    readonly property string readinessText: !operations.connected ? qsTr("等待连接") : !operations.hasPayload ? qsTr("载荷不可用") : !operations.payloadOnline ? qsTr("载荷离线") : operations.payloadFault || operations.payloadWorking || operations.payloadStatus === USVLayout.StatusPaused ? operations.samplingText : !operations.validSignal ? qsTr("等待有效信号") : !operations.baselineSet ? qsTr("待设基线") : qsTr("准备就绪")
    readonly property string signalText: operations.metric(operations.payload ? operations.payload.voltage : null, 3, "", operations.validSignal)
    readonly property string absorbanceText: operations.metric(operations.payload ? operations.payload.absorbance : null, 4, "", operations.validSignal && operations.baselineSet)
    property var theme: _theme
    readonly property real targetHeight: Math.min(maxHeight, header.implicitHeight + (expanded ? bodyColumn.implicitHeight + theme.gap * 2 : 0))
    readonly property string nextTitle: !operations.connected ? qsTr("连接无人船后开始准备") : !operations.payloadOnline ? qsTr("检查船载设备连接") : operations.payloadFault ? qsTr("检查采样装置") : operations.payloadStatus === USVLayout.StatusPaused ? qsTr("采样已暂停") : operations.payloadStatus === USVLayout.StatusWaitingStable ? qsTr("正在准备采样") : operations.payloadWorking ? qsTr("设备正在执行作业") : !operations.validSignal ? qsTr("先让检测器开始工作") : !operations.baselineSet ? qsTr("用当前有效测量设置基线") : qsTr("采样准备完成")
    readonly property string nextDescription: !operations.connected ? qsTr("通过 QGC 连接飞控，确认通信链路正常。") : !operations.payloadOnline ? qsTr("飞控已连接，等待载荷遥测；检查 Jetson 与检测装置链路。") : operations.payloadFault ? qsTr("本次任务未确认完成。核对设备状态后再继续操作。") : operations.payloadStatus === USVLayout.StatusPaused ? qsTr("确认现场条件后恢复采样，也可停止本次作业。") : operations.payloadStatus === USVLayout.StatusWaitingStable ? qsTr("准备完成后自动进入采样。可停止本次准备，准备期间不支持暂停。") : operations.payloadWorking ? qsTr("步骤与结果以载荷遥测为准。航线任务由官方任务控制器管理。") : !operations.validSignal ? qsTr("启动信号采集，收到有效测量后即可设置当前基线。") : !operations.baselineSet ? qsTr("确认检测电压有效，再设置基线；收到基线状态后可采样。") : qsTr("可开始一次手动点采样。航线定点采样请在 Plan 中配置任务项。")

    function toggleExpanded() {
        expanded = !expanded;
        // Hidden controls must not retain focus during the closing transition.
        expandButton.forceActiveFocus(Qt.OtherFocusReason);
    }
    function showSection(section) {
        detailSection = detailSection === section ? "" : section;
    }
    function queueDetailReveal() {
        detailReveal.stop();
        detailScroll.stop();
        if (expanded && detailSection.length)
            Qt.callLater(function() { detailReveal.restart(); });
        else if (expanded)
            Qt.callLater(function() { body.returnToBounds(); });
    }
    function send(command) {
        commands.send(command, 0);
    }
    function progressText() {
        if (!operations.payloadOnline)
            return qsTr("步骤与循环暂不可用");
        const step = operations.factNumber(operations.payload.stepCurrent, 0);
        const total = operations.factNumber(operations.payload.stepTotal, 0);
        const loop = operations.factNumber(operations.payload.loopCurrent, 0);
        const loops = operations.factNumber(operations.payload.loopTotal, 0);
        return total > 0 ? qsTr("步骤 %1 / %2  ·  循环 %3 / %4").arg(step).arg(total).arg(loop).arg(loops > 0 ? String(loops) : qsTr("不限")) : qsTr("当前没有采样步骤");
    }

    color: theme.surface
    height: targetHeight
    objectName: "usvSamplingWorkflow"
    radius: theme.dockRadius
    clip: true

    onDetailSectionChanged: queueDetailReveal()
    onExpandedChanged: queueDetailReveal()

    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    USVOperationsTheme { id: _theme }
    USVPayloadCommandController {
        id: commands
        operations: root.operations
        safetyLocked: !!root.emergencyController && !!root.emergencyController.safetyLocked
    }
    Timer {
        id: detailReveal

        // Let the height settle before positioning the new section. Include
        // its toggle row so the user can switch back or close it in place.
        interval: 220
        onTriggered: {
            if (!root.expanded || !root.detailSection.length)
                return;
            detailScroll.to = Math.max(0, Math.min(body.contentHeight - body.height, detailActions.y - root.theme.unit));
            detailScroll.start();
        }
    }
    NumberAnimation {
        id: detailScroll
        target: body
        property: "contentY"
        duration: 180
        easing.type: Easing.OutCubic
    }
    // Consume pointer events over the dock only; the surrounding map stays live.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = true; }
    }
    ColumnLayout {
        id: header

        spacing: root.theme.unit
        width: root.width
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.theme.gap
            Layout.rightMargin: root.theme.gap
            Layout.topMargin: root.theme.unit
            Layout.bottomMargin: root.theme.unit
            spacing: root.theme.unit
            QGCLabel {
                color: root.theme.text
                font.bold: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.15
                text: qsTr("采样准备")
            }
            Rectangle {
                color: root.operations.payloadFault ? root.theme.danger : root.operations.payloadOnline ? root.theme.good : root.theme.warning
                height: root.theme.unit * 0.65
                width: height
                radius: height / 2
            }
            QGCLabel {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: root.operations.payloadFault ? root.theme.danger : root.operations.payloadOnline ? root.theme.secondary : root.theme.warning
                elide: Text.ElideRight
                text: root.readinessText
            }
            USVOperationsButton {
                destructive: true
                flat: true
                enabled: root.operations.connected && !!root.emergencyController && !root.emergencyController.propulsionStopPending && !root.emergencyController.payloadStopPending
                helpText: qsTr("确认后停止推进电机并取消当前采样")
                objectName: "workflowEmergencyButton"
                text: qsTr("紧急停止")
                theme: root.theme
                onClicked: root.emergencyController.requestEmergencyStop()
            }
            USVOperationsButton {
                id: expandButton
                Accessible.description: root.expanded ? qsTr("收起采样准备，保留状态与告警") : qsTr("展开采样准备和设备操作")
                objectName: "workflowExpandButton"
                text: root.expanded ? qsTr("收起") : qsTr("展开")
                theme: root.theme
                onClicked: root.toggleExpanded()
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            Layout.leftMargin: root.theme.gap
            Layout.rightMargin: root.theme.gap
            Layout.bottomMargin: root.theme.gap
            color: root.operations.payloadFault ? root.theme.danger : root.theme.warning
            text: root.operations.alertText
            visible: text.length > 0
            wrapMode: Text.WordWrap
        }
        QGCLabel {
            Layout.fillWidth: true
            Layout.leftMargin: root.theme.gap
            Layout.rightMargin: root.theme.gap
            Layout.bottomMargin: root.theme.gap
            color: root.feedbackWarning ? root.theme.warning : root.theme.secondary
            objectName: "workflowFeedback"
            text: root.feedback
            visible: !root.expanded && text.length > 0
            wrapMode: Text.WordWrap
        }
    }
    Flickable {
        id: body

        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: bodyColumn.implicitHeight + root.theme.gap * 2
        enabled: root.expanded
        opacity: root.expanded ? 1 : 0
        visible: root.expanded || opacity > 0
        objectName: "workflowBody"
        ScrollBar.vertical: ScrollBar {
            id: bodyScroll
            policy: ScrollBar.AsNeeded
            active: root.expanded
            objectName: "workflowScrollBar"
        }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        ColumnLayout {
            id: bodyColumn

            spacing: root.theme.gap
            width: Math.max(0, body.width - root.theme.gap * 2 - bodyScroll.width - root.theme.unit)
            x: root.theme.gap
            y: root.theme.unit * 0.5
            objectName: "workflowContent"
            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.unit
                Repeater {
                    model: [qsTr("连接设备"), qsTr("获取信号"), qsTr("设置基线"), qsTr("手动点采样")]
                    delegate: RowLayout {
                        required property int index
                        required property string modelData
                        readonly property bool complete: index < root.preparationStep
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: root.theme.unit
                        Rectangle {
                            Layout.preferredHeight: root.theme.line * 1.5
                            Layout.preferredWidth: height
                            color: parent.complete ? Qt.tint(root.theme.surface, Qt.rgba(root.theme.good.r, root.theme.good.g, root.theme.good.b, 0.22)) : index === root.preparationStep ? root.theme.primaryFill : root.theme.raised
                            radius: height / 2
                            QGCLabel {
                                anchors.centerIn: parent
                                color: root.theme.text
                                text: String(index + 1)
                                visible: !parent.parent.complete
                            }
                            Canvas {
                                anchors.fill: parent
                                visible: parent.parent.complete
                                onVisibleChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.strokeStyle = root.theme.good;
                                    ctx.lineWidth = 1.8;
                                    ctx.beginPath();
                                    ctx.moveTo(width * 0.28, height * 0.51);
                                    ctx.lineTo(width * 0.44, height * 0.66);
                                    ctx.lineTo(width * 0.73, height * 0.35);
                                    ctx.stroke();
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.theme.unit * 0.3
                            QGCLabel {
                                Layout.fillWidth: true
                                color: root.theme.text
                                font.bold: index === root.preparationStep
                                text: modelData
                                wrapMode: Text.WordWrap
                            }
                            QGCLabel {
                                Layout.fillWidth: true
                                color: root.theme.secondary
                                font.pointSize: ScreenTools.smallFontPointSize
                                text: index === 0 ? root.operations.payloadOnline ? qsTr("飞控与载荷在线") : qsTr("等待载荷连接") : index === 1 ? root.operations.validSignal ? qsTr("有效测量已到达") : qsTr("等待有效测量") : index === 2 ? root.operations.baselineSet ? qsTr("基线已设置") : qsTr("先获取有效测量") : root.operations.payloadWorking || root.operations.payloadStatus === USVLayout.StatusPaused ? root.operations.samplingText : qsTr("准备后可执行")
                                visible: !root.compact
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: root.theme.gap * 2
                columns: root.stacked ? 1 : root.compact ? 2 : 3
                rowSpacing: root.theme.gap
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.theme.unit * 34
                    spacing: root.theme.unit * 0.65
                    QGCLabel {
                        Layout.fillWidth: true
                        color: root.theme.text
                        font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.2
                        text: root.nextTitle
                        wrapMode: Text.WordWrap
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        color: root.theme.secondary
                        text: root.nextDescription
                        wrapMode: Text.WordWrap
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.theme.unit * 25
                    spacing: root.theme.unit
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.gap * 2
                        Repeater {
                            model: [qsTr("检测电压"), qsTr("吸光度")]
                            delegate: ColumnLayout {
                                required property int index
                                required property string modelData
                                Layout.fillWidth: true
                                spacing: root.theme.unit * 0.5
                                QGCLabel { color: root.theme.secondary; text: modelData }
                                QGCLabel {
                                    color: root.theme.text
                                    font.bold: true
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.45
                                    text: (index === 0 ? root.signalText : root.absorbanceText) + (index === 0 ? " V" : " Abs")
                                }
                            }
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        color: root.operations.baselineSet ? root.theme.secondary : root.theme.warning
                        text: root.operations.baselineSet ? qsTr("基线  %1 V").arg(root.operations.payloadMetric("baselineVoltage", 3, "")) : qsTr("基线  未设置")
                        wrapMode: Text.WordWrap
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.theme.unit * 28
                    Layout.columnSpan: root.compact && !root.stacked ? 2 : 1
                    spacing: root.theme.unit * 0.65
                    USVOperationsButton {
                        Layout.fillWidth: true
                        enabled: root.mainCommand !== 0 && commands.allowed(root.mainCommand)
                        helpText: root.nextDescription
                        objectName: "workflowMainButton"
                        primary: true
                        text: root.mainText
                        theme: root.theme
                        onClicked: root.send(root.mainCommand)
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        color: root.theme.secondary
                        horizontalAlignment: Text.AlignHCenter
                        text: commands.busy ? qsTr("设备状态返回后可继续") : root.preparationStep === 1 ? qsTr("下一步：等待有效测量") : root.preparationStep === 2 ? qsTr("下一步：确认基线状态") : root.operations.payloadWorking ? root.progressText() : qsTr("操作结果以遥测为准")
                        wrapMode: Text.WordWrap
                    }
                }
            }
            RowLayout {
                id: detailActions
                Layout.fillWidth: true
                spacing: root.theme.unit
                objectName: "workflowDetailActions"
                Item { Layout.fillWidth: true }
                USVOperationsButton {
                    checked: root.detailSection === "devices"
                    objectName: "workflowDevicesButton"
                    text: qsTr("设备控制")
                    theme: root.theme
                    onClicked: root.showSection("devices")
                }
                USVOperationsButton {
                    checked: root.detailSection === "diagnostics"
                    objectName: "workflowDiagnosticsButton"
                    text: qsTr("通信诊断")
                    theme: root.theme
                    onClicked: root.showSection("diagnostics")
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider; visible: root.detailSection.length > 0 || root.feedback.length > 0 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.gap
                visible: root.detailSection === "devices"
                QGCLabel {
                    Layout.fillWidth: true
                    color: root.theme.secondary
                    text: qsTr("泵组角度  X %1°   Y %2°   Z %3°   A %4°").arg(root.operations.payloadMetric("pumpX", 1, "")).arg(root.operations.payloadMetric("pumpY", 1, "")).arg(root.operations.payloadMetric("pumpZ", 1, "")).arg(root.operations.payloadMetric("pumpA", 1, ""))
                    wrapMode: Text.WordWrap
                }
                Flow {
                    Layout.fillWidth: true
                    objectName: "workflowDeviceControls"
                    spacing: root.theme.unit
                    Repeater {
                        model: [{name: qsTr("启动信号"), command: 31018}, {name: qsTr("停止信号"), command: 31019}, {name: qsTr("重设基线"), command: 31017}, {name: qsTr("校准泵组"), command: 31014}, {name: qsTr("开始走航检测"), command: 31015}, {name: qsTr("停止走航"), command: 31016}, {name: qsTr("停止采样"), command: 31011}]
                        delegate: USVOperationsButton {
                            required property var modelData
                            enabled: commands.allowed(modelData.command)
                            objectName: "workflowCommand" + modelData.command
                            text: modelData.name
                            theme: root.theme
                            onClicked: root.send(modelData.command)
                        }
                    }
                }
                QGCLabel {
                    Layout.fillWidth: true
                    color: root.theme.secondary
                    text: root.progressText()
                    wrapMode: Text.WordWrap
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.unit
                objectName: "workflowDiagnosticsContent"
                visible: root.detailSection === "diagnostics"
                QGCLabel {
                    Layout.fillWidth: true
                    color: root.theme.text
                    text: root.operations.connected ? qsTr("飞控链路  %1").arg(root.operations.vehicle.vehicleLinkManager.primaryLinkName) : qsTr("飞控链路  未连接")
                    wrapMode: Text.WrapAnywhere
                }
                QGCLabel {
                    Layout.fillWidth: true
                    color: root.theme.secondary
                    text: root.operations.payloadOnline ? qsTr("载荷报文 %1  ·  心跳到达间隔 %2 ms").arg(root.operations.payloadMetric("packetCount", 0, "")).arg(root.operations.payload.latencyMs) : qsTr("载荷遥测不可用，请检查通信链路")
                    wrapMode: Text.WordWrap
                }
                QGCLabel {
                    Layout.fillWidth: true
                    color: root.theme.secondary
                    text: qsTr("Jetson %1 °C  ·  检测装置 %2 °C").arg(root.operations.payloadMetric("jetsonTemp", 1, "")).arg(root.operations.payloadMetric("detectorTemp", 1, ""))
                    wrapMode: Text.WordWrap
                }
            }
            QGCLabel {
                Layout.fillWidth: true
                color: root.feedbackWarning ? root.theme.warning : root.theme.secondary
                text: root.feedback
                visible: text.length > 0
                wrapMode: Text.WordWrap
            }
        }
    }
}

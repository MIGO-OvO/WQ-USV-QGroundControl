pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.Controls

import "USVFlyViewLayout.js" as USVLayout

USVCockpitSurface {
    id: root

    required property var operations
    required property var controller
    property real maxHeight: implicitHeight
    property bool compact: false
    property bool expanded: true
    property bool diagnostics: false
    readonly property real contentHeight: expanded ? bodyColumn.implicitHeight + theme.gap : 0
    readonly property var currentTask: controller.commandController && controller.commandController.activeTask
                                      && controller.commandController.activeTask.vehicle === operations.vehicle
                                      ? controller.commandController.activeTask : null
    readonly property bool routeTask: !currentTask && operations.taskExecuting && [USVLayout.StatusNavigating, USVLayout.StatusWaypointReached,
                                        USVLayout.StatusHolding, USVLayout.StatusResumingAuto].indexOf(operations.payloadStatus) >= 0
    readonly property string taskTitle: currentTask ? currentTask.command === 31010 ? qsTr("手动点采样")
                                                      : currentTask.command === 31014 ? qsTr("泵组校准") : qsTr("走航检测")
                                                  : routeTask ? qsTr("航线任务") : qsTr("载荷作业（来源待确认）")
    readonly property string preflightPhase: currentTask && currentTask.latestEvent ? currentTask.latestEvent.preflight_phase || "" : ""
    readonly property string preflightText: {
        switch (preflightPhase) {
        case "checking": return qsTr("检查设备");
        case "homing": return qsTr("泵组回零");
        case "compensating": return qsTr("泵组补偿");
        case "separating": return qsTr("油相分隔");
        case "injection": return qsTr("进样准备");
        case "complete": return qsTr("准备完成");
        default: return qsTr("设备准备");
        }
    }
    readonly property bool preparing: !!currentTask && !currentTask.terminal && operations.payloadStatus !== USVLayout.StatusPaused
                                      && preflightPhase !== "" && preflightPhase !== "complete"
    readonly property int phaseIndex: !operations.payloadOnline ? -1 : currentTask
                                     ? currentTask.terminal ? 3 : preparing ? 1 : currentTask.executing || currentTask.observed ? 2 : -1
                                     : operations.phaseIndex
    readonly property var observedStages: {
        if (!currentTask)
            return routeTask ? operations.observedStages : phaseIndex >= 0 ? [phaseIndex] : [];
        const seen = [];
        for (const event of currentTask.stages) {
            if (currentTask.attemptId && event.attempt_id !== currentTask.attemptId)
                continue;
            const stage = event.phase === "terminal" ? 3 : event.preflight_phase && event.preflight_phase !== "complete" ? 1 : event.phase === "progress" ? 2 : -1;
            if (stage >= 0 && seen.indexOf(stage) < 0)
                seen.push(stage);
        }
        if (phaseIndex >= 0 && seen.indexOf(phaseIndex) < 0)
            seen.push(phaseIndex);
        return seen;
    }
    readonly property var stages: routeTask ? [
        { phase: 0, label: qsTr("接近航点") }, { phase: 1, label: preflightText },
        { phase: 2, label: qsTr("执行采样") }, { phase: 3, label: qsTr("返回结果") }, { phase: 4, label: qsTr("继续航行") }
    ] : [{ phase: 1, label: preflightText }, { phase: 2, label: currentTask && currentTask.command === 31014 ? qsTr("执行校准") : qsTr("执行检测") }, { phase: 3, label: qsTr("任务结果") }]

    objectName: "usvCurrentTaskPanel"
    implicitHeight: header.implicitHeight + theme.gap * 2 + contentHeight
    height: Math.min(implicitHeight, maxHeight)

    ColumnLayout {
        id: header
        objectName: "usvTaskHeader"
        x: root.theme.gap
        y: root.theme.unit
        width: Math.max(0, root.width - root.theme.gap * 2)
        spacing: root.theme.unit
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.fillWidth: true; text: root.diagnostics ? qsTr("通信诊断") : qsTr("当前任务"); color: root.theme.text; font.bold: true; font.pointSize: root.theme.headingPointSize }
            USVOperationsButton {
                Layout.preferredWidth: ScreenTools.minTouchPixels
                Layout.preferredHeight: ScreenTools.minTouchPixels
                padding: root.theme.unit * 0.3
                theme: root.theme
                flat: true
                symbol: root.expanded ? "down" : "chevron"
                helpText: root.expanded ? qsTr("收起任务详情，保留当前阶段") : qsTr("展开任务详情")
                Accessible.name: helpText
                onClicked: root.expanded = !root.expanded
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.divider }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.unit
            visible: root.maxHeight >= root.theme.line * 11
            USVCockpitIcon { Layout.preferredWidth: root.theme.line * 1.4; Layout.preferredHeight: root.theme.line * 1.4; name: "route"; color: root.theme.accent }
            QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; color: root.theme.text; font.bold: true; text: root.taskTitle; elide: Text.ElideRight }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.theme.line * 2.3
            color: root.theme.background(root.controller.safetyLocked || root.operations.payloadFault ? root.theme.dangerFill : root.operations.payloadOnline ? root.theme.primaryFill : root.theme.mutedFill)
            radius: root.theme.radius
            QGCLabel { font.pointSize: root.theme.bodyPointSize;
                anchors.fill: parent
                anchors.margins: root.theme.unit
                color: root.theme.text
                font.bold: true
                text: root.controller.safetyLocked ? qsTr("实际停止待核验") : root.preparing ? qsTr("设备准备：%1").arg(root.preflightText) : root.operations.samplingText
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
                objectName: "usvTaskPhase"
            }
        }
    }
    Flickable {
        id: body
        objectName: "usvTaskBody"
        x: root.theme.gap
        y: header.y + header.height + root.theme.unit
        width: Math.max(0, root.width - root.theme.gap * 2)
        height: Math.max(0, root.height - y - root.theme.unit)
        visible: root.expanded
        contentHeight: bodyColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: bodyColumn
            width: body.width - root.theme.unit
            spacing: root.theme.gap
            USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("航行模式"); value: root.operations.modeText }
            USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("当前航点"); value: root.operations.waypointText }
            RowLayout {
                Layout.fillWidth: true
                visible: root.compact
                spacing: root.theme.unit
                Repeater {
                    model: 3
                    delegate: ColumnLayout {
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: root.theme.unit * 0.5
                        QGCLabel { text: [qsTr("流程步骤"), qsTr("当前循环"), qsTr("启动次数")][parent.index]; color: root.theme.secondary; font.pointSize: root.theme.captionPointSize }
                        QGCLabel { font.pointSize: root.theme.bodyPointSize; text: [root.operations.stepText, root.operations.loopText, root.operations.sampleCountText][parent.index]; color: root.theme.text; font.bold: true }
                    }
                }
            }
            QGCLabel { font.pointSize: root.theme.bodyPointSize;
                Layout.fillWidth: true
                color: root.theme.warning
                text: root.operations.alertText
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.diagnostics
                spacing: root.compact ? root.theme.unit * 0.75 : root.theme.unit * 1.5
                Repeater {
                    model: root.stages
                    delegate: RowLayout {
                        id: stage
                        required property var modelData
                        readonly property bool current: root.phaseIndex === modelData.phase
                        readonly property bool observed: root.observedStages.indexOf(modelData.phase) >= 0
                        Layout.fillWidth: true
                        spacing: root.theme.unit
                        Rectangle {
                            Layout.preferredWidth: root.theme.line * 1.3
                            Layout.preferredHeight: root.theme.line * 1.3
                            radius: width / 2
                            color: stage.current ? root.theme.accent : stage.observed ? root.theme.good : root.theme.surface
                            border.color: stage.current ? root.theme.text : stage.observed ? root.theme.good : root.theme.secondary
                            border.width: 1
                            USVCockpitIcon { anchors.fill: parent; anchors.margins: root.theme.unit * 0.25; name: stage.observed && !stage.current ? "check" : ""; color: root.theme.surface }
                        }
                        QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; text: stage.modelData.label; color: stage.current ? root.theme.accent : root.theme.text; font.bold: stage.current }
                        QGCLabel { text: stage.current ? qsTr("当前") : stage.observed ? qsTr("已观测") : qsTr("待观测"); color: root.theme.secondary; font.pointSize: root.theme.captionPointSize; visible: !root.compact }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.divider; visible: !root.diagnostics }
            USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("流程步骤"); value: root.operations.stepText; visible: !root.diagnostics && !root.compact }
            USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("当前循环"); value: root.operations.loopText; visible: !root.diagnostics && !root.compact }
            USVCockpitValueRow { Layout.fillWidth: true; theme: root.theme; label: qsTr("启动次数"); value: root.operations.sampleCountText; visible: !root.diagnostics && !root.compact }
            Loader {
                Layout.fillWidth: true
                active: root.diagnostics
                visible: active
                sourceComponent: Component {
                    USVCockpitDiagnostics { operations: root.operations; theme: root.theme }
                }
            }
        }
    }
}

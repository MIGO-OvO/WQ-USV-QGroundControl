pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.Controls

USVCockpitSurface {
    id: root

    required property var operations
    required property var controller
    required property var commands
    property real maxHeight: implicitHeight
    property bool compact: false
    property bool expanded: true
    property bool devicesExpanded: false
    property bool diagnosticsShown: false
    readonly property bool preparing: operations.payloadOnline && !operations.payloadWorking && operations.payloadStatus !== 11 && (!operations.validSignal || !operations.baselineSet)

    signal diagnosticsRequested()

    function revealFocusedControl() {
        const window = root.Window.window;
        const focused = window ? window.activeFocusItem : null;
        if (!focused || !body.visible || body.height <= 0)
            return;
        let ancestor = focused;
        while (ancestor && ancestor !== body.contentItem)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        const top = focused.mapToItem(body.contentItem, 0, 0).y;
        const bottom = top + focused.height;
        if (top < body.contentY)
            body.contentY = Math.max(0, top - root.theme.unit);
        else if (bottom > body.contentY + body.height)
            body.contentY = Math.min(Math.max(0, body.contentHeight - body.height), bottom - body.height + root.theme.unit);
    }

    objectName: "usvCockpitControlPanel"
    clip: true
    implicitHeight: header.implicitHeight + theme.unit * 2 + (expanded ? content.implicitHeight + theme.gap : 0)
    height: Math.min(implicitHeight, maxHeight)
    visible: maxHeight >= header.implicitHeight + theme.unit * 2 + (expanded ? theme.line * 2 + theme.unit : 0)

    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { root.revealFocusedControl(); }
    }

    RowLayout {
        id: header
        objectName: "usvControlHeader"
        x: root.theme.gap
        y: root.theme.unit
        width: Math.max(0, root.width - root.theme.gap * 2)
        QGCLabel { Layout.fillWidth: true; color: root.theme.text; font.bold: true; font.pointSize: root.theme.headingPointSize; text: qsTr("操作控制") }
        USVOperationsButton { Layout.preferredWidth: ScreenTools.minTouchPixels; Layout.preferredHeight: ScreenTools.minTouchPixels; padding: root.theme.unit * 0.3; theme: root.theme; symbol: root.expanded ? "down" : "chevron"; helpText: root.expanded ? qsTr("收起操作控制") : qsTr("展开操作控制"); Accessible.name: helpText; onClicked: root.expanded = !root.expanded }
    }
    Flickable {
        id: body
        objectName: "usvControlBody"
        x: root.theme.gap
        y: header.y + header.height + root.theme.unit
        width: Math.max(0, root.width - root.theme.gap * 2)
        height: Math.max(0, root.height - y - root.theme.unit)
        contentHeight: content.implicitHeight
        clip: true
        visible: root.expanded
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        onHeightChanged: root.revealFocusedControl()
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: content
            width: Math.max(0, body.width - root.theme.unit)
            spacing: root.theme.unit
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.divider }
            Loader {
                Layout.fillWidth: true
                active: !root.compact
                visible: active
                sourceComponent: navigationComponent
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: root.theme.unit; color: root.theme.divider; visible: !root.compact }
            QGCLabel { font.pointSize: root.theme.bodyPointSize; color: root.theme.secondary; text: qsTr("采样作业") }
            USVOperationsButton {
                Layout.fillWidth: true
                theme: root.theme
                primary: true
                symbol: root.operations.validSignal ? "baseline" : "signal"
                text: root.operations.validSignal ? qsTr("设置当前基线") : qsTr("启动信号采集")
                visible: root.preparing
                enabled: root.commands.allowed(root.operations.validSignal ? 31017 : 31018)
                helpText: root.commands.helpTextFor(root.operations.validSignal ? 31017 : 31018, "")
                onClicked: root.commands.send(root.operations.validSignal ? 31017 : 31018, 0)
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width < root.theme.unit * 24 ? 1 : 2
                columnSpacing: root.theme.unit
                rowSpacing: root.theme.unit
                USVOperationsButton { Layout.fillWidth: true; Layout.preferredWidth: 1; theme: root.theme; primary: true; symbol: root.operations.payloadStatus === 11 ? "play" : "pause"; text: root.operations.payloadStatus === 11 ? qsTr("恢复采样") : qsTr("暂停采样"); enabled: root.commands.allowed(root.operations.payloadStatus === 11 ? 31013 : 31012); onClicked: root.commands.send(root.operations.payloadStatus === 11 ? 31013 : 31012, 0) }
                USVOperationsButton { Layout.fillWidth: true; Layout.preferredWidth: 1; theme: root.theme; symbol: "stop"; text: qsTr("停止采样"); enabled: root.commands.allowed(31011) && !root.controller.emergencyPending; helpText: root.commands.helpTextFor(31011, qsTr("取消采样作业；不会停止推进电机")); onClicked: root.commands.send(31011, 0) }
            }
            USVOperationsButton { Layout.fillWidth: true; theme: root.theme; symbol: "hand"; text: qsTr("手动点采样"); visible: !root.compact || !root.operations.payloadWorking && root.operations.payloadStatus !== 11; enabled: root.commands.allowed(31010); helpText: root.commands.helpTextFor(31010, qsTr("有效信号与基线就绪后执行一次点采样")); onClicked: root.commands.send(31010, 0) }
            QGCLabel { Layout.fillWidth: true; visible: !root.operations.payloadOnline; text: qsTr("等待载荷遥测，开始与恢复操作不可用"); color: root.theme.warning; font.pointSize: root.theme.captionPointSize; wrapMode: Text.WordWrap }
            QGCLabel { Layout.fillWidth: true; visible: !root.compact && text.length > 0; color: root.theme.secondary; font.pointSize: root.theme.captionPointSize; wrapMode: Text.WordWrap; text: root.commands.helpTextFor(root.operations.validSignal ? 31017 : 31018, ""); objectName: "usvCommandBlockedReason" }
            QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; text: root.commands.feedback.length ? root.commands.feedback : root.controller.feedback; color: root.commands.feedback.length ? root.commands.warning ? root.theme.warning : root.theme.secondary : root.controller.feedbackWarning ? root.theme.warning : root.theme.secondary; visible: text.length > 0; wrapMode: Text.WordWrap; objectName: "usvCommandFeedback" }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: root.theme.unit; color: root.theme.divider }
            Loader {
                Layout.fillWidth: true
                active: root.compact
                visible: active
                sourceComponent: navigationComponent
            }
            USVOperationsButton { Layout.fillWidth: true; theme: root.theme; flat: true; symbol: "pump"; text: root.devicesExpanded ? qsTr("收起设备控制") : qsTr("设备控制"); onClicked: root.devicesExpanded = !root.devicesExpanded }
            Loader {
                Layout.fillWidth: true
                active: root.devicesExpanded
                visible: active
                sourceComponent: Component { USVCockpitDeviceControls { operations: root.operations; controller: root.controller; commands: root.commands; theme: root.theme } }
            }
            USVOperationsButton { Layout.fillWidth: true; theme: root.theme; flat: true; symbol: "diagnostics"; text: root.diagnosticsShown ? qsTr("返回当前任务") : qsTr("通信诊断"); helpText: qsTr("在左侧查看船载状态和通信统计"); onClicked: root.diagnosticsRequested() }
        }
    }
    Component {
        id: navigationComponent
        USVCockpitNavigationControls { operations: root.operations; controller: root.controller; theme: root.theme }
    }
}

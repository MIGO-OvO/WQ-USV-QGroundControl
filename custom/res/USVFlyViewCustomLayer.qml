/*
 * THESIS: 采样准备沿一条流程带完成，地图保留主工作区。
 * OWN-WORLD: QGC 原生顶栏和航行仪表，实色深色面板、蓝色主操作和克制的状态色。
 * STORY: 连接设备、获取有效信号、设置基线，再手动点采样；设备和诊断按需展开。
 * FIRST VIEWPORT: 流程带停靠地图下方、原生仪表左侧；收起时保留状态、告警和急停。
 * FORM: 用户选择准备流程带；brief overrides direction seed c8468699；原生 QML。
 * FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
 */
import QtQuick

import QGroundControl
import QGroundControl.Controls

import USV

Item {
    id: root

    property var _guidedController: globals.guidedControllerFlyView
    readonly property int _payloadCompId: 191
    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property var dockGeometry: operationsState.workflowDock(width, height, theme.unit, parentToolInsets)
    property var mapControl
    property var parentToolInsets
    property var totalToolInsets: toolInsets

    USVOperationsTheme {
        id: theme

    }
    USVOperationsState {
        id: operationsState

        guidedController: root._guidedController
        missionController: root._guidedController ? root._guidedController.missionController : null
        vehicle: root.activeVehicle
    }

    // Reuse the established confirmation and ACK handling. Its Dialog is
    // parented to Overlay.overlay, so it remains usable by this hidden control.
    USVActionBar {
        id: emergencyController

        availableWidth: root.width
        operations: operationsState
        theme: theme
        visible: false
    }
    USVSamplingWorkflow {
        id: workflow

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.dockGeometry.bottom
        emergencyController: emergencyController
        maxHeight: root.dockGeometry.maxHeight
        operations: operationsState
        theme: theme
        width: root.dockGeometry.width
        x: root.dockGeometry.x
        z: 10
    }
    QGCToolInsets {
        id: toolInsets

        bottomEdgeCenterInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeCenterInset : 0, workflow.x <= root.width / 2 && workflow.x + workflow.width >= root.width / 2 ? root.height - workflow.y + theme.gap : 0)
        bottomEdgeLeftInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeLeftInset : 0, root.height - workflow.y + theme.gap)
        bottomEdgeRightInset: root.parentToolInsets ? root.parentToolInsets.bottomEdgeRightInset : 0
        leftEdgeBottomInset: root.parentToolInsets ? root.parentToolInsets.leftEdgeBottomInset : 0
        leftEdgeCenterInset: root.parentToolInsets ? root.parentToolInsets.leftEdgeCenterInset : 0
        leftEdgeTopInset: root.parentToolInsets ? root.parentToolInsets.leftEdgeTopInset : 0
        rightEdgeBottomInset: root.parentToolInsets ? root.parentToolInsets.rightEdgeBottomInset : 0
        rightEdgeCenterInset: root.parentToolInsets ? root.parentToolInsets.rightEdgeCenterInset : 0
        rightEdgeTopInset: root.parentToolInsets ? root.parentToolInsets.rightEdgeTopInset : 0
        topEdgeCenterInset: root.parentToolInsets ? root.parentToolInsets.topEdgeCenterInset : 0
        topEdgeLeftInset: root.parentToolInsets ? root.parentToolInsets.topEdgeLeftInset : 0
        topEdgeRightInset: root.parentToolInsets ? root.parentToolInsets.topEdgeRightInset : 0
    }
}

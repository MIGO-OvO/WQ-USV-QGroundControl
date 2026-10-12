/*
 * THESIS: 地图为主，驾驶、采样与诊断按作业频率分层。
 * OWN-WORLD: 实色工业深色面板，清晰文字，蓝色操作、橙色警示、红色急停。
 * STORY: 驾驶员先确认连接与船态，再启动和监控自动采样，按需进入诊断。
 * FIRST VIEWPORT: 顶部系统栏；右侧四个 Tab；底部集中航行控制；地图占主要区域。
 * FORM: 用户指定工业控制布局，优先 1280×720 / 1920×1080；brief overrides seed 6bf7e73d。
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
    readonly property real _toolsMargin: theme.unit * 0.75
    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
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

    // Overlay coordinates already start below the toolbar; parent top insets
    // are map coordinates. Do not add the toolbar height a second time.
    USVOperationsPanel {
        id: operationsPanel

        anchors.bottom: actionBar.top
        anchors.bottomMargin: root._toolsMargin
        anchors.right: parent.right
        anchors.top: parent.top
        operations: operationsState
        theme: theme
        width: operationsState.panelWidth(root.width, theme.unit)
        z: 10
    }
    USVActionBar {
        id: actionBar

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.parentToolInsets ? Math.max(root.parentToolInsets.bottomEdgeLeftInset, root.parentToolInsets.bottomEdgeRightInset) : 0
        availableWidth: Math.max(0, root.width - x)
        operations: operationsState
        theme: theme
        x: root.parentToolInsets ? root.parentToolInsets.leftEdgeBottomInset : 0
        z: 11
    }
    QGCToolInsets {
        id: toolInsets

        bottomEdgeCenterInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeCenterInset : 0, root.height - actionBar.y + root._toolsMargin)
        bottomEdgeLeftInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeLeftInset : 0, root.height - actionBar.y + root._toolsMargin)
        bottomEdgeRightInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeRightInset : 0, root.height - actionBar.y + root._toolsMargin)
        leftEdgeBottomInset: root.parentToolInsets ? root.parentToolInsets.leftEdgeBottomInset : 0
        leftEdgeCenterInset: root.parentToolInsets ? root.parentToolInsets.leftEdgeCenterInset : 0
        leftEdgeTopInset: root.parentToolInsets ? root.parentToolInsets.leftEdgeTopInset : 0
        rightEdgeBottomInset: Math.max(root.parentToolInsets ? root.parentToolInsets.rightEdgeBottomInset : 0, operationsPanel.width + root._toolsMargin)
        rightEdgeCenterInset: Math.max(root.parentToolInsets ? root.parentToolInsets.rightEdgeCenterInset : 0, operationsPanel.width + root._toolsMargin)
        rightEdgeTopInset: Math.max(root.parentToolInsets ? root.parentToolInsets.rightEdgeTopInset : 0, operationsPanel.width + root._toolsMargin)
        topEdgeCenterInset: root.parentToolInsets ? root.parentToolInsets.topEdgeCenterInset : 0
        topEdgeLeftInset: root.parentToolInsets ? root.parentToolInsets.topEdgeLeftInset : 0
        topEdgeRightInset: root.parentToolInsets ? root.parentToolInsets.topEdgeRightInset : 0
    }
}

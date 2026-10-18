import QtQuick

import QGroundControl
import QGroundControl.Controls

import USV
import "USVFlyViewLayout.js" as USVLayout

Item {
    id: root

    property var _guidedController: globals.guidedControllerFlyView
    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var mapControl
    property var parentToolInsets
    readonly property var totalToolInsets: toolInsets
    readonly property point mapOrigin: {
        const positionX = x;
        const positionY = y;
        return mapControl ? mapToItem(mapControl, positionX - x, positionY - y) : Qt.point(positionX, positionY);
    }
    readonly property real mapWidth: mapControl ? mapControl.width : width
    readonly property real mapHeight: mapControl ? mapControl.height : height
    readonly property var geometry: USVLayout.cockpitLayout(width, height, theme.unit, theme.line, parentToolInsets, mapOrigin.y)
    readonly property alias operations: operationsState
    readonly property alias controller: cockpitController
    readonly property alias commands: payloadCommands

    USVOperationsTheme { id: theme }
    USVOperationsState {
        id: operationsState
        guidedController: root._guidedController
        missionController: root._guidedController ? root._guidedController.missionController : null
        vehicle: root.activeVehicle
    }
    USVCockpitController {
        id: cockpitController
        operations: operationsState
        theme: theme
        commandController: payloadCommands
        onEmergencyIssued: payloadCommands.reset()
    }
    USVPayloadCommandController {
        id: payloadCommands
        operations: operationsState
        safetyLocked: cockpitController.safetyLocked
    }
    Binding {
        target: root._guidedController
        property: "safetyController"
        value: cockpitController
        when: !!root._guidedController
    }
    USVCurrentTaskPanel {
        id: taskPanel
        visible: root.geometry.taskVisible
        x: root.geometry.leftX
        y: root.geometry.top
        width: root.geometry.leftWidth
        maxHeight: root.geometry.leftMaxHeight
        compact: root.geometry.compact
        operations: operationsState
        controller: cockpitController
        theme: theme
    }
    USVEmergencyStopPanel {
        id: emergencyPanel
        x: root.geometry.rightX
        y: root.geometry.top
        width: root.geometry.rightWidth
        height: implicitHeight
        compact: root.geometry.compact
        operations: operationsState
        controller: cockpitController
        theme: theme
    }
    USVCockpitControlPanel {
        id: controlPanel
        x: root.geometry.rightX
        y: emergencyPanel.y + emergencyPanel.height + root.geometry.gap
        width: root.geometry.rightWidth
        maxHeight: Math.max(0, root.geometry.rightMaxHeight - emergencyPanel.height - root.geometry.gap)
        operations: operationsState
        controller: cockpitController
        commands: payloadCommands
        compact: root.geometry.compact
        theme: theme
        diagnosticsShown: taskPanel.diagnostics
        onDiagnosticsRequested: { taskPanel.diagnostics = !taskPanel.diagnostics; taskPanel.expanded = true; }
    }
    USVRealtimeDataStrip {
        id: dataStrip
        x: root.geometry.dataX
        y: root.geometry.dataY
        width: root.geometry.dataWidth
        height: root.geometry.dataHeight
        operations: operationsState
        theme: theme
    }
    QGCToolInsets {
        id: toolInsets

        leftEdgeTopInset: Math.max(root.parentToolInsets ? root.parentToolInsets.leftEdgeTopInset : 0, taskPanel.visible ? root.mapOrigin.x + taskPanel.x + taskPanel.width + root.geometry.gap : 0)
        leftEdgeCenterInset: leftEdgeTopInset
        leftEdgeBottomInset: Math.max(root.parentToolInsets ? root.parentToolInsets.leftEdgeBottomInset : 0, root.mapOrigin.x + dataStrip.x + dataStrip.width)
        rightEdgeTopInset: Math.max(root.parentToolInsets ? root.parentToolInsets.rightEdgeTopInset : 0, root.mapWidth - root.mapOrigin.x - emergencyPanel.x + root.geometry.gap)
        rightEdgeCenterInset: rightEdgeTopInset
        rightEdgeBottomInset: root.parentToolInsets ? root.parentToolInsets.rightEdgeBottomInset : 0
        topEdgeLeftInset: Math.max(root.parentToolInsets ? root.parentToolInsets.topEdgeLeftInset : 0, taskPanel.visible ? root.mapOrigin.y + taskPanel.y + taskPanel.height : 0)
        topEdgeCenterInset: Math.max(root.parentToolInsets ? root.parentToolInsets.topEdgeCenterInset : 0, root.mapOrigin.y)
        topEdgeRightInset: Math.max(root.parentToolInsets ? root.parentToolInsets.topEdgeRightInset : 0, root.mapOrigin.y + (controlPanel.visible ? controlPanel.y + controlPanel.height : emergencyPanel.y + emergencyPanel.height))
        bottomEdgeLeftInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeLeftInset : 0, root.mapHeight - root.mapOrigin.y - dataStrip.y + root.geometry.gap)
        bottomEdgeCenterInset: Math.max(root.parentToolInsets ? root.parentToolInsets.bottomEdgeCenterInset : 0, root.mapHeight - root.mapOrigin.y - dataStrip.y + root.geometry.gap)
        bottomEdgeRightInset: root.parentToolInsets ? root.parentToolInsets.bottomEdgeRightInset : 0
    }
}

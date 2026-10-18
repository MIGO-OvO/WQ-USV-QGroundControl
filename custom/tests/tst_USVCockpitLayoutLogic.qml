import QtQuick
import QtTest

import "../res/USVFlyViewLayout.js" as USVLayout

TestCase {
    name: "USVCockpitLayoutLogic"

    function test_edgeRegions_data() {
        return [
            {tag: "desktop", width: 1920, height: 934, unit: 9, line: 20},
            {tag: "compact", width: 1280, height: 587, unit: 9, line: 20},
            {tag: "large-font", width: 1280, height: 534, unit: 12.6, line: 28},
            {tag: "small-window", width: 900, height: 467, unit: 9, line: 20}
        ]
    }

    function test_edgeRegions(data) {
        const layout = USVLayout.cockpitLayout(data.width, data.height, data.unit, data.line,
            {leftEdgeTopInset: 62, rightEdgeBottomInset: 190, bottomEdgeRightInset: 180}, 140)
        verify(layout.leftX >= 62)
        verify(layout.leftX + layout.leftWidth < layout.rightX)
        verify(layout.rightX + layout.rightWidth <= data.width)
        verify(layout.top + layout.leftMaxHeight < layout.dataY)
        verify(layout.top + layout.rightMaxHeight <= data.height - 180)
        verify(layout.dataX + layout.dataWidth <= data.width - 190)
        verify(layout.dataY + layout.dataHeight <= data.height)
    }

    function test_centerScaleDoesNotPushDownEdgePanels() {
        const insets = {topEdgeCenterInset: 180}
        const belowToolbar = USVLayout.cockpitLayout(1280, 540, 9, 20, insets, 180)
        const fullViewport = USVLayout.cockpitLayout(1280, 720, 9, 20, insets, 0)
        compare(fullViewport.top, belowToolbar.top)
        compare(belowToolbar.top, belowToolbar.gap)
    }

    function test_expandedActionsReserveWidth() {
        const open = USVLayout.cockpitLayout(1280, 640, 9, 20, {leftEdgeTopInset: 260}, 80)
        verify(open.taskVisible)
        verify(open.leftX >= 260)
        verify(open.leftX + open.leftWidth < open.rightX)
        const narrow = USVLayout.cockpitLayout(700, 540, 12, 28, {leftEdgeTopInset: 420}, 100)
        verify(!narrow.taskVisible)
        const closed = USVLayout.cockpitLayout(700, 540, 12, 28, {leftEdgeTopInset: 62}, 100)
        verify(closed.taskVisible)
    }

    function test_pipAndCompassLiftDataWhenSpaceIsTight() {
        const layout = USVLayout.cockpitLayout(900, 600, 9, 20,
            {leftEdgeBottomInset: 270, bottomEdgeLeftInset: 162,
             rightEdgeBottomInset: 200, bottomEdgeRightInset: 180}, 0)
        verify(layout.lifted)
        verify(layout.dataY + layout.dataHeight <= 600 - 180)
        verify(layout.top + layout.leftMaxHeight < layout.dataY)
        verify(layout.top + layout.rightMaxHeight < layout.dataY)
    }

    function test_emptyViewportProducesFiniteGeometry() {
        const layout = USVLayout.cockpitLayout(0, 0, 0, 0, null, 0)
        for (const field of ["leftX", "leftWidth", "rightX", "rightWidth", "top",
                             "leftMaxHeight", "rightMaxHeight", "dataX", "dataY", "dataWidth", "dataHeight"])
            verify(isFinite(layout[field]) && layout[field] >= 0, field)
    }
}

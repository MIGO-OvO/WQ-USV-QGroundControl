import QtQuick
import QtTest

import "../res/USVFlyViewLayout.js" as USVLayout

TestCase {
    name: "USVFlyViewLayoutLogic"

    function test_tabletBreakpoints_data() {
        return [
            { tag: "1280x800-mdpi", width: 1280, font: 9, compact: false },
            { tag: "1280x800-hdpi", width: 1280 / 1.5, font: 9, compact: true },
            { tag: "1920x1200-xhdpi", width: 1920 / 2, font: 9, compact: true },
            { tag: "1920x1200-mdpi", width: 1920, font: 9, compact: false },
            { tag: "large-font", width: 1280, font: 12, compact: true },
            { tag: "boundary", width: 1170, font: 9, compact: false }
        ]
    }

    function test_tabletBreakpoints(data) {
        compare(USVLayout.compactSamplingLayout(data.width, data.font), data.compact)
    }

    function test_idleState_staysCompact() {
        const state = USVLayout.payloadState(true, USVLayout.StatusIdle, true, false)
        compare(state.compact, true)
        compare(state.showDetail, false)
        compare(state.showDiagnostics, false)
        compare(state.showQuickActions, false)
        compare(state.severity, "normal")
    }

    function test_samplingState_showsQuickActions() {
        const state = USVLayout.payloadState(true, USVLayout.StatusSampling, true, false)
        compare(state.compact, false)
        compare(state.showDetail, true)
        compare(state.showDiagnostics, false)
        compare(state.showQuickActions, true)
        compare(state.severity, "active")
    }

    function test_surveyingState_isActive() {
        const state = USVLayout.payloadState(true, USVLayout.StatusSurveying, true, false)
        compare(state.compact, false)
        compare(state.showDetail, true)
        compare(state.showQuickActions, true)
        compare(state.severity, "active")
    }

    function test_absorbanceSamplingRequiresBaseline() {
        compare(USVLayout.shouldSampleAbsorbance(USVLayout.StatusSampling, false), false)
        compare(USVLayout.shouldSampleAbsorbance(USVLayout.StatusSampling, true), true)
        compare(USVLayout.shouldSampleAbsorbance(USVLayout.StatusIdle, true), false)
    }

    function test_faultState_forcesDiagnostics() {
        const state = USVLayout.payloadState(true, USVLayout.StatusFault, true, false)
        compare(state.compact, false)
        compare(state.showDetail, true)
        compare(state.showDiagnostics, true)
        compare(state.showQuickActions, true)
        compare(state.severity, "critical")
    }

    function test_linkLoss_forcesVisibility() {
        const state = USVLayout.payloadState(true, USVLayout.StatusIdle, false, false)
        compare(state.compact, false)
        compare(state.showDetail, true)
        compare(state.showDiagnostics, true)
        compare(state.showQuickActions, false)
        compare(state.severity, "warning")
    }
}

.pragma library

// Logical viewport/font units: physical resolution alone is not a breakpoint.
function compactSamplingLayout(viewportWidth, fontWidth) {
    return viewportWidth < fontWidth * 130
}

function operationsPanelWidth(viewportWidth, fontWidth) {
    return Math.min(fontWidth * 44, viewportWidth * 0.32)
}

// The overlay already starts below the toolbar. Prefer the space beside bottom
// controls; lift the dock only when it cannot fit there, so the compass height
// is not counted twice. All breakpoints follow logical font units.
function workflowDock(viewportWidth, viewportHeight, fontWidth, insets) {
    const w = Math.max(0, viewportWidth)
    const h = Math.max(0, viewportHeight)
    const unit = Math.max(1, fontWidth)
    const gap = unit * 1.5
    function inset(name) {
        const value = insets ? Number(insets[name]) : 0
        return isFinite(value) ? Math.max(0, value) : 0
    }
    const sideLeft = Math.max(inset("leftEdgeTopInset"), inset("leftEdgeCenterInset"))
    const sideRight = Math.max(inset("rightEdgeTopInset"), inset("rightEdgeCenterInset"))
    const besideLeft = Math.max(sideLeft, inset("leftEdgeBottomInset")) + gap
    const besideRight = Math.max(sideRight, inset("rightEdgeBottomInset")) + gap
    const besideWidth = Math.max(0, w - besideLeft - besideRight)
    const lifted = besideWidth < unit * 62
    const left = lifted ? sideLeft + gap : besideLeft
    const right = lifted ? sideRight + gap : besideRight
    const bottom = lifted ? Math.max(inset("bottomEdgeLeftInset"), inset("bottomEdgeCenterInset"), inset("bottomEdgeRightInset")) + gap : gap
    return {
        x: Math.min(left, w),
        width: Math.max(0, Math.min(unit * 110, w - left - right)),
        bottom: Math.min(bottom, h),
        maxHeight: Math.max(0, h - bottom - gap),
        lifted: lifted
    }
}

function missionPosition(index, count) {
    if (!isFinite(index) || !isFinite(count) || count <= 0) return 0
    return Math.max(0, Math.min(1, index / count))
}

// Status constants — extended for auto-sampling mission stages
var StatusIdle = 0
var StatusSampling = 1
var StatusDetecting = 2
var StatusFault = 3
var StatusCalibrating = 4
var StatusNavigating = 5
var StatusWaypointReached = 6
var StatusHolding = 7
var StatusWaitingStable = 8
var StatusSamplingDone = 9
var StatusResumingAuto = 10
var StatusPaused = 11
var StatusAborted = 12
var StatusHoldNoMission = 13
var StatusSurveying = 14

var Tokens = {
    opacity: {
        panel: 0.92,
        overlay: 0.85,
        disabled: 0.35,
        subtle: 0.55
    },
    spacing: {
        xs: 0.3,
        sm: 0.6,
        md: 1.0,
        lg: 1.5,
        xl: 2.0
    },
    radius:  {
        sm: 0.4,
        md: 0.7,
        lg: 1.0,
        pill: 999
    },
    touch:   {
        minHeight: 2.2
    }
}

function statusText(status) {
    switch (status) {
    case StatusIdle: return "空闲"
    case StatusSampling: return "采样中"
    case StatusDetecting: return "检测中"
    case StatusFault: return "任务失败"
    case StatusCalibrating: return "校准中"
    case StatusNavigating: return "航行中"
    case StatusWaypointReached: return "到达航点"
    case StatusHolding: return "保持"
    case StatusWaitingStable: return "稳定等待"
    case StatusSamplingDone: return "采样完成"
    case StatusResumingAuto: return "恢复航行"
    case StatusPaused: return "已暂停"
    case StatusAborted: return "已中止"
    case StatusHoldNoMission: return "无任务保持"
    case StatusSurveying: return "走航检测"
    default: return "未知"
    }
}

function payloadState(hasVehicle, payloadStatus, linkOk, expanded) {
    const isWorking = payloadStatus === StatusSampling
            || payloadStatus === StatusDetecting
            || payloadStatus === StatusCalibrating
            || payloadStatus === StatusNavigating
            || payloadStatus === StatusHolding
            || payloadStatus === StatusWaitingStable
            || payloadStatus === StatusResumingAuto
            || payloadStatus === StatusSurveying
    const isFault = payloadStatus === StatusFault
            || payloadStatus === StatusAborted
    const isOffline = hasVehicle && !linkOk
    const forcedDetail = isWorking || isFault || isOffline

    return {
        compact: !expanded && !forcedDetail,
        showDetail: expanded || forcedDetail,
        showDiagnostics: expanded || isFault || isOffline,
        showQuickActions: hasVehicle && (isWorking || isFault),
        emphasizeSummary: isWorking || isFault || isOffline,
        severity: isFault ? "critical" : (isOffline ? "warning" : (isWorking ? "active" : "normal"))
    }
}

function shouldSampleAbsorbance(payloadStatus, baselineSet) {
    const chartActive = payloadStatus === StatusSampling
            || payloadStatus === StatusDetecting
            || payloadStatus === StatusCalibrating
            || payloadStatus === StatusWaitingStable
            || payloadStatus === StatusSurveying
    return !!baselineSet && chartActive
}

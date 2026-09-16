import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

import "USVFlyViewLayout.js" as USVLayout

Rectangle {
    id: root

    property var vehicle: null
    property int payloadStatus: USVLayout.StatusIdle
    property real availableWidth: parent ? parent.width : implicitWidth

    readonly property int _cmdStart: 31010
    readonly property int _cmdStop: 31011
    readonly property int _cmdStartSurvey: 31015
    readonly property int _cmdStopSurvey: 31016
    readonly property int _cmdSetBaseline: 31017
    readonly property int _cmdSpectroStart: 31018
    readonly property int _cmdSpectroStop: 31019
    readonly property int _payloadCompId: 191

    property real _m: ScreenTools.defaultFontPixelWidth
    property bool _hasPayloadGroup: vehicle && vehicle.factGroupNames.indexOf("usvPayload") >= 0
    property var _linkActiveFact: _hasPayloadGroup ? vehicle.getFact("usvPayload.linkActive") : null
    property var _baselineSetFact: _hasPayloadGroup ? vehicle.getFact("usvPayload.baselineSet") : null
    property var _spectrometerValidFact: _hasPayloadGroup ? vehicle.getFact("usvPayload.spectrometerValid") : null
    property bool _linkOk: _linkActiveFact ? _linkActiveFact.value === 1 : !_hasPayloadGroup
    property bool baselineSet: _baselineSetFact ? Number(_baselineSetFact.value) >= 1 : false
    property bool spectrometerValid: _spectrometerValidFact ? Number(_spectrometerValidFact.value) >= 1 : false
    property bool _canStartPointSample: payloadStatus === USVLayout.StatusIdle
                                        || payloadStatus === USVLayout.StatusSamplingDone
                                        || payloadStatus === USVLayout.StatusHoldNoMission
    property bool _isWorking: payloadStatus === USVLayout.StatusSampling
                              || payloadStatus === USVLayout.StatusDetecting
                              || payloadStatus === USVLayout.StatusCalibrating
                              || payloadStatus === USVLayout.StatusNavigating
                              || payloadStatus === USVLayout.StatusHolding
                              || payloadStatus === USVLayout.StatusWaitingStable
                              || payloadStatus === USVLayout.StatusResumingAuto
                              || payloadStatus === USVLayout.StatusSurveying

    implicitWidth: _m * 91
    width: Math.min(implicitWidth, availableWidth)
    height: actionRow.implicitHeight + _m * 2
    radius: _m
    color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, USVLayout.Tokens.opacity.panel)
    border.width: 1
    border.color: Qt.rgba(qgcPal.windowShade.r, qgcPal.windowShade.g, qgcPal.windowShade.b, 0.45)
    opacity: vehicle ? 1.0 : 0.0
    visible: opacity > 0

    Behavior on opacity { NumberAnimation { duration: 300 } }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    function _send(cmdId, param1) {
        if (vehicle) {
            vehicle.sendCommand(_payloadCompId, cmdId, false, param1 || 0)
        }
    }

    Flow {
        id: actionRow
        x: _m
        y: _m
        width: parent.width - _m * 2
        spacing: _m * USVLayout.Tokens.spacing.md

        Repeater {
            model: [
                { text: qsTr("启动信号"), cmd: _cmdSpectroStart, param1: 0, en: vehicle && _linkOk && payloadStatus !== USVLayout.StatusFault, warn: false },
                { text: qsTr("设基线"), cmd: _cmdSetBaseline, param1: 0, en: vehicle && _linkOk && spectrometerValid && payloadStatus !== USVLayout.StatusFault, warn: false },
                { text: qsTr("点采样"), cmd: _cmdStart, param1: 0, en: vehicle && _linkOk && spectrometerValid && baselineSet && _canStartPointSample, warn: false },
                { text: qsTr("走航"), cmd: _cmdStartSurvey, param1: 5, en: vehicle && _linkOk && spectrometerValid && baselineSet && payloadStatus !== USVLayout.StatusFault && payloadStatus !== USVLayout.StatusSurveying, warn: false },
                { text: qsTr("停止检测"), cmd: _cmdStop, param1: 0, en: vehicle && _isWorking, warn: true },
                { text: qsTr("停止走航"), cmd: _cmdStopSurvey, param1: 0, en: vehicle && payloadStatus === USVLayout.StatusSurveying, warn: true },
                { text: qsTr("停信号"), cmd: _cmdSpectroStop, param1: 0, en: vehicle && _linkOk, warn: true }
            ]

            delegate: Rectangle {
                id: btnRect
                height: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.5)
                width: Math.min(actionRow.width, textLabel.implicitWidth + _m * 3)
                radius: height / 2

                property bool isHovered: btnMouse.containsMouse
                property bool isPressed: btnMouse.pressed
                property color baseColor: modelData.warn
                    ? Qt.rgba(qgcPal.colorRed.r, qgcPal.colorRed.g, qgcPal.colorRed.b, 0.85)
                    : Qt.rgba(qgcPal.windowShade.r, qgcPal.windowShade.g, qgcPal.windowShade.b, 0.7)

                color: !modelData.en
                       ? Qt.rgba(qgcPal.windowShade.r, qgcPal.windowShade.g, qgcPal.windowShade.b, 0.3)
                       : (isPressed ? Qt.darker(baseColor, 1.2) : (isHovered ? Qt.lighter(baseColor, 1.1) : baseColor))

                scale: isPressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                QGCLabel {
                    id: textLabel
                    anchors.centerIn: parent
                    text: modelData.text
                    color: modelData.warn && modelData.en ? "white" : qgcPal.text
                    opacity: modelData.en ? 1.0 : USVLayout.Tokens.opacity.disabled
                    font.bold: true
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    enabled: modelData.en
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: _send(modelData.cmd, modelData.param1)
                }
            }
        }
    }
}

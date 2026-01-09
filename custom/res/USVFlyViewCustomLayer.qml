/****************************************************************************
 *
 * USV Fly View Custom Layer - 无人船飞行视图自定义层
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// @brief 无人船飞行视图自定义层
Item {
    id: _root

    // ========== 必需的属性 - 与 QGC 原生接口保持一致 ==========
    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    // 传递父级边距
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    // ========== USV 自定义属性 ==========
    property var  activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property real roll:             activeVehicle ? activeVehicle.roll.value  : 0
    property real pitch:            activeVehicle ? activeVehicle.pitch.value : 0
    property real _toolsMargin:     ScreenTools.defaultFontPixelWidth * 0.75

    // 姿态警告阈值
    property real rollWarningThreshold:  15.0
    property real pitchWarningThreshold: 10.0
    property real rollCriticalThreshold: 25.0
    property real pitchCriticalThreshold: 20.0

    property bool isRollWarning:    Math.abs(roll) > rollWarningThreshold
    property bool isPitchWarning:   Math.abs(pitch) > pitchWarningThreshold
    property bool isRollCritical:   Math.abs(roll) > rollCriticalThreshold
    property bool isPitchCritical:  Math.abs(pitch) > pitchCriticalThreshold
    property bool isAttitudeWarning: isRollWarning || isPitchWarning
    property bool isAttitudeCritical: isRollCritical || isPitchCritical

    // ========== 航行状态面板 ==========
    Rectangle {
        id: usvStatusPanel
        anchors.top:            parent.top
        anchors.right:          parent.right
        anchors.topMargin:      parentToolInsets.topEdgeRightInset + _toolsMargin
        anchors.rightMargin:    _toolsMargin
        width:                  statusColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 statusColumn.height + ScreenTools.defaultFontPixelHeight
        color:                  qgcPal.window
        opacity:                0.9
        radius:                 ScreenTools.defaultFontPixelWidth / 2

        QGCPalette { id: qgcPal; colorGroupEnabled: true }

        Column {
            id:                 statusColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelHeight / 4

            QGCLabel {
                text:               qsTr("航行状态")
                font.bold:          true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width:  parent.width
                height: 1
                color:  qgcPal.text
                opacity: 0.3
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("航速:"); opacity: 0.7; width: ScreenTools.defaultFontPixelWidth * 5 }
                QGCLabel { text: activeVehicle ? activeVehicle.groundSpeed.value.toFixed(1) + " m/s" : "---"; font.bold: true }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("航向:"); opacity: 0.7; width: ScreenTools.defaultFontPixelWidth * 5 }
                QGCLabel { text: activeVehicle ? activeVehicle.heading.value.toFixed(0) + "°" : "---"; font.bold: true }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("油门:"); opacity: 0.7; width: ScreenTools.defaultFontPixelWidth * 5 }
                QGCLabel { text: activeVehicle ? (activeVehicle.throttlePct * 100).toFixed(0) + "%" : "---"; font.bold: true }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("距Home:"); opacity: 0.7; width: ScreenTools.defaultFontPixelWidth * 5 }
                QGCLabel { text: activeVehicle ? activeVehicle.distanceToHome.value.toFixed(0) + " m" : "---"; font.bold: true }
            }
        }
    }

    // ========== 姿态监测面板 ==========
    Rectangle {
        id: attitudePanel
        anchors.top:            usvStatusPanel.bottom
        anchors.right:          parent.right
        anchors.topMargin:      _toolsMargin
        anchors.rightMargin:    _toolsMargin
        width:                  attitudeColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 attitudeColumn.height + ScreenTools.defaultFontPixelHeight
        color:                  isAttitudeCritical ? qgcPal.colorRed : (isAttitudeWarning ? qgcPal.colorOrange : qgcPal.window)
        opacity:                0.9
        radius:                 ScreenTools.defaultFontPixelWidth / 2

        Column {
            id:                 attitudeColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelHeight / 4

            QGCLabel {
                text:       qsTr("姿态监测")
                font.bold:  true
                color:      isAttitudeCritical ? "white" : qgcPal.text
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width:  parent.width
                height: 1
                color:  isAttitudeCritical ? "white" : qgcPal.text
                opacity: 0.3
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel {
                    text: qsTr("横滚:")
                    color: isAttitudeCritical ? "white" : qgcPal.text
                    opacity: isAttitudeCritical ? 1.0 : 0.7
                    width: ScreenTools.defaultFontPixelWidth * 5
                }
                QGCLabel {
                    text: roll.toFixed(1) + "°"
                    font.bold: true
                    color: isRollCritical ? "white" : (isRollWarning ? qgcPal.colorOrange : qgcPal.text)
                }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel {
                    text: qsTr("俯仰:")
                    color: isAttitudeCritical ? "white" : qgcPal.text
                    opacity: isAttitudeCritical ? 1.0 : 0.7
                    width: ScreenTools.defaultFontPixelWidth * 5
                }
                QGCLabel {
                    text: pitch.toFixed(1) + "°"
                    font.bold: true
                    color: isPitchCritical ? "white" : (isPitchWarning ? qgcPal.colorOrange : qgcPal.text)
                }
            }

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: isAttitudeCritical ? qsTr("⚠ 姿态危险！") : (isAttitudeWarning ? qsTr("姿态异常") : qsTr("✓ 运行平稳"))
                font.bold: true
                color: isAttitudeCritical ? "white" : (isAttitudeWarning ? qgcPal.colorOrange : qgcPal.colorGreen)
            }
        }
    }

    // ========== 模式指示器 ==========
    Rectangle {
        anchors.bottom:         parent.bottom
        anchors.left:           parent.left
        anchors.bottomMargin:   parentToolInsets.bottomEdgeLeftInset + _toolsMargin
        anchors.leftMargin:     _toolsMargin
        width:                  modeLabel.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 modeLabel.height + ScreenTools.defaultFontPixelHeight / 2
        color:                  activeVehicle && activeVehicle.armed ? qgcPal.colorGreen : qgcPal.colorGrey
        radius:                 ScreenTools.defaultFontPixelWidth / 2

        QGCLabel {
            id:                 modeLabel
            anchors.centerIn:   parent
            text:               activeVehicle ?
                                (activeVehicle.armed ? qsTr("🚤 已解锁 - ") : qsTr("🔒 已锁定 - ")) + activeVehicle.flightMode :
                                qsTr("🚤 USV 未连接")
            color:              "white"
            font.bold:          true
        }
    }

    // ========== 姿态危险警告横幅 ==========
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:            parent.top
        anchors.topMargin:      parentToolInsets.topEdgeCenterInset + ScreenTools.defaultFontPixelHeight * 2
        width:                  warningLabel.width + ScreenTools.defaultFontPixelWidth * 4
        height:                 warningLabel.height + ScreenTools.defaultFontPixelHeight
        color:                  qgcPal.colorRed
        radius:                 ScreenTools.defaultFontPixelWidth / 2
        visible:                isAttitudeCritical

        QGCLabel {
            id:                 warningLabel
            anchors.centerIn:   parent
            text:               qsTr("⚠️ 船体姿态异常 - 请检查水况或减速！")
            color:              "white"
            font.bold:          true
        }
    }
}

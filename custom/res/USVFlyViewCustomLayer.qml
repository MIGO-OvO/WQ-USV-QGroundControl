/****************************************************************************
 *
 * USV Fly View Custom Layer - 无人船飞行视图自定义层
 *
 * 注意：航行状态和姿态监测已整合到 USVInstrumentPanel.qml
 * 此文件仅保留警告横幅和模式指示器
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
    property real roll:             activeVehicle ? activeVehicle.roll.rawValue  : 0
    property real pitch:            activeVehicle ? activeVehicle.pitch.rawValue : 0
    property real _toolsMargin:     ScreenTools.defaultFontPixelWidth * 0.75

    // 姿态警告阈值
    property real rollCriticalThreshold:  25.0
    property real pitchCriticalThreshold: 20.0
    property bool isAttitudeCritical:     Math.abs(roll) > rollCriticalThreshold ||
                                          Math.abs(pitch) > pitchCriticalThreshold

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ========== 姿态危险警告横幅 ==========
    Rectangle {
        id:                         warningBanner
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                parent.top
        anchors.topMargin:          parentToolInsets.topEdgeCenterInset + ScreenTools.defaultFontPixelHeight
        width:                      warningLabel.width + ScreenTools.defaultFontPixelWidth * 4
        height:                     warningLabel.height + ScreenTools.defaultFontPixelHeight
        color:                      qgcPal.colorRed
        radius:                     ScreenTools.defaultFontPixelWidth / 2
        visible:                    isAttitudeCritical
        opacity:                    0.95

        SequentialAnimation on opacity {
            running:    warningBanner.visible
            loops:      Animation.Infinite
            NumberAnimation { to: 0.6; duration: 500 }
            NumberAnimation { to: 0.95; duration: 500 }
        }

        QGCLabel {
            id:                 warningLabel
            anchors.centerIn:   parent
            text:               qsTr("⚠️ 船体姿态异常 - 横滚: %1° 俯仰: %2° - 请检查水况或减速！")
                                    .arg(roll.toFixed(1)).arg(pitch.toFixed(1))
            color:              "white"
            font.bold:          true
        }
    }

    // ========== 模式指示器 (左下角) ==========
    Rectangle {
        id:                     modeIndicator
        anchors.bottom:         parent.bottom
        anchors.left:           parent.left
        anchors.bottomMargin:   parentToolInsets.bottomEdgeLeftInset + _toolsMargin
        anchors.leftMargin:     _toolsMargin
        width:                  modeRow.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 modeRow.height + ScreenTools.defaultFontPixelHeight / 2
        color:                  activeVehicle && activeVehicle.armed ? qgcPal.colorGreen : qgcPal.window
        radius:                 ScreenTools.defaultFontPixelWidth / 2
        opacity:                0.9

        Row {
            id:                 modeRow
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth / 2

            QGCLabel {
                text:           activeVehicle ?
                                (activeVehicle.armed ? "🚤" : "🔒") : "🚤"
                font.pointSize: ScreenTools.mediumFontPointSize
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           activeVehicle ?
                                (activeVehicle.armed ? qsTr("已解锁") : qsTr("已锁定")) + " - " + activeVehicle.flightMode :
                                qsTr("USV 未连接")
                color:          activeVehicle && activeVehicle.armed ? "white" : qgcPal.text
                font.bold:      true
            }
        }
    }
}

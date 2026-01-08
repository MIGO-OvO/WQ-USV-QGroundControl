/****************************************************************************
 *
 * USV Fly View Custom Layer - 无人船飞行视图自定义层
 *
 * 可在此添加无人船特有的 UI 元素
 * 例如：水深显示、航迹记录、水温等
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap

/// @brief 无人船飞行视图自定义层
/// 此组件会叠加在默认飞行视图之上
Item {
    id: usvCustomLayer
    anchors.fill: parent

    // 访问当前活动载具
    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    // QGC 调色板
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ========== 无人船状态指示器 ==========
    Rectangle {
        id: usvStatusPanel
        anchors.top:        parent.top
        anchors.right:      parent.right
        anchors.margins:    ScreenTools.defaultFontPixelWidth
        width:              usvStatusColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:             usvStatusColumn.height + ScreenTools.defaultFontPixelHeight
        color:              qgcPal.window
        opacity:            0.9
        radius:             ScreenTools.defaultFontPixelWidth / 2
        visible:            activeVehicle && activeVehicle.rover

        ColumnLayout {
            id:                 usvStatusColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelHeight / 4

            // 标题
            QGCLabel {
                text:               qsTr("无人船状态")
                font.bold:          true
                Layout.alignment:   Qt.AlignHCenter
            }

            // 分隔线
            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.text
                opacity:            0.3
            }

            // 航速显示
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("航速:")
                    opacity: 0.7
                }
                QGCLabel {
                    text: activeVehicle ? activeVehicle.groundSpeed.value.toFixed(1) + " m/s" : "---"
                    font.bold: true
                }
            }

            // 航向显示
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("航向:")
                    opacity: 0.7
                }
                QGCLabel {
                    text: activeVehicle ? activeVehicle.heading.value.toFixed(0) + "°" : "---"
                    font.bold: true
                }
            }

            // 油门显示
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("油门:")
                    opacity: 0.7
                }
                QGCLabel {
                    text: activeVehicle ? (activeVehicle.throttlePct * 100).toFixed(0) + "%" : "---"
                    font.bold: true
                }
            }

            // 距离 Home 点
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("距Home:")
                    opacity: 0.7
                }
                QGCLabel {
                    text: activeVehicle ? activeVehicle.distanceToHome.value.toFixed(0) + " m" : "---"
                    font.bold: true
                }
            }
        }
    }

    // ========== 无人船模式提示 ==========
    Rectangle {
        id: usvModeIndicator
        anchors.bottom:     parent.bottom
        anchors.left:       parent.left
        anchors.margins:    ScreenTools.defaultFontPixelWidth
        width:              usvModeLabel.width + ScreenTools.defaultFontPixelWidth * 2
        height:             usvModeLabel.height + ScreenTools.defaultFontPixelHeight / 2
        color:              activeVehicle && activeVehicle.armed ? qgcPal.colorGreen : qgcPal.colorGrey
        radius:             ScreenTools.defaultFontPixelWidth / 2
        visible:            activeVehicle && activeVehicle.rover

        QGCLabel {
            id:                 usvModeLabel
            anchors.centerIn:   parent
            text:               activeVehicle ?
                                (activeVehicle.armed ? qsTr("🚤 已解锁 - ") : qsTr("🔒 已锁定 - ")) +
                                activeVehicle.flightMode :
                                qsTr("未连接")
            color:              "white"
            font.bold:          true
        }
    }

    // ========== 水域警告提示 (示例) ==========
    // 可以根据实际需求添加水深传感器数据显示等
    /*
    Rectangle {
        id: waterDepthWarning
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 3
        width: warningLabel.width + ScreenTools.defaultFontPixelWidth * 2
        height: warningLabel.height + ScreenTools.defaultFontPixelHeight / 2
        color: qgcPal.colorOrange
        radius: ScreenTools.defaultFontPixelWidth / 2
        visible: false // 根据水深传感器数据控制显示

        QGCLabel {
            id: warningLabel
            anchors.centerIn: parent
            text: qsTr("⚠️ 水深不足")
            color: "white"
            font.bold: true
        }
    }
    */
}

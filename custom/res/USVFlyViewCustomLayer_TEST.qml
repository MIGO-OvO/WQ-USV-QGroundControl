/****************************************************************************
 *
 * USV Fly View Custom Layer - 测试版本
 * 用于验证 QML 覆盖是否生效
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Item {
    id: _root

    // 必需的属性
    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

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

    // 测试标记 - 如果看到这个红色矩形，说明 USV 自定义层已加载
    Rectangle {
        anchors.centerIn:   parent
        width:              300
        height:             150
        color:              "red"
        opacity:            0.9
        radius:             10
        z:                  9999

        Column {
            anchors.centerIn:   parent
            spacing:            10

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "🚤 USV CUSTOM LAYER"
                color:          "white"
                font.bold:      true
                font.pointSize: 24
            }

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "自定义层已成功加载！"
                color:          "white"
                font.pointSize: 16
            }

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "如果看到此消息，说明 QML 覆盖机制正常工作"
                color:          "white"
                font.pointSize: 12
            }
        }
    }
}

/****************************************************************************
 *
 * USV Custom Toolbar Button - Theme-Aware Logo Override
 * 无人船工具栏按钮 - 覆盖默认 QGCToolBarButton 以支持主题切换
 *
 * This component overrides QGCToolBarButton to provide theme-aware logo switching.
 * When the 'logo' property is true, it displays the USV brand image that
 * automatically switches between white (dark theme) and black (light theme).
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Override of QGCToolBarButton with theme-aware logo support
Button {
    id:                 button
    height:             ScreenTools.defaultFontPixelHeight * 3
    leftPadding:        _horizontalMargin
    rightPadding:       _horizontalMargin
    checkable:          false

    property bool logo: false

    property real _horizontalMargin: ScreenTools.defaultFontPixelWidth

    // Theme-aware logo source selection
    // Light theme (Outdoor) = black logo for visibility
    // Dark theme (Indoor) = white logo for visibility
    property string _logoSource: qgcPal.globalTheme === QGCPalette.Light
                                    ? "/custom/img/usv-logo-black.png"
                                    : "/custom/img/usv-logo-white.png"

    QGCPalette { id: qgcPal; colorGroupEnabled: button.enabled }

    onCheckedChanged: checkable = false

    background: Rectangle {
        anchors.fill:   parent
        color:          button.checked ? qgcPal.buttonHighlight : Qt.rgba(0,0,0,0)
        border.color:   "red"
        border.width:   QGroundControl.corePlugin.showTouchAreas ? 3 : 0
    }

    contentItem: Row {
        spacing:                ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: button.verticalCenter

        QGCColoredImage {
            id:                     _icon
            height:                 ScreenTools.defaultFontPixelHeight * 2
            width:                  height
            sourceSize.height:      parent.height
            fillMode:               Image.PreserveAspectFit
            // For logo mode: use theme-aware USV logo with transparent color
            // For non-logo mode: use the provided icon with theme-appropriate color
            color:                  button.logo ? "transparent" : (button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText)
            source:                 button.logo ? button._logoSource : button.icon.source
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            id:                     _label
            visible:                text !== ""
            text:                   button.text
            color:                  button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

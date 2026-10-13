import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Button {
    id: root

    property bool destructive: false
    property string helpText: ""
    property bool primary: false
    property var theme: _theme

    Accessible.description: helpText
    Accessible.name: text
    ToolTip.delay: 500
    ToolTip.text: helpText
    ToolTip.visible: hovered && helpText.length > 0
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitHeight: theme.controlHeight
    implicitWidth: label.implicitWidth + theme.unit * 3
    padding: theme.unit

    background: Rectangle {
        border.color: root.activeFocus ? root.theme.accent : root.destructive ? root.theme.danger : root.theme.divider
        border.width: root.activeFocus ? 2 : 1
        color: !root.enabled ? root.theme.surface : root.down ? Qt.lighter(root.destructive ? root.theme.dangerFill : root.theme.primaryFill, 1.2) : root.destructive ? root.theme.dangerFill : root.primary || root.checked ? root.theme.primaryFill : root.hovered ? Qt.lighter(root.theme.raised, 1.2) : root.theme.raised
        radius: root.theme.radius
    }
    contentItem: QGCLabel {
        id: label

        color: root.enabled ? root.theme.text : root.theme.secondary
        elide: Text.ElideRight
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        verticalAlignment: Text.AlignVCenter
    }

    USVOperationsTheme {
        id: _theme

    }
}

import QtQuick
import QtQuick.Controls.Basic

import QGroundControl
import QGroundControl.Controls

Button {
    id: root

    property bool destructive: false
    property string helpText: ""
    property string symbol: ""
    property bool primary: false
    property var theme: _theme

    Accessible.description: helpText
    Accessible.name: text
    ToolTip.delay: 500
    ToolTip.text: helpText
    ToolTip.visible: (hovered || activeFocus) && helpText.length > 0
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitHeight: theme.controlHeight
    implicitWidth: label.implicitWidth + theme.unit * 3 + (symbol.length ? theme.line * 1.7 : 0)
    padding: theme.unit * 0.75
    font.pointSize: theme.bodyPointSize

    background: Rectangle {
        opacity: root.theme.backgroundOpacity
        border.color: root.activeFocus ? root.theme.accent : root.destructive ? root.theme.danger : root.theme.divider
        border.width: root.activeFocus ? 2 : 1
        color: !root.enabled ? root.theme.surface : root.down ? Qt.lighter(root.destructive ? root.theme.dangerFill : root.theme.primaryFill, 1.2) : root.destructive ? root.flat ? Qt.tint(root.theme.surface, Qt.rgba(root.theme.danger.r, root.theme.danger.g, root.theme.danger.b, root.hovered ? 0.28 : 0.14)) : root.theme.dangerFill : root.primary || root.checked ? root.theme.primaryFill : root.hovered ? Qt.lighter(root.theme.raised, 1.2) : root.theme.raised
        radius: root.theme.radius
    }
    contentItem: Item {
        USVCockpitIcon {
            anchors.left: root.text.length ? parent.left : undefined
            anchors.horizontalCenter: root.text.length ? undefined : parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            color: root.enabled ? root.theme.text : root.theme.secondary
            height: root.theme.line * 1.05
            name: root.symbol
            visible: root.symbol.length > 0
            width: height
        }
        QGCLabel {
            id: label

            anchors.fill: parent
            anchors.leftMargin: root.symbol.length ? root.theme.line * 1.35 : 0
            color: root.enabled ? root.theme.text : root.theme.secondary
            elide: Text.ElideRight
            font.bold: true
            font.pointSize: root.font.pointSize
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
        }
    }

    USVOperationsTheme {
        id: _theme

    }
}

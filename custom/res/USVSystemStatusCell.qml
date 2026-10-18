import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.Controls

Item {
    id: root

    required property var theme
    required property string title
    required property string detail
    required property string stateText
    required property string symbol
    property bool healthy: false
    property bool separator: true
    property bool compact: false
    readonly property color statusColor: healthy ? theme.good : theme.warning

    implicitHeight: content.implicitHeight + theme.unit * 2
    implicitWidth: content.implicitWidth + theme.gap * 2
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("%1，%2，%3").arg(title).arg(stateText).arg(detail)
    activeFocusOnTab: true
    ToolTip.text: Accessible.name
    ToolTip.visible: statusHover.hovered || activeFocus
    ToolTip.delay: 400
    HoverHandler { id: statusHover }

    Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: parent.height * 0.65; color: root.theme.divider; visible: root.separator }
    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: root.theme.gap
        anchors.rightMargin: root.theme.unit
        anchors.topMargin: root.theme.unit
        anchors.bottomMargin: root.theme.unit
        spacing: root.theme.unit
        USVCockpitIcon { Layout.preferredWidth: root.theme.line * 1.6; Layout.preferredHeight: root.theme.line * 1.6; name: root.symbol; color: root.statusColor; visible: !root.compact }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.theme.unit * 0.3
            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.unit * 0.5
                QGCLabel { Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.title; color: root.statusColor; font.pointSize: root.theme.bodyPointSize; font.bold: true; textFormat: Text.PlainText; elide: Text.ElideRight }
                USVCockpitIcon { Layout.preferredWidth: root.theme.line * 0.8; Layout.preferredHeight: root.theme.line * 0.8; color: root.statusColor; name: root.healthy ? "check" : "warning" }
                Item { Layout.fillWidth: true }
            }
            QGCLabel { Layout.fillWidth: true; Layout.minimumWidth: 0; color: root.theme.text; text: root.stateText; font.pointSize: root.theme.captionPointSize; textFormat: Text.PlainText; elide: Text.ElideRight }
        }
    }
}

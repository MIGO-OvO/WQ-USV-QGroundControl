import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

Item {
    id: root

    required property var theme
    required property string title
    required property string value
    property string suffix: ""
    property string symbol: ""
    property bool separator: true
    property bool prominent: false

    implicitWidth: Math.max(theme.unit * 14, content.implicitWidth + theme.gap * 2)
    implicitHeight: content.implicitHeight + theme.unit * 2
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("%1，%2 %3").arg(title).arg(value).arg(suffix)

    Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: parent.height * 0.65; color: root.theme.divider; visible: root.separator }
    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.theme.unit
        spacing: root.theme.unit
        USVCockpitIcon { Layout.preferredWidth: root.theme.line * 1.35; Layout.preferredHeight: root.theme.line * 1.35; color: root.theme.text; name: root.symbol }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.theme.unit * 0.5
            QGCLabel { text: root.title; color: root.theme.secondary; font.pointSize: root.theme.captionPointSize; textFormat: Text.PlainText }
            RowLayout {
                spacing: root.theme.unit * 0.5
                QGCLabel { text: root.value; color: root.theme.text; font.bold: root.prominent; font.pointSize: root.prominent ? root.theme.headingPointSize : root.theme.bodyPointSize; textFormat: Text.PlainText }
                QGCLabel { text: root.suffix; color: root.theme.secondary; font.pointSize: root.theme.captionPointSize; textFormat: Text.PlainText }
            }
        }
    }
}

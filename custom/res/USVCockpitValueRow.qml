import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

RowLayout {
    id: root

    required property string label
    required property string value
    required property var theme
    property color valueColor: theme.text

    spacing: theme.unit

    QGCLabel { font.pointSize: root.theme.bodyPointSize; Layout.fillWidth: true; color: root.theme.secondary; text: root.label; textFormat: Text.PlainText; elide: Text.ElideRight }
    QGCLabel { font.pointSize: root.theme.bodyPointSize; color: root.valueColor; text: root.value; textFormat: Text.PlainText; font.bold: true; horizontalAlignment: Text.AlignRight }
}

import QtQuick

Rectangle {
    id: root

    required property var theme

    color: theme.panel
    radius: theme.radius
    border.color: theme.divider
    border.width: 1

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = true; }
    }
}

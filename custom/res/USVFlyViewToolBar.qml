import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

import USV

Item {
    id: control

    property var _guidedController: globals.guidedControllerFlyView
    required property var guidedValueSlider
    required property bool utmspSliderTrigger

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    height: statusRow.height + (guidedActionConfirm.visible ? confirmationRow.height : 0)
    width: parent.width

    USVOperationsTheme {
        id: theme

    }
    USVOperationsState {
        id: operationsState

        guidedController: control._guidedController
        missionController: control._guidedController ? control._guidedController.missionController : null
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
    }
    Rectangle {
        anchors.fill: parent
        color: theme.surface
    }
    RowLayout {
        id: statusRow

        height: Math.max(ScreenTools.toolbarHeight, theme.line * 3.5)
        spacing: theme.unit
        width: parent.width

        QGCToolBarButton {
            Layout.fillHeight: true
            icon.source: "/res/QGCLogoFull.svg"
            logo: true

            onClicked: mainWindow.showToolSelectDialog()
        }
        MainStatusIndicator {
            id: mainStatusIndicator

            Layout.fillHeight: true
        }
        USVSystemStatusBar {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.rightMargin: theme.unit
            operations: operationsState
            theme: theme
        }
    }
    Item {
        id: confirmationRow

        anchors.top: statusRow.bottom
        height: theme.line * 3
        visible: guidedActionConfirm.visible
        width: parent.width

        GuidedActionConfirm {
            id: guidedActionConfirm

            anchors.left: parent.left
            anchors.leftMargin: theme.gap
            guidedController: control._guidedController
            guidedValueSlider: control.guidedValueSlider
            height: parent.height
            messageDisplay: guidedMessage
            utmspSliderTrigger: control.utmspSliderTrigger
        }
        QGCLabel {
            id: guidedMessage

            anchors.left: guidedActionConfirm.right
            anchors.margins: theme.gap
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: theme.text
            text: guidedActionConfirm.message
            wrapMode: Text.WordWrap
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        color: theme.divider
        height: 1
        width: parent.width
    }
    PropertyAnimation {
        id: messageOpacityAnimation

        duration: 500
        from: 1
        property: "opacity"
        target: guidedMessage
        to: 0
    }
    Timer {
        id: messageFadeTimer

        interval: 4000

        onTriggered: messageOpacityAnimation.start()
    }
    ParameterDownloadProgress {
        anchors.fill: parent
    }
}

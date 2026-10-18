import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

import USV

Item {
    id: control

    property var _guidedController: globals.guidedControllerFlyView
    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    readonly property var cockpitController: _guidedController ? _guidedController.safetyController : null
    readonly property var mapInsets: typeof _mapControl !== "undefined" && _mapControl ? _mapControl.toolInsets : null
    property color _mainStatusBGColor: theme.surface
    required property var guidedValueSlider
    required property bool utmspSliderTrigger

    width: parent ? parent.width : implicitWidth
    height: Math.max(ScreenTools.toolbarHeight, theme.line * 3.5)
    objectName: "usvFlyViewToolBar"

    function dropMainStatusIndicatorTool() { mainStatusIndicator.dropMainStatusIndicator(); }

    USVOperationsTheme { id: theme }
    USVOperationsState {
        id: operationsState
        guidedController: control._guidedController
        missionController: control._guidedController ? control._guidedController.missionController : null
        vehicle: control._activeVehicle
    }
    Binding {
        target: control._guidedController
        property: "singleMissionEntry"
        value: true
        when: !!control._guidedController
    }
    Rectangle { anchors.fill: parent; color: theme.toolbarSurface }
    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: theme.unit
        spacing: theme.unit
        USVOperationsButton {
            Layout.preferredWidth: theme.controlHeight
            Layout.leftMargin: theme.unit
            theme: theme
            flat: true
            symbol: "menu"
            helpText: qsTr("页面入口：航行、规划、数据、设置")
            Accessible.name: helpText
            objectName: "usvPageMenuButton"
            onClicked: mainWindow.showToolSelectDialog()
        }
        MainStatusIndicator {
            id: mainStatusIndicator
            Layout.fillHeight: true
            compact: true
            objectName: "usvMainStatusIndicator"
            armingAllowed: !control.cockpitController || !control.cockpitController.isVehicleLocked(operationsState.vehicle)
        }
        USVSystemStatusBar {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            operations: operationsState
            theme: theme
        }
        Item {
            Layout.preferredWidth: guidedActionConfirm.visible ? guidedActionConfirm.width : startMissionButton.implicitWidth
            Layout.fillHeight: true
            USVOperationsButton {
                id: startMissionButton
                anchors.verticalCenter: parent.verticalCenter
                theme: theme
                primary: true
                symbol: "play"
                objectName: "usvStartMissionButton"
                text: control._guidedController && control._guidedController.showContinueMission ? qsTr("继续航线任务") : qsTr("开始航线任务")
                visible: !guidedActionConfirm.visible
                enabled: !!control.cockpitController && operationsState.connected && operationsState.gpsReady
                         && !control.cockpitController.safetyLocked && !operationsState.payloadWorking && operationsState.payloadStatus !== 11
                         && !!control._guidedController && (control._guidedController.showStartMission || control._guidedController.showContinueMission)
                helpText: qsTr("载入航线且 GPS 有效后开始；仍需长按确认")
                onClicked: control.cockpitController.startMission()
            }
            GuidedActionConfirm {
                id: guidedActionConfirm
                anchors.verticalCenter: parent.verticalCenter
                height: theme.controlHeight
                guidedController: control._guidedController
                guidedValueSlider: control.guidedValueSlider
                messageDisplay: guidedMessage
                utmspSliderTrigger: control.utmspSliderTrigger
            }
        }
    }
    // Only an explicit confirmation opens this explanation; toolbar stays one row.
    Rectangle {
        anchors.top: parent.bottom
        x: control.mapInsets ? control.mapInsets.leftEdgeCenterInset + theme.gap : control.width * 0.35
        width: Math.max(0, Math.min(theme.unit * 65, control.width - x - (control.mapInsets ? control.mapInsets.rightEdgeCenterInset + theme.gap : control.width * 0.35)))
        objectName: "usvConfirmationMessage"
        height: guidedMessage.implicitHeight + theme.gap * 2
        color: theme.panel
        visible: guidedActionConfirm.visible && guidedMessage.text.length > 0
        QGCLabel {
            id: guidedMessage
            anchors.fill: parent
            anchors.margins: theme.gap
            color: theme.text
            font.pointSize: theme.bodyPointSize
            text: guidedActionConfirm.message
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.divider }
    PropertyAnimation {
        id: messageOpacityAnimation
        target: guidedMessage
        property: "opacity"
        from: 1
        to: 0
        duration: 250
    }
    Timer { id: messageFadeTimer; interval: 4000; onTriggered: messageOpacityAnimation.start() }
    ParameterDownloadProgress { anchors.fill: parent }
}

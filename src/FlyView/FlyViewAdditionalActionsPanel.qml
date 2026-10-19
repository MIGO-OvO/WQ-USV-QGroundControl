/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id: root
    property var additionalActions
    property var mavlinkActions
    property var customActions

    property var  _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property var  _guidedController:    globals.guidedControllerFlyView

    // Pre-defined Additional Guided Actions
    Repeater {
        model: additionalActions.model

        QGCButton {
            background.opacity: ScreenTools.panelOpacity
            Layout.fillWidth:   true
            text:               modelData.title
            visible:            modelData.visible

            onClicked: {
                dropPanel.hide()
                _guidedController.confirmAction(modelData.action)
            }
        }
    }

    // Custom Build Actions
    Repeater {
        model: customActions.model

        QGCButton {
            background.opacity: ScreenTools.panelOpacity
            Layout.fillWidth:   true
            text:               modelData.title
            visible:            modelData.visible

            onClicked: {
                dropPanel.hide()
                _guidedController.confirmAction(modelData.action)
            }
        }
    }

    // User-defined Mavlink Actions
    Repeater {
        model: _activeVehicle ? mavlinkActions : undefined // The action list is a QmlObjectListModel

        QGCButton {
            background.opacity: ScreenTools.panelOpacity
            Layout.fillWidth:   true
            text:               object.label
            enabled:            !root._guidedController.safetyController || root._guidedController.safetyController.customActionAllowed(object, root._activeVehicle)

            onClicked: {
                dropPanel.hide()
                if (root._guidedController.safetyController)
                    root._guidedController.safetyController.executeCustomAction(object, root._activeVehicle)
                else
                    object.sendTo(root._activeVehicle)
            }
        }
    }
}

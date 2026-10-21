import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.Controls

USVCockpitSurface {
    id: root

    required property var operations

    objectName: "usvRealtimeDataStrip"
    implicitHeight: theme.line * 4.2

    Flickable {
        id: body
        anchors.fill: parent
        anchors.margins: 1
        clip: true
        contentWidth: Math.max(width, content.implicitWidth)
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        RowLayout {
            id: content
            width: body.contentWidth
            height: body.height
            spacing: 0
            USVCockpitMetric { Layout.fillWidth: true; Layout.fillHeight: true; theme: root.theme; title: qsTr("检测电压"); value: root.operations.voltageText; suffix: "V"; symbol: "flask"; separator: false; prominent: true }
            USVCockpitMetric { Layout.fillWidth: true; Layout.fillHeight: true; theme: root.theme; title: qsTr("吸光度"); value: root.operations.absorbanceText; suffix: "Abs"; symbol: "signal"; prominent: true }
            USVCockpitMetric { Layout.fillWidth: true; Layout.fillHeight: true; theme: root.theme; title: qsTr("基线"); value: !root.operations.fresh("baselineSet") ? "—" : root.operations.baselineSet ? qsTr("已设置") : qsTr("未设置"); symbol: "baseline" }
            USVCockpitMetric { Layout.fillWidth: true; Layout.fillHeight: true; theme: root.theme; title: qsTr("泵组角度"); value: qsTr("X %1  Y %2  Z %3  A %4").arg(root.operations.payloadMetric("pumpX", 0, "°")).arg(root.operations.payloadMetric("pumpY", 0, "°")).arg(root.operations.payloadMetric("pumpZ", 0, "°")).arg(root.operations.payloadMetric("pumpA", 0, "°")); symbol: "pump" }
            USVCockpitMetric { Layout.fillWidth: true; Layout.fillHeight: true; theme: root.theme; title: qsTr("设备温度"); value: qsTr("Jetson %1  检测装置 %2").arg(root.operations.payloadMetric("jetsonTemp", 0, " °C")).arg(root.operations.payloadMetric("detectorTemp", 0, " °C")); symbol: "temperature" }
        }
    }
}

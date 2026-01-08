/****************************************************************************
 *
 * USV AutoPilot Plugin Implementation - 无人船自动驾驶插件实现
 *
 ****************************************************************************/

#include "USVAutoPilotPlugin.h"
#include "VehicleComponent.h"
#include "Vehicle.h"

#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(USVFirmwarePluginLog)

USVAutoPilotPlugin::USVAutoPilotPlugin(Vehicle *vehicle, QObject *parent)
    : APMAutoPilotPlugin(vehicle, parent)
{
    qCDebug(USVFirmwarePluginLog) << "USVAutoPilotPlugin created for vehicle" << vehicle->id();
}

USVAutoPilotPlugin::~USVAutoPilotPlugin()
{
}

const QVariantList &USVAutoPilotPlugin::vehicleComponents()
{
    if (!_componentsFiltered) {
        _filterVehicleComponents();
        _componentsFiltered = true;
    }
    return _filteredComponents;
}

void USVAutoPilotPlugin::_filterVehicleComponents()
{
    // 获取父类的组件列表
    const QVariantList &baseComponents = APMAutoPilotPlugin::vehicleComponents();

    _filteredComponents.clear();

    for (const QVariant &componentVar : baseComponents) {
        VehicleComponent *component = componentVar.value<VehicleComponent*>();
        if (!component) {
            continue;
        }

        const QString &name = component->name();

        // 过滤掉不适用于无人船的组件
        // 注意：组件名称可能因固件版本而异，需要根据实际情况调整

        // 保留的组件:
        // - "Summary" - 摘要
        // - "Sensors" - 传感器
        // - "Radio" - 遥控器
        // - "Flight Modes" - 飞行模式
        // - "Power" - 电源
        // - "Safety" - 安全
        // - "Motors" - 电机
        // - "Tuning" - 调参
        // - "Camera" - 相机 (如果有)

        // 排除的组件:
        bool exclude = false;

        // 空速计设置 - 无人船不需要
        if (name.contains(QStringLiteral("Airspeed"), Qt::CaseInsensitive)) {
            exclude = true;
            qCDebug(USVFirmwarePluginLog) << "Excluding component:" << name;
        }

        // 副翼/升降舵/方向舵设置 - 固定翼专用
        if (name.contains(QStringLiteral("Aileron"), Qt::CaseInsensitive) ||
            name.contains(QStringLiteral("Elevator"), Qt::CaseInsensitive) ||
            name.contains(QStringLiteral("Rudder"), Qt::CaseInsensitive)) {
            exclude = true;
            qCDebug(USVFirmwarePluginLog) << "Excluding component:" << name;
        }

        // 螺旋桨设置 - 多旋翼专用
        if (name.contains(QStringLiteral("Propeller"), Qt::CaseInsensitive) &&
            name.contains(QStringLiteral("Multi"), Qt::CaseInsensitive)) {
            exclude = true;
            qCDebug(USVFirmwarePluginLog) << "Excluding component:" << name;
        }

        if (!exclude) {
            _filteredComponents.append(componentVar);
        }
    }

    qCDebug(USVFirmwarePluginLog) << "Filtered vehicle components:"
                                   << baseComponents.count() << "->"
                                   << _filteredComponents.count();
}

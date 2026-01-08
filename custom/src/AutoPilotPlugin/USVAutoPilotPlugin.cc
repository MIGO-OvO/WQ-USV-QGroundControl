/****************************************************************************
 *
 * USV AutoPilot Plugin Implementation - 无人船自动驾驶插件实现
 *
 * 同时支持 ArduPilot 和 PX4 固件
 *
 ****************************************************************************/

#include "USVAutoPilotPlugin.h"
#include "VehicleComponent.h"
#include "Vehicle.h"

#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(USVFirmwarePluginLog)

/// @brief 通用组件过滤逻辑
/// @param name 组件名称
/// @return true 如果应该排除该组件
static bool shouldExcludeComponent(const QString &name)
{
    // 空速计设置 - 无人船不需要
    if (name.contains(QStringLiteral("Airspeed"), Qt::CaseInsensitive)) {
        return true;
    }

    // 副翼/升降舵设置 - 固定翼专用
    if (name.contains(QStringLiteral("Aileron"), Qt::CaseInsensitive) ||
        name.contains(QStringLiteral("Elevator"), Qt::CaseInsensitive)) {
        return true;
    }

    // 多旋翼螺旋桨设置
    if (name.contains(QStringLiteral("Propeller"), Qt::CaseInsensitive) &&
        name.contains(QStringLiteral("Multi"), Qt::CaseInsensitive)) {
        return true;
    }

    // VTOL 相关设置
    if (name.contains(QStringLiteral("VTOL"), Qt::CaseInsensitive)) {
        return true;
    }

    return false;
}

/*===========================================================================*/
// USVAPMAutoPilotPlugin - ArduPilot 实现
/*===========================================================================*/

USVAPMAutoPilotPlugin::USVAPMAutoPilotPlugin(Vehicle *vehicle, QObject *parent)
    : APMAutoPilotPlugin(vehicle, parent)
{
    qCDebug(USVFirmwarePluginLog) << "USVAPMAutoPilotPlugin created for vehicle" << vehicle->id();
}

USVAPMAutoPilotPlugin::~USVAPMAutoPilotPlugin()
{
}

const QVariantList &USVAPMAutoPilotPlugin::vehicleComponents()
{
    if (!_componentsFiltered) {
        _filterVehicleComponents();
        _componentsFiltered = true;
    }
    return _filteredComponents;
}

void USVAPMAutoPilotPlugin::_filterVehicleComponents()
{
    const QVariantList &baseComponents = APMAutoPilotPlugin::vehicleComponents();

    _filteredComponents.clear();

    for (const QVariant &componentVar : baseComponents) {
        VehicleComponent *component = componentVar.value<VehicleComponent*>();
        if (!component) {
            continue;
        }

        const QString &name = component->name();

        if (shouldExcludeComponent(name)) {
            qCDebug(USVFirmwarePluginLog) << "APM: Excluding component:" << name;
            continue;
        }

        _filteredComponents.append(componentVar);
    }

    qCDebug(USVFirmwarePluginLog) << "APM: Filtered vehicle components:"
                                   << baseComponents.count() << "->"
                                   << _filteredComponents.count();
}

/*===========================================================================*/
// USVPX4AutoPilotPlugin - PX4 实现
/*===========================================================================*/

USVPX4AutoPilotPlugin::USVPX4AutoPilotPlugin(Vehicle *vehicle, QObject *parent)
    : PX4AutoPilotPlugin(vehicle, parent)
{
    qCDebug(USVFirmwarePluginLog) << "USVPX4AutoPilotPlugin created for vehicle" << vehicle->id();
}

USVPX4AutoPilotPlugin::~USVPX4AutoPilotPlugin()
{
}

const QVariantList &USVPX4AutoPilotPlugin::vehicleComponents()
{
    if (!_componentsFiltered) {
        _filterVehicleComponents();
        _componentsFiltered = true;
    }
    return _filteredComponents;
}

void USVPX4AutoPilotPlugin::_filterVehicleComponents()
{
    const QVariantList &baseComponents = PX4AutoPilotPlugin::vehicleComponents();

    _filteredComponents.clear();

    for (const QVariant &componentVar : baseComponents) {
        VehicleComponent *component = componentVar.value<VehicleComponent*>();
        if (!component) {
            continue;
        }

        const QString &name = component->name();

        if (shouldExcludeComponent(name)) {
            qCDebug(USVFirmwarePluginLog) << "PX4: Excluding component:" << name;
            continue;
        }

        _filteredComponents.append(componentVar);
    }

    qCDebug(USVFirmwarePluginLog) << "PX4: Filtered vehicle components:"
                                   << baseComponents.count() << "->"
                                   << _filteredComponents.count();
}

/****************************************************************************
 *
 * USV AutoPilot Plugin - 无人船自动驾驶插件
 *
 * 同时支持 ArduPilot 和 PX4 固件
 * 控制载具设置页面的可见性，隐藏不适用于无人船的设置组件
 *
 ****************************************************************************/

#pragma once

#include "AutoPilotPlugins/APM/APMAutoPilotPlugin.h"
#include "AutoPilotPlugins/PX4/PX4AutoPilotPlugin.h"

class Vehicle;

/// @brief USV ArduPilot 自动驾驶插件
/// 基于 APM 自动驾驶插件，针对无人船进行定制
class USVAPMAutoPilotPlugin : public APMAutoPilotPlugin
{
    Q_OBJECT

public:
    explicit USVAPMAutoPilotPlugin(Vehicle *vehicle, QObject *parent = nullptr);
    ~USVAPMAutoPilotPlugin();

    // ========== AutoPilotPlugin 覆盖 ==========

    /// @brief 获取载具组件列表
    /// 过滤掉不适用于无人船的组件
    const QVariantList &vehicleComponents() override;

private:
    void _filterVehicleComponents();

    QVariantList _filteredComponents;
    bool _componentsFiltered = false;
};

/*===========================================================================*/

/// @brief USV PX4 自动驾驶插件
/// 基于 PX4 自动驾驶插件，针对无人船进行定制
class USVPX4AutoPilotPlugin : public PX4AutoPilotPlugin
{
    Q_OBJECT

public:
    explicit USVPX4AutoPilotPlugin(Vehicle *vehicle, QObject *parent = nullptr);
    ~USVPX4AutoPilotPlugin();

    // ========== AutoPilotPlugin 覆盖 ==========

    /// @brief 获取载具组件列表
    /// 过滤掉不适用于无人船的组件
    const QVariantList &vehicleComponents() override;

private:
    void _filterVehicleComponents();

    QVariantList _filteredComponents;
    bool _componentsFiltered = false;
};

/****************************************************************************
 *
 * USV AutoPilot Plugin - 无人船自动驾驶插件
 *
 * 控制载具设置页面的可见性
 * 隐藏不适用于无人船的设置组件
 *
 ****************************************************************************/

#pragma once

#include "AutoPilotPlugins/APM/APMAutoPilotPlugin.h"

class Vehicle;

/// @brief USV 专用自动驾驶插件
/// 基于 APM 自动驾驶插件，针对无人船进行定制
class USVAutoPilotPlugin : public APMAutoPilotPlugin
{
    Q_OBJECT

public:
    explicit USVAutoPilotPlugin(Vehicle *vehicle, QObject *parent = nullptr);
    ~USVAutoPilotPlugin();

    // ========== AutoPilotPlugin 覆盖 ==========

    /// @brief 获取载具组件列表
    /// 过滤掉不适用于无人船的组件
    const QVariantList &vehicleComponents() override;

private:
    /// @brief 过滤载具组件
    void _filterVehicleComponents();

    QVariantList _filteredComponents;
    bool _componentsFiltered = false;
};

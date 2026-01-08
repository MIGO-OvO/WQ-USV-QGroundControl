/****************************************************************************
 *
 * USV Firmware Plugin Factory - 无人船固件插件工厂
 *
 * 负责创建 USV 固件插件实例
 *
 ****************************************************************************/

#pragma once

#include "FirmwarePluginFactory.h"

/// @brief USV 固件插件工厂
/// 为 ArduPilot Rover/Boat 类型载具创建 USV 专用固件插件
class USVFirmwarePluginFactory : public FirmwarePluginFactory
{
    Q_OBJECT

public:
    explicit USVFirmwarePluginFactory(QObject *parent = nullptr);
    ~USVFirmwarePluginFactory();

    // ========== FirmwarePluginFactory 覆盖 ==========

    /// @brief 获取支持的固件类型列表
    QList<QGCMAVLink::FirmwareClass_t> supportedFirmwareClasses() const override;

    /// @brief 获取指定固件类型支持的载具类型列表
    QList<QGCMAVLink::VehicleClass_t> supportedVehicleClasses(QGCMAVLink::FirmwareClass_t firmwareClass) const override;

    /// @brief 创建固件插件实例
    FirmwarePlugin *firmwarePluginForAutopilot(MAV_AUTOPILOT autopilotType, MAV_TYPE vehicleType) override;

private:
    class USVFirmwarePlugin *_usvFirmwarePlugin = nullptr;
};

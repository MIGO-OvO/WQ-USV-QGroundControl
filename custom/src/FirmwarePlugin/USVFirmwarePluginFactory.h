/****************************************************************************
 *
 * USV Firmware Plugin Factory - 无人船固件插件工厂
 *
 * 同时支持 ArduPilot 和 PX4 固件
 * 根据连接的载具自动选择对应的固件插件
 *
 ****************************************************************************/

#pragma once

#include "FirmwarePluginFactory.h"

class USVArduPilotFirmwarePlugin;
class USVPX4FirmwarePlugin;

/// @brief USV 固件插件工厂
/// 为 ArduPilot 和 PX4 的 Rover/Boat 类型载具创建 USV 专用固件插件
class USVFirmwarePluginFactory : public FirmwarePluginFactory
{
    Q_OBJECT

public:
    explicit USVFirmwarePluginFactory(QObject *parent = nullptr);
    ~USVFirmwarePluginFactory();

    // ========== FirmwarePluginFactory 覆盖 ==========

    /// @brief 获取支持的固件类型列表
    /// 同时支持 ArduPilot 和 PX4
    QList<QGCMAVLink::FirmwareClass_t> supportedFirmwareClasses() const override;

    /// @brief 获取指定固件类型支持的载具类型列表
    /// 仅支持 Rover/Boat 类型
    QList<QGCMAVLink::VehicleClass_t> supportedVehicleClasses(
        QGCMAVLink::FirmwareClass_t firmwareClass) const override;

    /// @brief 创建固件插件实例
    /// 根据固件类型返回对应的 USV 插件
    FirmwarePlugin *firmwarePluginForAutopilot(MAV_AUTOPILOT autopilotType,
                                                MAV_TYPE vehicleType) override;

private:
    USVArduPilotFirmwarePlugin *_arduPilotPlugin = nullptr;
    USVPX4FirmwarePlugin *_px4Plugin = nullptr;
};

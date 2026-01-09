/****************************************************************************
 *
 * USV Firmware Plugin - 无人船固件插件
 *
 * 同时支持 ArduPilot 和 PX4 固件
 * 针对无人船进行定制，过滤不适用的任务命令和飞行模式
 *
 ****************************************************************************/

#pragma once

#include "QGCMAVLink.h"
#include "FirmwarePlugin/APM/ArduRoverFirmwarePlugin.h"
#include "FirmwarePlugin/PX4/PX4FirmwarePlugin.h"

#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(USVFirmwarePluginLog)

/// @brief 无人船通用任务命令过滤
/// 提供静态方法，供 ArduPilot 和 PX4 插件共用
class USVMissionCommands
{
public:
    /// @brief 获取无人船适用的任务命令列表
    static QList<MAV_CMD> supportedCommands();
};

/*===========================================================================*/

/// @brief USV ArduPilot 固件插件
/// 基于 ArduRover 固件插件，针对无人船进行优化
class USVArduPilotFirmwarePlugin : public ArduRoverFirmwarePlugin
{
    Q_OBJECT

public:
    explicit USVArduPilotFirmwarePlugin(QObject *parent = nullptr);
    ~USVArduPilotFirmwarePlugin();

    // ========== FirmwarePlugin 覆盖 ==========

    QList<MAV_CMD> supportedMissionCommands(QGCMAVLink::VehicleClass_t vehicleClass) const override;
    QStringList flightModes(Vehicle *vehicle) const override;

    QString vehicleImageOpaque(const Vehicle *vehicle) const override;
    QString vehicleImageOutline(const Vehicle *vehicle) const override;
    QString brandImageIndoor(const Vehicle *vehicle) const override;
    QString brandImageOutdoor(const Vehicle *vehicle) const override;
};

/*===========================================================================*/

/// @brief USV PX4 固件插件
/// 基于 PX4 固件插件，针对无人船进行优化
class USVPX4FirmwarePlugin : public PX4FirmwarePlugin
{
    Q_OBJECT

public:
    explicit USVPX4FirmwarePlugin(QObject *parent = nullptr);
    ~USVPX4FirmwarePlugin();

    // ========== FirmwarePlugin 覆盖 ==========

    QList<MAV_CMD> supportedMissionCommands(QGCMAVLink::VehicleClass_t vehicleClass) const override;
    QStringList flightModes(Vehicle *vehicle) const override;

    QString vehicleImageOpaque(const Vehicle *vehicle) const override;
    QString vehicleImageOutline(const Vehicle *vehicle) const override;
    QString brandImageIndoor(const Vehicle *vehicle) const override;
    QString brandImageOutdoor(const Vehicle *vehicle) const override;
};

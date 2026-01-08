/****************************************************************************
 *
 * USV Firmware Plugin - 无人船固件插件
 *
 * 继承 ArduPilot Rover 固件插件，针对无人船进行定制
 * 过滤不适用的任务命令和飞行模式
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>

#include "FirmwarePlugin/APM/ArduRoverFirmwarePlugin.h"

Q_DECLARE_LOGGING_CATEGORY(USVFirmwarePluginLog)

/// @brief USV 专用固件插件
/// 基于 ArduRover 固件插件，针对无人船进行优化
class USVFirmwarePlugin : public ArduRoverFirmwarePlugin
{
    Q_OBJECT

public:
    explicit USVFirmwarePlugin(QObject *parent = nullptr);
    ~USVFirmwarePlugin();

    // ========== FirmwarePlugin 覆盖 ==========

    /// @brief 获取支持的任务命令列表
    /// 过滤掉不适用于无人船的命令
    QList<MAV_CMD> supportedMissionCommands(QGCMAVLink::VehicleClass_t vehicleClass) const override;

    /// @brief 获取可用飞行模式列表
    QStringList flightModes(Vehicle *vehicle) const override;

    /// @brief 是否支持负推力
    /// 无人船支持倒车
    bool supportsNegativeThrust(Vehicle *vehicle) const override { Q_UNUSED(vehicle); return true; }

    /// @brief 是否支持油门中位为零
    /// 无人船油门中位为停止
    bool supportsThrottleModeCenterZero() const override { return true; }

    /// @brief 是否支持无线电
    bool supportsRadio() const override { return true; }

    /// @brief 是否支持电机干扰校准
    /// 无人船通常不需要
    bool supportsMotorInterference() const override { return false; }

    /// @brief 获取载具图标 (不透明版本)
    QString vehicleImageOpaque(const Vehicle *vehicle) const override;

    /// @brief 获取载具图标 (轮廓版本)
    QString vehicleImageOutline(const Vehicle *vehicle) const override;

    /// @brief 获取品牌图片 (室内主题)
    QString brandImageIndoor(const Vehicle *vehicle) const override;

    /// @brief 获取品牌图片 (室外主题)
    QString brandImageOutdoor(const Vehicle *vehicle) const override;

    /// @brief 获取暂停飞行模式名称
    QString pauseFlightMode() const override { return QStringLiteral("Hold"); }

    /// @brief 获取任务飞行模式名称
    QString missionFlightMode() const override { return QStringLiteral("Auto"); }

    /// @brief 获取返航飞行模式名称
    QString rtlFlightMode() const override { return QStringLiteral("RTL"); }

    /// @brief 获取手动控制飞行模式名称
    QString takeControlFlightMode() const override { return QStringLiteral("Manual"); }

private:
    /// @brief 获取无人船适用的任务命令列表
    QList<MAV_CMD> _usvSupportedCommands() const;
};

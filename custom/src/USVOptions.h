/****************************************************************************
 *
 * USV Options - 无人船选项配置
 *
 * 控制 QGC 功能的可见性和行为
 * 禁用不适用于无人船的功能
 *
 ****************************************************************************/

#pragma once

#include "QGCOptions.h"

class USVPlugin;

/// @brief USV 专用飞行视图选项
/// 控制飞行视图中的 UI 元素和 Guided 操作
class USVFlyViewOptions : public QGCFlyViewOptions
{
    Q_OBJECT

public:
    explicit USVFlyViewOptions(QGCOptions *options, QObject *parent = nullptr);
    ~USVFlyViewOptions();

protected:
    // ========== QGCFlyViewOptions 覆盖 ==========

    /// @brief 显示多载具列表
    /// 无人船通常单独操作，但保留此功能以支持船队管理
    bool showMultiVehicleList() const override { return true; }

    /// @brief 显示仪表盘
    bool showInstrumentPanel() const override { return true; }

    /// @brief 显示地图比例尺
    bool showMapScale() const override { return true; }

    /// @brief 显示紧急停止按钮
    /// 关键安全功能，必须保留
    bool guidedBarShowEmergencyStop() const override { return true; }

    /// @brief 显示 Orbit 模式
    /// 无人船不需要空中盘旋，禁用
    bool guidedBarShowOrbit() const override { return false; }

    /// @brief 显示 ROI (Region of Interest)
    /// 无人船通常不需要云台 ROI 功能，禁用
    /// 如果你的无人船有云台，可以改为 true
    bool guidedBarShowROI() const override { return false; }
};

/*===========================================================================*/

/// @brief USV 专用选项配置
/// 控制整个应用的功能可见性
class USVOptions : public QGCOptions
{
    Q_OBJECT

public:
    explicit USVOptions(USVPlugin *plugin, QObject *parent = nullptr);
    ~USVOptions();

    // ========== QGCOptions 覆盖 ==========

    /// @brief 获取飞行视图选项
    const QGCFlyViewOptions *flyViewOptions() const override { return _flyViewOptions; }

    // ========== 传感器校准页面控制 ==========

    /// @brief 显示加速度计校准
    /// 无人船需要，保留
    bool showSensorCalibrationAccel() const override { return true; }

    /// @brief 显示空速计校准
    /// 无人船不需要空速计，禁用
    bool showSensorCalibrationAirspeed() const override { return false; }

    /// @brief 显示罗盘校准
    /// 无人船需要，保留
    bool showSensorCalibrationCompass() const override { return true; }

    /// @brief 显示陀螺仪校准
    /// 无人船需要，保留
    bool showSensorCalibrationGyro() const override { return true; }

    /// @brief 显示水平校准
    /// 无人船需要，保留
    bool showSensorCalibrationLevel() const override { return true; }

    // ========== 功能控制 ==========

    /// @brief 显示固件升级
    /// 仅在高级模式下显示
    bool showFirmwareUpgrade() const override;

    /// @brief 显示任务绝对高度
    /// 无人船在水面，不需要绝对高度显示
    bool showMissionAbsoluteAltitude() const override { return false; }

    /// @brief 显示 PX4 日志传输选项
    /// 保留日志功能用于调试
    bool showPX4LogTransferOptions() const override { return true; }

    /// @brief 显示简单任务启动
    bool showSimpleMissionStart() const override { return false; }

    /// @brief 任务仅允许航点
    /// false = 允许复杂任务项（如 Survey）
    /// 无人船可以使用 Survey 进行水域测量
    bool missionWaypointsOnly() const override { return false; }

    /// @brief 支持多载具
    /// 保留以支持船队管理
    bool multiVehicleEnabled() const override { return true; }

    /// @brief 显示离线地图导出
    bool showOfflineMapExport() const override { return true; }

    /// @brief 显示离线地图导入
    bool showOfflineMapImport() const override { return true; }

    // ========== 预飞检查清单 ==========

    /// @brief 自定义预飞检查清单 URL
    /// 使用无人船专用检查清单
    QUrl preFlightChecklistUrl() const override;

    // ========== 工具栏 ==========

    /// @brief 工具栏高度倍数
    double toolbarHeightMultiplier() const override { return 1.0; }

    /// @brief 显示任务状态
    bool showMissionStatus() const override { return true; }

private:
    USVPlugin *_plugin = nullptr;
    USVFlyViewOptions *_flyViewOptions = nullptr;
};

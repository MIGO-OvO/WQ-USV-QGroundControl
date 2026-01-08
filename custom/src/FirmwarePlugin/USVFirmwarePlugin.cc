/****************************************************************************
 *
 * USV Firmware Plugin Implementation - 无人船固件插件实现
 *
 ****************************************************************************/

#include "USVFirmwarePlugin.h"
#include "Vehicle.h"

#include <QtCore/QLoggingCategory>

QGC_LOGGING_CATEGORY(USVFirmwarePluginLog, "USV.FirmwarePlugin")

USVFirmwarePlugin::USVFirmwarePlugin(QObject *parent)
    : ArduRoverFirmwarePlugin(parent)
{
    qCDebug(USVFirmwarePluginLog) << "USVFirmwarePlugin created";
}

USVFirmwarePlugin::~USVFirmwarePlugin()
{
}

QList<MAV_CMD> USVFirmwarePlugin::supportedMissionCommands(QGCMAVLink::VehicleClass_t vehicleClass) const
{
    Q_UNUSED(vehicleClass);
    return _usvSupportedCommands();
}

QList<MAV_CMD> USVFirmwarePlugin::_usvSupportedCommands() const
{
    // 无人船适用的任务命令列表
    QList<MAV_CMD> commands;

    // ========== 导航命令 ==========
    commands << MAV_CMD_NAV_WAYPOINT;           // 航点导航
    commands << MAV_CMD_NAV_RETURN_TO_LAUNCH;   // 返回起点
    commands << MAV_CMD_NAV_LOITER_UNLIM;       // 无限期定点等待
    commands << MAV_CMD_NAV_LOITER_TIME;        // 定时定点等待
    commands << MAV_CMD_NAV_LOITER_TURNS;       // 绕圈等待 (可用于水面绕点)
    commands << MAV_CMD_NAV_SPLINE_WAYPOINT;    // 样条曲线航点 (平滑航线)
    commands << MAV_CMD_NAV_DELAY;              // 延时

    // ========== DO 命令 (执行动作) ==========
    commands << MAV_CMD_DO_SET_SPEED;           // 设置速度
    commands << MAV_CMD_DO_CHANGE_SPEED;        // 改变速度
    commands << MAV_CMD_DO_SET_HOME;            // 设置 Home 点
    commands << MAV_CMD_DO_SET_SERVO;           // 控制舵机
    commands << MAV_CMD_DO_REPEAT_SERVO;        // 重复舵机动作
    commands << MAV_CMD_DO_SET_RELAY;           // 控制继电器
    commands << MAV_CMD_DO_REPEAT_RELAY;        // 重复继电器动作
    commands << MAV_CMD_DO_SET_ROI_LOCATION;    // 设置 ROI 位置 (如果有云台)
    commands << MAV_CMD_DO_SET_ROI_NONE;        // 清除 ROI
    commands << MAV_CMD_DO_DIGICAM_CONTROL;     // 相机控制
    commands << MAV_CMD_DO_SET_CAM_TRIGG_DIST;  // 设置相机触发距离
    commands << MAV_CMD_DO_JUMP;                // 跳转到指定航点
    commands << MAV_CMD_DO_GRIPPER;             // 夹爪控制 (如果有)

    // ========== 条件命令 ==========
    commands << MAV_CMD_CONDITION_DELAY;        // 延时条件
    commands << MAV_CMD_CONDITION_DISTANCE;     // 距离条件
    commands << MAV_CMD_CONDITION_YAW;          // 航向条件

    // ========== 排除的命令 (不适用于无人船) ==========
    // MAV_CMD_NAV_TAKEOFF              - 起飞
    // MAV_CMD_NAV_LAND                 - 降落
    // MAV_CMD_NAV_VTOL_TAKEOFF         - VTOL 起飞
    // MAV_CMD_NAV_VTOL_LAND            - VTOL 降落
    // MAV_CMD_DO_VTOL_TRANSITION       - VTOL 过渡
    // MAV_CMD_NAV_ALTITUDE_WAIT        - 高度等待
    // MAV_CMD_DO_CHANGE_ALTITUDE       - 改变高度
    // MAV_CMD_CONDITION_ALTITUDE       - 高度条件

    qCDebug(USVFirmwarePluginLog) << "Supported mission commands count:" << commands.count();
    return commands;
}

QStringList USVFirmwarePlugin::flightModes(Vehicle *vehicle) const
{
    Q_UNUSED(vehicle);

    // 无人船适用的飞行模式
    QStringList modes;

    modes << QStringLiteral("Manual");      // 手动模式
    modes << QStringLiteral("Acro");        // 特技模式 (直接控制)
    modes << QStringLiteral("Steering");    // 转向模式
    modes << QStringLiteral("Hold");        // 保持模式 (定点)
    modes << QStringLiteral("Loiter");      // 悬停模式 (GPS 定点)
    modes << QStringLiteral("Auto");        // 自动模式 (执行任务)
    modes << QStringLiteral("RTL");         // 返航模式
    modes << QStringLiteral("SmartRTL");    // 智能返航
    modes << QStringLiteral("Guided");      // 引导模式
    modes << QStringLiteral("Simple");      // 简单模式

    // 排除不适用的模式:
    // - "Flip" - 翻转 (飞行器专用)
    // - "Circle" - 盘旋 (飞行器专用)
    // - "Drift" - 漂移 (飞行器专用)
    // - "Sport" - 运动模式 (飞行器专用)
    // - "AutoTune" - 自动调参 (需要飞行)

    return modes;
}

QString USVFirmwarePlugin::vehicleImageOpaque(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle);
    // 可以替换为无人船图标
    // 如果没有自定义图标，使用默认 Rover 图标
    return QStringLiteral("/qmlimages/Boat.svg");
}

QString USVFirmwarePlugin::vehicleImageOutline(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle);
    return QStringLiteral("/qmlimages/Boat.svg");
}

QString USVFirmwarePlugin::brandImageIndoor(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle);
    return QStringLiteral("/custom/img/usv-logo-white.svg");
}

QString USVFirmwarePlugin::brandImageOutdoor(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle);
    return QStringLiteral("/custom/img/usv-logo-black.svg");
}

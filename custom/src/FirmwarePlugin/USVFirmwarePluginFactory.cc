/****************************************************************************
 *
 * USV Firmware Plugin Factory Implementation - 无人船固件插件工厂实现
 *
 ****************************************************************************/

#include "USVFirmwarePluginFactory.h"
#include "USVFirmwarePlugin.h"

#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(USVFirmwarePluginLog)

USVFirmwarePluginFactory::USVFirmwarePluginFactory(QObject *parent)
    : FirmwarePluginFactory(parent)
{
    qCDebug(USVFirmwarePluginLog) << "USVFirmwarePluginFactory created";
}

USVFirmwarePluginFactory::~USVFirmwarePluginFactory()
{
    delete _usvFirmwarePlugin;
}

QList<QGCMAVLink::FirmwareClass_t> USVFirmwarePluginFactory::supportedFirmwareClasses() const
{
    // 支持 ArduPilot 和 PX4 固件
    // 但主要针对 ArduPilot (ArduRover) 优化
    return QList<QGCMAVLink::FirmwareClass_t>({
        QGCMAVLink::FirmwareClassArduPilot,
        QGCMAVLink::FirmwareClassPX4
    });
}

QList<QGCMAVLink::VehicleClass_t> USVFirmwarePluginFactory::supportedVehicleClasses(
    QGCMAVLink::FirmwareClass_t firmwareClass) const
{
    Q_UNUSED(firmwareClass);

    // 仅支持 Rover/Boat 类型
    // 这是 USV 定制构建的核心限制
    return QList<QGCMAVLink::VehicleClass_t>({
        QGCMAVLink::VehicleClassRoverBoat
    });
}

FirmwarePlugin *USVFirmwarePluginFactory::firmwarePluginForAutopilot(
    MAV_AUTOPILOT autopilotType,
    MAV_TYPE vehicleType)
{
    // 仅为 Rover/Boat 类型创建 USV 固件插件
    if (QGCMAVLink::isRoverBoat(vehicleType)) {
        if (!_usvFirmwarePlugin) {
            _usvFirmwarePlugin = new USVFirmwarePlugin(this);
        }
        qCDebug(USVFirmwarePluginLog) << "Created USVFirmwarePlugin for"
                                       << autopilotType << vehicleType;
        return _usvFirmwarePlugin;
    }

    // 其他载具类型返回 nullptr，使用默认插件
    qCWarning(USVFirmwarePluginLog) << "Unsupported vehicle type:" << vehicleType
                                     << "- USV build only supports Rover/Boat";
    return nullptr;
}

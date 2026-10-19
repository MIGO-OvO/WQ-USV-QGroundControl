/****************************************************************************
 *
 * USV Firmware Plugin Implementation - 无人船固件插件实现
 *
 * 同时支持 ArduPilot 和 PX4 固件
 *
 ****************************************************************************/

#include "USVFirmwarePlugin.h"
#include "Vehicle.h"

#include <QtCore/QLoggingCategory>

Q_LOGGING_CATEGORY(USVFirmwarePluginLog, "USV.FirmwarePlugin")

/*===========================================================================*/
// USVArduPilotFirmwarePlugin - ArduPilot 实现
/*===========================================================================*/

USVArduPilotFirmwarePlugin::USVArduPilotFirmwarePlugin(QObject *parent)
    : ArduRoverFirmwarePlugin(parent)
{
    qCDebug(USVFirmwarePluginLog) << "USVArduPilotFirmwarePlugin created";
}

USVArduPilotFirmwarePlugin::~USVArduPilotFirmwarePlugin()
{
}

QString USVArduPilotFirmwarePlugin::vehicleImageOpaque(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/qmlimages/Boat.svg");
}

QString USVArduPilotFirmwarePlugin::vehicleImageOutline(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/qmlimages/Boat.svg");
}

QString USVArduPilotFirmwarePlugin::brandImageIndoor(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/custom/img/usv-logo-white.png");
}

QString USVArduPilotFirmwarePlugin::brandImageOutdoor(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/custom/img/usv-logo-black.png");
}

QMap<QString, FactGroup*>* USVArduPilotFirmwarePlugin::factGroups()
{
    // Vehicle consumes this map once in _commonInit. Each vehicle owns its data.
    _nameToFactGroupMap["usvPayload"] = new USVPayloadFactGroup(this);
    return &_nameToFactGroupMap;
}

void USVArduPilotFirmwarePlugin::initializeVehicle(Vehicle *vehicle)
{
    ArduRoverFirmwarePlugin::initializeVehicle(vehicle);
    if (auto *payload = qobject_cast<USVPayloadFactGroup*>(vehicle->getFactGroup(QStringLiteral("usvPayload")))) {
        payload->setParent(vehicle);
        payload->setVehicleId(vehicle->id());
    }
}

/*===========================================================================*/
// USVPX4FirmwarePlugin - PX4 实现
/*===========================================================================*/

USVPX4FirmwarePlugin::USVPX4FirmwarePlugin(QObject *parent)
    : PX4FirmwarePlugin()
{
    setParent(parent);
    qCDebug(USVFirmwarePluginLog) << "USVPX4FirmwarePlugin created";
}

USVPX4FirmwarePlugin::~USVPX4FirmwarePlugin()
{
}

QString USVPX4FirmwarePlugin::vehicleImageOpaque(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/qmlimages/Boat.svg");
}

QString USVPX4FirmwarePlugin::vehicleImageOutline(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/qmlimages/Boat.svg");
}

QString USVPX4FirmwarePlugin::brandImageIndoor(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/custom/img/usv-logo-white.png");
}

QString USVPX4FirmwarePlugin::brandImageOutdoor(const Vehicle *vehicle) const
{
    Q_UNUSED(vehicle)
    return QStringLiteral("/custom/img/usv-logo-black.png");
}

QMap<QString, FactGroup*>* USVPX4FirmwarePlugin::factGroups()
{
    _nameToFactGroupMap["usvPayload"] = new USVPayloadFactGroup(this);
    return &_nameToFactGroupMap;
}

void USVPX4FirmwarePlugin::initializeVehicle(Vehicle *vehicle)
{
    PX4FirmwarePlugin::initializeVehicle(vehicle);
    if (auto *payload = qobject_cast<USVPayloadFactGroup*>(vehicle->getFactGroup(QStringLiteral("usvPayload")))) {
        payload->setParent(vehicle);
        payload->setVehicleId(vehicle->id());
    }
}

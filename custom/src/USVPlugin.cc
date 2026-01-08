/****************************************************************************
 *
 * USV (Unmanned Surface Vehicle) Custom Plugin Implementation
 * 无人船专用定制插件实现
 *
 ****************************************************************************/

#include "USVPlugin.h"
#include "USVOptions.h"

#include "QGCLoggingCategory.h"
#include "QGCPalette.h"
#include "QGCMAVLink.h"
#include "AppSettings.h"
#include "BrandImageSettings.h"
#include "FirmwareUpgradeSettings.h"
#include "Vehicle.h"

#include <QtCore/QApplicationStatic>
#include <QtQml/QQmlApplicationEngine>
#include <QtCore/QFile>

QGC_LOGGING_CATEGORY(USVPluginLog, "USV.Plugin")

Q_APPLICATION_STATIC(USVPlugin, _usvPluginInstance);

/*===========================================================================*/
// USVPlugin Implementation
/*===========================================================================*/

USVPlugin::USVPlugin(QObject *parent)
    : QGCCorePlugin(parent)
    , _usvOptions(new USVOptions(this, this))
{
    qCDebug(USVPluginLog) << "USVPlugin created";

    // 默认隐藏高级 UI
    _showAdvancedUI = false;

    connect(this, &QGCCorePlugin::showAdvancedUIChanged,
            this, &USVPlugin::_advancedChanged);
}

USVPlugin::~USVPlugin()
{
    qCDebug(USVPluginLog) << "USVPlugin destroyed";
}

QGCCorePlugin *USVPlugin::instance()
{
    return _usvPluginInstance();
}

void USVPlugin::init()
{
    qCInfo(USVPluginLog) << "USV Custom Plugin initialized - 无人船专用模式";
    QGCCorePlugin::init();
}

void USVPlugin::cleanup()
{
    if (_qmlEngine && _interceptor) {
        _qmlEngine->removeUrlInterceptor(_interceptor);
    }

    delete _interceptor;
    _interceptor = nullptr;

    QGCCorePlugin::cleanup();
}

QGCOptions *USVPlugin::options()
{
    return _usvOptions;
}

QString USVPlugin::brandImageIndoor() const
{
    // 可以替换为你的无人船品牌 Logo
    // 如果没有自定义图片，返回空字符串使用默认
    return QStringLiteral("/custom/img/usv-logo-white.svg");
}

QString USVPlugin::brandImageOutdoor() const
{
    return QStringLiteral("/custom/img/usv-logo-black.svg");
}

bool USVPlugin::overrideSettingsGroupVisibility(const QString &name)
{
    // 隐藏品牌图片设置 (已自定义)
    if (name == BrandImageSettings::name) {
        return false;
    }

    // 固件升级仅在高级模式下显示
    if (name == FirmwareUpgradeSettings::name) {
        return _showAdvancedUI;
    }

    return true;
}

void USVPlugin::adjustSettingMetaData(const QString &settingsGroup,
                                       FactMetaData &metaData,
                                       bool &visible)
{
    // 先调用父类方法
    QGCCorePlugin::adjustSettingMetaData(settingsGroup, metaData, visible);

    if (settingsGroup == AppSettings::settingsGroup) {
        const QString &name = metaData.name();

        // ========== 锁定载具类型为 Rover/Boat ==========
        if (name == QStringLiteral("offlineEditingVehicleClass")) {
            // MAV_TYPE_GROUND_ROVER = 10, 包含 Rover 和 Boat
            metaData.setRawDefaultValue(QGCMAVLink::VehicleClassRoverBoat);
            visible = false;  // 隐藏选择器，用户无法更改
            qCDebug(USVPluginLog) << "Locked vehicle class to RoverBoat";
            return;
        }

        // ========== 锁定固件类型为 ArduPilot (ArduRover) ==========
        if (name == QStringLiteral("offlineEditingFirmwareClass")) {
            // 使用 ArduPilot，因为 ArduRover 对无人船支持更好
            metaData.setRawDefaultValue(QGCMAVLink::FirmwareClassArduPilot);
            visible = false;
            qCDebug(USVPluginLog) << "Locked firmware class to ArduPilot";
            return;
        }

        // ========== 隐藏不适用于无人船的速度设置 ==========
        // 悬停速度 - 无人船不悬停
        if (name == QStringLiteral("offlineEditingHoverSpeed")) {
            visible = false;
            return;
        }

        // 上升速度 - 无人船不上升
        if (name == QStringLiteral("offlineEditingAscentSpeed")) {
            visible = false;
            return;
        }

        // 下降速度 - 无人船不下降
        if (name == QStringLiteral("offlineEditingDescentSpeed")) {
            visible = false;
            return;
        }

        // ========== 调整巡航速度默认值 ==========
        if (name == QStringLiteral("offlineEditingCruiseSpeed")) {
            // 无人船典型巡航速度 5 m/s (约 10 节)
            metaData.setRawDefaultValue(5.0);
            return;
        }

        // ========== 调整默认任务高度 ==========
        if (name == QStringLiteral("defaultMissionItemAltitude")) {
            // 无人船高度设为 0 (水面)
            metaData.setRawDefaultValue(0.0);
            return;
        }
    }
}

void USVPlugin::paletteOverride(const QString &colorName,
                                 QGCPalette::PaletteColorInfo_t &colorInfo)
{
    // 可选：自定义无人船主题颜色
    // 使用蓝色系代表水域

    if (colorName == QStringLiteral("brandingBlue")) {
        // 海洋蓝主题色
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#0077b6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#48cae4");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#0077b6");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#48cae4");
    } else if (colorName == QStringLiteral("colorGreen")) {
        // 安全/正常状态 - 保持绿色
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#2d9d78");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#2d9d78");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#2d9d78");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#2d9d78");
    }
}

QQmlApplicationEngine *USVPlugin::createQmlApplicationEngine(QObject *parent)
{
    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);

    // 添加 USV QML 模块导入路径
    _qmlEngine->addImportPath("qrc:/qml/USV");

    // 安装 URL 拦截器，用于替换默认 QML 文件
    _interceptor = new USVQmlOverrideInterceptor();
    _qmlEngine->addUrlInterceptor(_interceptor);

    return _qmlEngine;
}

const QVariantList &USVPlugin::analyzePages()
{
    // 使用默认分析页面
    return QGCCorePlugin::analyzePages();
}

const QVariantList &USVPlugin::toolBarIndicators()
{
    // 使用默认工具栏指示器
    return QGCCorePlugin::toolBarIndicators();
}

QList<int> USVPlugin::firstRunPromptStdIds()
{
    // 保留单位设置提示，移除离线载具选择提示（已锁定）
    return QList<int>({ kUnitsFirstRunPromptId });
}

QStringList USVPlugin::complexMissionItemNames(Vehicle *vehicle,
                                                const QStringList &complexMissionItemNames)
{
    Q_UNUSED(vehicle);

    QStringList filteredItems;

    for (const QString &item : complexMissionItemNames) {
        // 保留适用于无人船的复杂任务项
        if (item == QStringLiteral("Survey") ||           // 测量任务 - 可用于水域测量
            item == QStringLiteral("Corridor Scan")) {    // 走廊扫描 - 可用于河道巡检
            filteredItems.append(item);
        }
        // 排除:
        // - "Fixed Wing Landing" - 固定翼降落
        // - "VTOL Landing" - 垂直起降
        // - "Structure Scan" - 建筑扫描（需要高度变化）
    }

    qCDebug(USVPluginLog) << "Filtered complex mission items:" << filteredItems;
    return filteredItems;
}

void USVPlugin::_advancedChanged(bool advanced)
{
    Q_UNUSED(advanced);
    // 高级模式变化时，通知固件升级设置可见性变化
    emit _usvOptions->showFirmwareUpgradeChanged(advanced);
}

/*===========================================================================*/
// USVQmlOverrideInterceptor Implementation
/*===========================================================================*/

USVQmlOverrideInterceptor::USVQmlOverrideInterceptor()
    : QQmlAbstractUrlInterceptor()
{
}

QUrl USVQmlOverrideInterceptor::intercept(const QUrl &url,
                                           QQmlAbstractUrlInterceptor::DataType type)
{
    // 仅拦截 QML 文件
    if (type != QQmlAbstractUrlInterceptor::QmlFile &&
        type != QQmlAbstractUrlInterceptor::UrlString) {
        return url;
    }

    if (url.scheme() != QStringLiteral("qrc")) {
        return url;
    }

    const QString origPath = url.path();

    // 检查是否有 USV 定制版本
    const QString overridePath = QStringLiteral(":/USV%1").arg(origPath);

    if (QFile::exists(overridePath)) {
        QUrl result;
        result.setScheme(QStringLiteral("qrc"));
        result.setPath(QStringLiteral("/USV") + origPath);
        qCDebug(USVPluginLog) << "QML override:" << origPath << "->" << result.path();
        return result;
    }

    return url;
}

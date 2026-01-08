/****************************************************************************
 *
 * USV Options Implementation - 无人船选项配置实现
 *
 ****************************************************************************/

#include "USVOptions.h"
#include "USVPlugin.h"

#include <QtCore/QUrl>

/*===========================================================================*/
// USVFlyViewOptions Implementation
/*===========================================================================*/

USVFlyViewOptions::USVFlyViewOptions(QGCOptions *options, QObject *parent)
    : QGCFlyViewOptions(options, parent)
{
}

USVFlyViewOptions::~USVFlyViewOptions()
{
}

/*===========================================================================*/
// USVOptions Implementation
/*===========================================================================*/

USVOptions::USVOptions(USVPlugin *plugin, QObject *parent)
    : QGCOptions(parent)
    , _plugin(plugin)
    , _flyViewOptions(new USVFlyViewOptions(this, this))
{
    Q_CHECK_PTR(_plugin);
}

USVOptions::~USVOptions()
{
}

bool USVOptions::showFirmwareUpgrade() const
{
    // 仅在高级模式下显示固件升级
    return _plugin->showAdvancedUI();
}

QUrl USVOptions::preFlightChecklistUrl() const
{
    // 使用无人船专用预飞检查清单
    return QUrl::fromUserInput(QStringLiteral("qrc:/qml/USV/USVChecklist.qml"));
}

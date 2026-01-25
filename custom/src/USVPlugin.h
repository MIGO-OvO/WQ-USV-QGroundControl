/****************************************************************************
 *
 * USV (Unmanned Surface Vehicle) Custom Plugin
 * 无人船专用定制插件
 *
 * 基于 QGroundControl 的 Custom Build 机制
 * 仅针对无人船载具进行优化，禁用不需要的飞行器功能
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>
#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"

class USVOptions;
class QQmlApplicationEngine;
class QTranslator;

Q_DECLARE_LOGGING_CATEGORY(USVPluginLog)

/// @brief USV 专用核心插件
/// 继承 QGCCorePlugin，覆盖必要的方法以实现无人船定制
class USVPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit USVPlugin(QObject *parent = nullptr);
    ~USVPlugin();

    /// @brief 获取插件单例实例
    static QGCCorePlugin *instance();

    // ========== QGCCorePlugin 覆盖方法 ==========

    /// @brief 插件初始化
    void init() override;

    /// @brief 插件清理
    void cleanup() override;

    /// @brief 获取选项配置
    QGCOptions *options() override;

    /// @brief 室内主题品牌图片
    QString brandImageIndoor() const override;

    /// @brief 室外主题品牌图片
    QString brandImageOutdoor() const override;

    /// @brief 控制设置组的可见性
    /// @param name 设置组名称
    /// @return true: 显示, false: 隐藏
    bool overrideSettingsGroupVisibility(const QString &name) override;

    /// @brief 调整设置元数据
    /// 用于锁定载具类型为 Rover/Boat，隐藏不适用的设置
    void adjustSettingMetaData(const QString &settingsGroup,
                               FactMetaData &metaData,
                               bool &visible) override;

    /// @brief 自定义调色板
    void paletteOverride(const QString &colorName,
                         QGCPalette::PaletteColorInfo_t &colorInfo) override;

    /// @brief 创建 QML 应用引擎
    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) override;

    /// @brief 获取分析页面列表
    const QVariantList &analyzePages() override;

    /// @brief 获取工具栏指示器列表
    const QVariantList &toolBarIndicators() override;

    /// @brief 获取首次运行提示 ID 列表
    QList<int> firstRunPromptStdIds() override;

    /// @brief 获取复杂任务项名称列表
    /// 过滤掉不适用于无人船的任务类型
    QStringList complexMissionItemNames(Vehicle *vehicle,
                                        const QStringList &complexMissionItemNames) override;

private slots:
    void _advancedChanged(bool advanced);

private:
    /// @brief 加载 USV 专用翻译文件
    void _loadUSVTranslations();

    /// @brief 设置默认的 MAVLink Actions 文件
    void _setupDefaultMavlinkActions();

    USVOptions *_usvOptions = nullptr;
    QQmlApplicationEngine *_qmlEngine = nullptr;
    class USVQmlOverrideInterceptor *_interceptor = nullptr;
    QTranslator *_usvTranslator = nullptr;  ///< USV 专用翻译器
};

/*===========================================================================*/

/// @brief QML URL 拦截器
/// 用于将默认 QML 文件替换为 USV 定制版本
class USVQmlOverrideInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    USVQmlOverrideInterceptor();

    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) override;
};

// Included by verify_native_cockpit_boot.py around the unchanged application entry.
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QTimer>
#include <QtGui/QImage>
#include <QtQml/QQmlComponent>
#include <QtQml/QQmlContext>
#include <QtQml/QQmlExpression>
#include <QtQml/QJSValue>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickWindow>
#include "MultiVehicleManager.h"
#include "USVPayloadFactGroup.h"
#include "Vehicle.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include <limits>

static QString evidenceDirectory;
static void verifyNativeCockpit();
static QtMessageHandler previousMessageHandler = nullptr;
static void captureNativeMessage(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    QFile log(evidenceDirectory + "/native-qml.log");
    if (log.open(QIODevice::WriteOnly | QIODevice::Append)) {
        log.write(message.toUtf8() + '\n');
    }
    if (previousMessageHandler) previousMessageHandler(type, context, message);
}
static void installNativeMessageCapture()
{
    previousMessageHandler = qInstallMessageHandler(captureNativeMessage);
}

// APPLICATION_ENTRY

static QObject *objectProperty(QObject *object, const char *name)
{
    const QVariant value = object->property(name);
    return value.metaType() == QMetaType::fromType<QJSValue>() ? value.value<QJSValue>().toQObject() : value.value<QObject*>();
}

static QVariant evaluate(QObject *scope, const QString &source, QObject *confirmedVehicle = nullptr)
{
    QQmlContext context(qmlContext(scope));
    context.setContextProperty("qaConfirmedVehicle", confirmedVehicle);
    QQmlExpression expression(&context, scope, source);
    const QVariant result = expression.evaluate();
    if (expression.hasError())
        qFatal("Native cockpit expression: %s", qPrintable(expression.error().toString()));
    return result;
}

static QQuickItem *findVisualItem(QQuickItem *parent, const QString &name)
{
    if (parent->objectName() == name) return parent;
    for (QQuickItem *child : parent->childItems()) {
        if (auto *match = findVisualItem(child, name)) return match;
    }
    return nullptr;
}

static void verifyNativeCockpit()
{
    QJsonArray checks;
    bool passed = true;
    const auto check = [&](bool value, const QString &description) {
        checks.append(QJsonObject{{"pass", value}, {"description", description}});
        if (!value) { passed = false; qWarning() << "Cockpit check failed:" << description; }
    };
    QQuickWindow *window = nullptr;
    QQuickItem *task = nullptr;
    for (QWindow *candidate : QGuiApplication::topLevelWindows()) {
        auto *quick = qobject_cast<QQuickWindow*>(candidate);
        if (quick && quick->contentItem()) {
            task = findVisualItem(quick->contentItem(), "usvCurrentTaskPanel");
            if (task) { window = quick; break; }
        }
    }
    check(window && task, "Full QGC MainWindow loads the resource-intercepted native cockpit");
    if (window && task) {
        window->resize(1280, 720);
        QEventLoop renderWait;
        QTimer::singleShot(200, &renderWait, &QEventLoop::quit);
        renderWait.exec();
        check(window->grabWindow().save(evidenceDirectory + "/qgc-offline.png"), "Full QGC offline window captured");
        QQuickItem *layer = task->parentItem();
        QQuickItem *toolbar = findVisualItem(window->contentItem(), "usvFlyViewToolBar");
        const qreal toolbarHeight = toolbar ? toolbar->height() : 0;
        check(toolbar && toolbarHeight < 110, "Cockpit toolbar occupies a single row at 1280x720");
        QQuickItem *menu = findVisualItem(window->contentItem(), "usvPageMenuButton");
        check(menu && menu->isVisible() && menu->width() > 0, "Visible icon keeps page navigation accessible");
        auto *transparency = SettingsManager::instance()->appSettings()->usvBackgroundTransparency();
        check(transparency->rawValue().toInt() == 50, "Background transparency defaults to 50 percent");
        for (const int percent : {0, 25, 50, 100}) {
            transparency->setRawValue(percent);
            QCoreApplication::processEvents();
            const QColor panel = task->property("color").value<QColor>();
            check(qAbs(panel.alphaF() - (1.0 - percent / 100.0)) < 0.01 && task->opacity() == 1,
                  QString("Background alpha changes without fading foreground: %1 percent").arg(percent));
        }
        transparency->setRawValue(50);
        QSettings saved;
        saved.sync();
        check(saved.value("usvBackgroundTransparency").toInt() == 50, "Background transparency persists in isolated settings");
        QObject *guided = objectProperty(layer, "_guidedController");
        QObject *controller = objectProperty(layer, "controller");
        check(guided && controller, "Native GuidedActionsController and cockpit safety controller are connected");
        if (guided && controller) {
            auto *engine = qmlEngine(layer);
            QQmlComponent settingsPage(engine, QUrl("qrc:/qml/QGroundControl/AppSettings/GeneralSettings.qml"));
            QObject *settingsItem = settingsPage.create(qmlContext(layer));
            check(settingsItem != nullptr, "General settings loads the editable transparency Fact");
            // Fact controls finish initialization via Qt.callLater; keep the page
            // alive until shutdown rather than destroying pending bindings.
            if (settingsItem) settingsItem->setParent(layer);
            QQmlComponent component(engine, QUrl::fromLocalFile(qEnvironmentVariable("USV_QA_MOCK_FILE")));
            QObject *mock = component.create();
            check(mock != nullptr, "Simulated vehicle created without opening a vehicle link");
            if (mock) {
                mock->setParent(layer);
                layer->setProperty("activeVehicle", QVariant::fromValue(mock));
                guided->setProperty("_activeVehicle", QVariant::fromValue(mock));
                QObject *confirm = objectProperty(guided, "confirmDialog");
                check(confirm && !confirm->property("visible").toBool(), "Original GuidedActionConfirm starts hidden");
                evaluate(guided, "confirmAction(actionSetFlightMode, 'Hold')");
                check(confirm && confirm->property("visible").toBool(), "Original confirmation opens and accesses the restored message timers");
                check(confirm && objectProperty(confirm, "targetVehicle") == mock, "Original confirmation captures the selected vehicle");
                QCoreApplication::processEvents();
                QQuickItem *strip = findVisualItem(window->contentItem(), "flyViewToolStrip");
                check(strip != nullptr, "Native tool strip is available for expansion regression");
                if (strip) {
                    const qreal closedTaskX = task->x();
                    guided->setProperty("showChangeSpeed", true);
                    evaluate(strip, "simulateClick(6)");
                    QCoreApplication::processEvents();
                    QObject *drop = objectProperty(strip, "_dropPanel");
                    check(drop && drop->property("visible").toBool(), "Native action menu opens");
                    check(!task->isVisible() || task->x() >= strip->x() + drop->property("occupiedWidth").toReal(), "Expanded actions and task information do not overlap");
                    auto *message = findVisualItem(window->contentItem(), "usvConfirmationMessage");
                    const qreal taskRight = task->mapToItem(window->contentItem(), QPointF(task->width(), 0)).x();
                    check(message && (!task->isVisible() || message->mapToItem(window->contentItem(), QPointF()).x() >= taskRight), "Confirmation explanation also avoids the displaced task panel");
                    window->grabWindow().save(evidenceDirectory + "/qgc-actions-expanded.png");
                    evaluate(strip, "_dropPanel.hide()");
                    QCoreApplication::processEvents();
                    check(task->isVisible() && qAbs(task->x() - closedTaskX) < 1, "Task position restores after closing actions");
                }
                if (auto *confirmItem = qobject_cast<QQuickItem*>(confirm)) {
                    const qreal bottom = confirmItem->mapToItem(window->contentItem(), QPointF(0, confirmItem->height())).y();
                    const qreal taskTop = task->mapToItem(window->contentItem(), QPointF()).y();
                    check(taskTop >= bottom && toolbar && toolbar->height() == toolbarHeight, "Native confirmation stays in the toolbar row without pushing down the map");
                }
                QObject *other = component.create();
                check(other != nullptr, "Second simulated vessel can test the native confirmation target");
                if (other) {
                    other->setParent(layer);
                    other->setProperty("id", 2);
                    layer->setProperty("activeVehicle", QVariant::fromValue(other));
                    guided->setProperty("_activeVehicle", QVariant::fromValue(other));
                    check(confirm && !confirm->property("visible").toBool(), "Switching vessels cancels the original native confirmation");
                    evaluate(guided, "executeAction(actionSetFlightMode, 'Hold', 0, false, qaConfirmedVehicle)", mock);
                    check(other->property("flightMode").toString() == "Auto", "Stale native confirmation cannot change the newly selected vessel");
                    evaluate(guided, "executeAction(actionSetFlightMode, 'Hold', 0, false)");
                    check(other->property("flightMode").toString() == "Hold", "Direct native actions remain available without a stale confirmation context");
                    layer->setProperty("activeVehicle", QVariant::fromValue(mock));
                    guided->setProperty("_activeVehicle", QVariant::fromValue(mock));
                    evaluate(guided, "confirmAction(actionSetFlightMode, 'Hold')");
                }
                evaluate(guided, "executeAction(actionEmergencyStop, null, 0, false)");
                check(controller->property("safetyLocked").toBool(), "Native emergency action activates the cockpit latch");
                check(mock->property("emergencyCalls").toInt() == 1 && mock->property("lastCommand").toInt() == 31011 && mock->property("lastComponent").toInt() == 191, "Native emergency routes both stops to simulated propulsion and payload");
                check(confirm && !confirm->property("visible").toBool(), "Emergency cancels the original confirmation control");
                evaluate(guided, "confirmAction(actionSetFlightMode, 'Auto')");
                check(confirm && !confirm->property("visible").toBool(), "Locked native mode change cannot open confirmation");
                evaluate(guided, "executeAction(actionStartMission, null, 0, false)");
                check(mock->property("missionCalls").toInt() == 0, "Locked native execute path cannot start the simulated vessel");
                evaluate(mock, "mavCommandResult(1, 1, 400, 0, 0); mavCommandResult(1, 191, 31011, 0, 0)");
                check(controller->property("emergencyPhase").toString() == "accepted" && controller->property("safetyLocked").toBool(), "Accepted native stop ACKs retain actual-stop verification latch");
                evaluate(guided, "executeAction(actionDisarm, null, 0, false)");
                check(!mock->property("armed").toBool(), "Locked native disarm remains available");
                QObject *mainStatus = findVisualItem(window->contentItem(), "usvMainStatusIndicator");
                check(mainStatus != nullptr, "Original MainStatusIndicator is retained");
                if (mainStatus) {
                    mainStatus->setProperty("_activeVehicle", QVariant::fromValue(mock));
                    mainStatus->setProperty("armingAllowed", false);
                    evaluate(mainStatus, "requestArm(false); requestArm(true)");
                    check(!mock->property("armed").toBool(), "Main status drawer Arm and Force Arm obey the safety guard");
                }
            } else {
                qWarning() << component.errors();
            }
        }
    }
    Vehicle *offlineVehicle = MultiVehicleManager::instance()->offlineEditingVehicle();
    check(offlineVehicle && offlineVehicle->isOfflineEditingVehicle(), "C++ checks use only the disconnected editing vehicle");
    if (offlineVehicle) {
        int denied = 0;
        const auto connection = QObject::connect(offlineVehicle, &Vehicle::mavCommandResult, offlineVehicle,
            [&](int, int, int, int result, int) { if (result == MAV_RESULT_DENIED) ++denied; });
        offlineVehicle->setUsvSafetyLocked(true);
        offlineVehicle->sendMavCommand(1, MAV_CMD_COMPONENT_ARM_DISARM, false, 1);
        offlineVehicle->sendMavCommand(1, MAV_CMD_MISSION_START, false);
        offlineVehicle->sendMavCommand(191, static_cast<MAV_CMD>(31010), false);
        check(denied == 3, "Vehicle-level latch rejects arm, mission start and payload start before transport");
        offlineVehicle->sendMavCommand(1, MAV_CMD_COMPONENT_ARM_DISARM, false, 0);
        offlineVehicle->sendMavCommand(191, static_cast<MAV_CMD>(31011), false);
        check(denied == 3, "Vehicle-level latch leaves disarm and payload stop permitted");
        offlineVehicle->setUsvSafetyLocked(false);
        QObject::disconnect(connection);

        USVPayloadFactGroup facts;
        facts.setVehicleId(42);
        bool freshSawUpdatedValue = false;
        QObject::connect(&facts, &USVPayloadFactGroup::freshnessChanged, &facts, [&]() {
            freshSawUpdatedValue = facts.freshFields().contains("voltage") && qAbs(facts.voltage()->rawValue().toDouble() - 1.842) < 0.001;
        });
        mavlink_message_t message = {};
        const char field[10] = "USV_VOLT";
        mavlink_msg_named_value_float_pack(42, 191, &message, 0, field, 1.842f);
        facts.handleMessage(offlineVehicle, message);
        check(freshSawUpdatedValue, "Freshness notification observes the new Fact value, not the preceding sample");
        mavlink_msg_named_value_float_pack(43, 191, &message, 0, field, 9.0f);
        facts.handleMessage(offlineVehicle, message);
        mavlink_msg_named_value_float_pack(42, 191, &message, 0, field, std::numeric_limits<float>::quiet_NaN());
        facts.handleMessage(offlineVehicle, message);
        check(qAbs(facts.voltage()->rawValue().toDouble() - 1.842) < 0.001, "Other systems and non-finite samples cannot overwrite the valid Fact");
    }
    const QSettings settings;
    check(QDir::cleanPath(settings.fileName()).startsWith(evidenceDirectory + "/settings/"), "User application settings are isolated inside the QA directory");
    QFile report(evidenceDirectory + "/native-boot-evidence.json");
    if (report.open(QIODevice::WriteOnly))
        report.write(QJsonDocument(QJsonObject{{"passed", passed}, {"qt", QT_VERSION_STR}, {"checks", checks}, {"settings", settings.fileName()}}).toJson());
    QCoreApplication::exit(passed ? 0 : 2);
}

int main(int argc, char *argv[])
{
    evidenceDirectory = QDir::cleanPath(qEnvironmentVariable("USV_QA_OUTPUT"));
    if (evidenceDirectory.isEmpty()) return 3;
    QDir().mkpath(evidenceDirectory + "/settings");
    QFile::remove(evidenceDirectory + "/native-qml.log");
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, evidenceDirectory + "/settings");
    QSettings::setPath(QSettings::IniFormat, QSettings::SystemScope, evidenceDirectory + "/settings-system");
    QStandardPaths::setTestModeEnabled(true);
    for (const QString &name : {QStringLiteral("QGroundControl"), QStringLiteral("QGroundControl Daily")}) {
        QSettings settings(QSettings::IniFormat, QSettings::UserScope, "QGroundControl", name);
        settings.setValue("SettingsVersion", 9);
        settings.setValue("savePath", evidenceDirectory + "/data");
        settings.setValue("firstRunPromptIdsShown", "1,2,3,4,5,6,7,8,9,10");
        for (const QString &key : {QStringLiteral("autoConnectUDP"), QStringLiteral("autoConnectPixhawk"), QStringLiteral("autoConnectSiKRadio"), QStringLiteral("autoConnectRTKGPS"), QStringLiteral("autoConnectLibrePilot"), QStringLiteral("autoConnectZeroConf")})
            settings.setValue("AutoConnect/" + key, false);
        settings.setValue("AutoConnect/autoConnectNmeaPort", "Disabled");
        settings.sync();
    }
    return qgcBootEntry(argc, argv);
}

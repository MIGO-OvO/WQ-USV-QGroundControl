/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SendMavCommandWithSignallingTest.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QLockFile>
#include <QtCore/QScopeGuard>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QUuid>
#include <QtQml/QJSValue>
#include <QtQml/QQmlComponent>
#include <QtQml/QQmlContext>
#include <QtQml/QQmlEngine>
#include <QtTest/QSignalSpy>
#include <QtTest/QTest>

#include <memory>

#include "../../custom/src/USVPayloadFactGroup.h"
#include "MockLink.h"
#include "MultiVehicleManager.h"

namespace {
QList<QByteArray> payloadEventFrames(const QJsonObject& event, int systemId)
{
    QList<QByteArray> frames;
    const QByteArray text = "USVE1:" + QJsonDocument(event).toJson(QJsonDocument::Compact) + '\0';
    static uint16_t chunkId = 77;
    ++chunkId;
    for (int offset = 0; offset < text.size(); offset += 50) {
        char chunk[50]{};
        memcpy(chunk, text.constData() + offset, qMin(qsizetype(50), text.size() - offset));
        mavlink_message_t message{};
        mavlink_msg_statustext_pack(systemId, 191, &message, MAV_SEVERITY_NOTICE, chunk, chunkId, offset / 50);
        uint8_t bytes[MAVLINK_MAX_PACKET_LEN]{};
        const uint16_t size = mavlink_msg_to_send_buffer(bytes, &message);
        frames.append(QByteArray(reinterpret_cast<const char*>(bytes), size));
    }
    return frames;
}

void deliverPayloadFrames(USVPayloadFactGroup& facts, Vehicle* vehicle, const QList<QByteArray>& frames)
{
    mavlink_message_t buffer{}, message{};
    mavlink_status_t status{}, decoded{};
    for (const QByteArray& frame : frames) {
        for (const uint8_t byte : frame) {
            if (mavlink_frame_char_buffer(&buffer, &status, byte, &message, &decoded) == MAVLINK_FRAMING_OK)
                facts.handleMessage(vehicle, message);
        }
    }
}
}  // namespace

void SendMavCommandWithSignallingTest::_payloadProgressLifecycle()
{
    _connectMockLinkNoInitialConnectSequence();
    Vehicle* vehicle = MultiVehicleManager::instance()->activeVehicle();
    const QString originalName = QCoreApplication::applicationName();
    QCoreApplication::setApplicationName("payload-lifecycle-" + QUuid::createUuid().toString(QUuid::WithoutBraces));
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const auto restore = qScopeGuard([&] {
        QDir(directory).removeRecursively();
        QCoreApplication::setApplicationName(originalName);
        _disconnectMockLink();
    });
    USVPayloadFactGroup facts;
    facts.setVehicleId(vehicle->id());
    connect(&facts, &USVPayloadFactGroup::payloadEventReceived, vehicle, &Vehicle::payloadCommandReceipt);
    const auto value = [&](const char* name, float number) {
        mavlink_message_t message{};
        char field[10]{};
        memcpy(field, name, qMin(size_t(10), strlen(name)));
        mavlink_msg_named_value_float_pack(vehicle->id(), 191, &message, 0, field, number);
        facts.handleMessage(vehicle, message);
    };
    value("USV_PROTO", 1);
    value("USV_STAT", 0);
    value("USV_VLD", 1);
    value("USV_BSET", 1);
    value("USV_VOLT", 1.8f);
    QQmlEngine engine;
    engine.addImportPath("qrc:/qml");
    QQmlEngine::setObjectOwnership(vehicle, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(&facts, QQmlEngine::CppOwnership);
    engine.rootContext()->setContextProperty("testVehicle", vehicle);
    engine.rootContext()->setContextProperty("testFacts", &facts);
    QQmlComponent component(&engine, QUrl::fromLocalFile(QFINDTESTDATA("USVPayloadLifecycleFixture.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));
    std::unique_ptr<QObject> fixture(component.create());
    QVERIFY2(fixture, qPrintable(component.errorString()));
    QObject* commands = fixture->property("commands").value<QObject*>();
    QObject* panel = fixture->property("taskPanel").value<QObject*>();
    QVERIFY(commands);
    QVERIFY(panel);
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "startSample"));
    auto request = [&]() { return commands->property("request").value<QJSValue>().toVariant().toMap(); };
    QCOMPARE(request().value("session").toInt(), 1);
    QCOMPARE(request().value("request").toInt(), 1);
    value("USV_STAT", 1);
    QVERIFY(request().value("observed").toBool());

    QJsonObject event{{"v", 1},
                      {"session", 1},
                      {"request", 1},
                      {"tcp_session", 1},
                      {"command", 31010},
                      {"sender_system", 255},
                      {"sender_component", 190},
                      {"seq", 2},
                      {"phase", "progress"},
                      {"outcome", ""},
                      {"reason", ""},
                      {"state", "running"},
                      {"attempt_id", "11111111111111111111111111111111"},
                      {"preflight_phase", "homing"}};
    QList<QByteArray> frames;
    const QString external = qEnvironmentVariable("USV_QA_EVENT_FRAMES");
    qInfo("Payload lifecycle wire source: %d/191; fixture: %s", vehicle->id(),
          qPrintable(external.isEmpty() ? QStringLiteral("native MAVLink pack") : external));
    if (!external.isEmpty()) {
        // Generate the external CRC-valid fixture for the logged MockLink sysid.
        // The standalone class is the cross-end QA entry point; no ID rewriting.
        QFile input(external);
        QVERIFY(input.open(QIODevice::ReadOnly));
        const QJsonArray encoded = QJsonDocument::fromJson(input.readAll()).object().value("frames").toArray();
        QVERIFY(!encoded.isEmpty());
        for (const QJsonValue& frame : encoded) {
            const QByteArray bytes = QByteArray::fromHex(frame.toString().toLatin1());
            QVERIFY(!bytes.isEmpty());
            frames.append(bytes);
        }
    } else
        frames = payloadEventFrames(event, vehicle->id());
    QSignalSpy received(&facts, &USVPayloadFactGroup::payloadEventReceived);
    deliverPayloadFrames(facts, vehicle, frames);
    QCOMPARE(received.count(), 1);
    QCOMPARE(received.first()[0].toMap().value("outcome").toString(), QString());
    QVERIFY(!commands->property("busy").toBool());
    QVERIFY(!request().value("unknown").toBool());
    QVERIFY(!request().value("accepted").toBool());
    QVERIFY(!request().value("terminal").isValid() || request().value("terminal").isNull());
    QVERIFY(!vehicle->usvSafetyLocked());
    QCOMPARE(panel->property("taskTitle").toString(), QStringLiteral("手动点采样"));
    QCOMPARE(panel->property("phaseIndex").toInt(), 1);
    QCOMPARE(panel->property("preflightText").toString(), QStringLiteral("泵组回零"));
    auto* phase = panel->findChild<QObject*>("usvTaskPhase");
    QVERIFY(phase);
    QVERIFY(phase->property("text").toString().contains(QStringLiteral("泵组回零")));

    event["seq"] = 3;
    event["preflight_phase"] = "complete";
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    QCOMPARE(panel->property("phaseIndex").toInt(), 2);
    QCOMPARE(panel->property("observedStages").value<QJSValue>().toVariant().toList(), QVariantList({1, 2}));
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "pauseSample"));
    value("USV_STAT", 11);
    QJsonObject pause = event;
    pause["request"] = request().value("request").toInt();
    pause["command"] = 31012;
    pause["seq"] = 1;
    pause["phase"] = "request";
    pause["outcome"] = "accepted";
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(pause, vehicle->id()));
    QCOMPARE(phase->property("text").toString(), QStringLiteral("已暂停"));
    event["seq"] = 4;
    event["phase"] = "terminal";
    event["outcome"] = "failed";
    event["reason"] = "spectrometer_saturated";
    event["cleanup_failed"] = true;
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    QVERIFY(vehicle->usvSafetyLocked());
    QVERIFY(commands->property("feedback").toString().contains("spectrometer_saturated"));
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "confirmStopped"));
    value("USV_STAT", 0);
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "startSurvey"));
    event["request"] = request().value("request").toInt();
    event["command"] = 31015;
    event["seq"] = 1;
    event["phase"] = "progress";
    event["outcome"] = "";
    event["reason"] = "";
    event["cleanup_failed"] = false;
    event["attempt_id"] = "22222222222222222222222222222222";
    value("USV_STAT", 14);
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    QCOMPARE(panel->property("taskTitle").toString(), QStringLiteral("走航检测"));
    QCOMPARE(panel->property("observedStages").value<QJSValue>().toVariant().toList(), QVariantList() << 2);
    event["seq"] = 2;
    event["phase"] = "terminal";
    event["outcome"] = "succeeded";
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    event["seq"] = 3;
    event["phase"] = "progress";
    event["outcome"] = "";
    event["attempt_id"] = "33333333333333333333333333333333";
    event["preflight_phase"] = "injection";
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    QCOMPARE(panel->property("phaseIndex").toInt(), 1);
    QCOMPARE(panel->property("preflightText").toString(), QStringLiteral("进样准备"));
    QCOMPARE(panel->property("observedStages").value<QJSValue>().toVariant().toList(), QVariantList() << 1);

    // Two native Vehicles exercise captured-object ownership, not just IDs.
    QPointer<MockLink> otherLink = MockLink::startNoInitialConnectMockLink(false);
    const int otherId = otherLink->vehicleId();
    const auto removeOther = qScopeGuard([&] {
        if (otherLink)
            otherLink->disconnect();
        QTRY_VERIFY(!MultiVehicleManager::instance()->getVehicleById(otherId));
    });
    QTRY_VERIFY(MultiVehicleManager::instance()->getVehicleById(otherId));
    Vehicle* otherVehicle = MultiVehicleManager::instance()->getVehicleById(otherId);
    QQmlEngine::setObjectOwnership(otherVehicle, QQmlEngine::CppOwnership);
    USVPayloadFactGroup otherFacts;
    otherFacts.setVehicleId(otherId);
    QQmlEngine::setObjectOwnership(&otherFacts, QQmlEngine::CppOwnership);
    QObject* operations = fixture->property("operations").value<QObject*>();
    QVERIFY(operations);
    QVERIFY(operations->setProperty("payload", QVariant::fromValue(&otherFacts)));
    QVERIFY(operations->setProperty("vehicle", QVariant::fromValue(otherVehicle)));
    QVERIFY(vehicle->usvSafetyLocked());
    QVERIFY(!otherVehicle->usvSafetyLocked());
    QCOMPARE(commands->property("activeTask").value<QJSValue>().toVariant().isNull(), true);
    const QString switchedFeedback = commands->property("feedback").toString();
    event["seq"] = 5;
    event["phase"] = "terminal";
    event["outcome"] = "failed";
    event["cleanup_failed"] = true;
    event["reason"] = "old_vehicle_failure";
    deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    QCOMPARE(commands->property("feedback").toString(), switchedFeedback);
    QVERIFY(!otherVehicle->usvSafetyLocked());
    const int before = received.count();
    QSignalSpy otherReceived(&otherFacts, &USVPayloadFactGroup::payloadEventReceived);
    deliverPayloadFrames(otherFacts, otherVehicle, payloadEventFrames(event, vehicle->id()));
    QCOMPARE(received.count(), before);
    QCOMPARE(otherReceived.count(), 0);
    QVERIFY(!otherVehicle->usvSafetyLocked());
}

void SendMavCommandWithSignallingTest::_payloadCommunicationRecovery()
{
    _connectMockLinkNoInitialConnectSequence();
    auto* vehicle = MultiVehicleManager::instance()->activeVehicle();
    vehicle->setUsvSafetyLocked(false);
    const auto restore = qScopeGuard([&] {
        vehicle->setUsvSafetyLocked(false);
        _disconnectMockLink();
    });
    USVPayloadFactGroup facts;
    facts.setVehicleId(vehicle->id());
    connect(&facts, &USVPayloadFactGroup::payloadEventReceived, vehicle, &Vehicle::payloadCommandReceipt);
    const auto value = [&](const char* name, float number) {
        mavlink_message_t message{};
        char field[10]{};
        memcpy(field, name, qMin(size_t(10), strlen(name)));
        mavlink_msg_named_value_float_pack(vehicle->id(), 191, &message, 0, field, number);
        facts.handleMessage(vehicle, message);
    };
    value("USV_PROTO", 1);
    value("USV_STAT", 0);
    value("USV_VLD", 1);
    value("USV_BSET", 1);
    value("USV_VOLT", 1.8f);
    QQmlEngine engine;
    engine.addImportPath("qrc:/qml");
    QQmlEngine::setObjectOwnership(vehicle, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(&facts, QQmlEngine::CppOwnership);
    engine.rootContext()->setContextProperty("testVehicle", vehicle);
    engine.rootContext()->setContextProperty("testFacts", &facts);
    QQmlComponent component(&engine, QUrl::fromLocalFile(QFINDTESTDATA("USVPayloadLifecycleFixture.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));
    std::unique_ptr<QObject> fixture(component.create());
    QVERIFY2(fixture, qPrintable(component.errorString()));
    auto* commands = fixture->property("commands").value<QObject*>();
    auto* cockpit = fixture->property("cockpit").value<QObject*>();
    auto* operations = fixture->property("operations").value<QObject*>();
    QVERIFY(commands && cockpit && operations);
    const auto accepted = [&]() {
        const QVariantMap request = commands->property("request").value<QJSValue>().toVariant().toMap();
        QJsonObject event{{"v", 1},
                          {"tcp_session", 1},
                          {"seq", 1},
                          {"phase", "request"},
                          {"outcome", "accepted"},
                          {"reason", ""},
                          {"attempt_id", ""},
                          {"preflight_phase", ""}};
        for (const QString& key : {"session", "request", "command", "sender_system", "sender_component"})
            event[key] = QJsonValue::fromVariant(request.value(key));
        mavlink_message_t ack{};
        mavlink_msg_command_ack_pack(vehicle->id(), 191, &ack, request.value("command").toInt(), MAV_RESULT_ACCEPTED, 0,
                                     0, 255, 190);
        vehicle->_handleCommandAck(ack);
        deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id()));
    };
    vehicle->_updateArmed(true);
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "startSample"));
    accepted();
    QVERIFY(!commands->property("busy").toBool());
    value("USV_STAT", 1);
    QVERIFY(operations->setProperty("connected", false));
    QCOMPARE(vehicle->usvSafetyLockSource(), QStringLiteral("communication"));
    QCOMPARE(cockpit->property("emergencyPhase").toString(), QStringLiteral("communication"));
    QVERIFY(operations->setProperty("connected", true));
    value("USV_STAT", 0);
    QVERIFY(vehicle->usvSafetyLocked());  // reconnect + Idle are insufficient
    QVERIFY(!cockpit->property("canVerifyStop").toBool());
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "stopDetector"));
    accepted();
    value("USV_ADS", 1);
    value("USV_STAT", 0);
    QVERIFY(vehicle->usvSafetyLocked());  // ADS-only is insufficient
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "stopSample"));
    accepted();
    QVERIFY(!commands->property("busy").toBool());
    QVERIFY(vehicle->usvSafetyLocked());  // pre-result Idle is insufficient
    value("USV_STAT", 0);
    QVERIFY(!vehicle->usvSafetyLocked());
    QVERIFY(vehicle->armed());
    QVERIFY(!cockpit->property("safetyLocked").toBool());
    QVERIFY(commands->property("activeTask").value<QJSValue>().toVariant().isNull());
    QVERIFY(commands->property("request").value<QJSValue>().toVariant().isNull());
    QVERIFY(!vehicle->isMavCommandPending(191, 31011));
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "startSample"));
    QVERIFY(vehicle->isMavCommandPending(191, 31010));  // C++ gate really reopened
    accepted();
    // A payload-only outage does not invent a whole-link failure.
    QVERIFY(operations->setProperty("payloadOnline", false));
    QVERIFY(!vehicle->usvSafetyLocked());
    QVERIFY(operations->setProperty("payloadOnline", true));
    vehicle->setUsvSafetyLockSource("emergency");
    QVERIFY(operations->setProperty("connected", false));
    QCOMPARE(vehicle->usvSafetyLockSource(), QStringLiteral("emergency"));
    QVERIFY(operations->setProperty("connected", true));
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "stopSample"));
    accepted();
    value("USV_STAT", 0);
    QVERIFY(vehicle->usvSafetyLocked());
    QVERIFY(cockpit->property("safetyLocked").toBool());
    QVERIFY(!cockpit->property("canVerifyStop").toBool());  // still armed
}

void SendMavCommandWithSignallingTest::_payloadRequestIdentity()
{
    const QString originalName = QCoreApplication::applicationName();
    QCoreApplication::setApplicationName("payload-identity-test-" + QUuid::createUuid().toString(QUuid::WithoutBraces));
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const auto restore = qScopeGuard([&] {
        QDir(directory).removeRecursively();
        QCoreApplication::setApplicationName(originalName);
    });
    const QString path = directory + "/payload-request-identity.ini";
    USVPayloadFactGroup first;
    const QVariantMap identity = first.allocateRequest();
    QCOMPARE(identity.value("session").toUInt(), 1U);
    QCOMPARE(identity.value("request").toUInt(), 1U);
    QCOMPARE(first.allocateRequest().value("request").toUInt(), 2U);
    USVPayloadFactGroup restarted;
    QCOMPARE(restarted.allocateRequest().value("session").toUInt(), 2U);
    QCOMPARE(restarted.allocateRequest().value("request").toUInt(), 2U);

    QLockFile lock(path + ".allocation-lock");
    QVERIFY(lock.tryLock());
    USVPayloadFactGroup blocked;
    QVERIFY(blocked.allocateRequest().isEmpty());
    lock.unlock();
    QCOMPARE(blocked.allocateRequest().value("session").toUInt(), 3U);

    QSettings settings(path, QSettings::IniFormat);
    for (const QVariant& invalid : {QVariant("corrupt"), QVariant(0xFFFFFF)}) {
        settings.setValue("session", invalid);
        settings.sync();
        USVPayloadFactGroup exhausted;
        QVERIFY(exhausted.allocateRequest().isEmpty());
    }
    settings.setValue("session", 0xFFFFFE);
    settings.sync();
    USVPayloadFactGroup lastSession;
    QCOMPARE(lastSession.allocateRequest().value("session").toUInt(), 0xFFFFFFU);
    USVPayloadFactGroup noWrap;
    QVERIFY(noWrap.allocateRequest().isEmpty());

    QVERIFY(QFile::remove(path));
    QVERIFY(QDir().mkdir(path));  // An unusable store must not fall back to volatile IDs.
    USVPayloadFactGroup unwritable;
    QVERIFY(unwritable.allocateRequest().isEmpty());
}

void SendMavCommandWithSignallingTest::_payloadFactsFreshnessAndEvents()
{
    _connectMockLinkNoInitialConnectSequence();
    Vehicle* vehicle = MultiVehicleManager::instance()->activeVehicle();
    USVPayloadFactGroup group;
    group.setVehicleId(vehicle->id());
    auto value = [&](int component, const char* name, float number) {
        mavlink_message_t message{};
        char field[10]{};
        memcpy(field, name, qMin(size_t(10), strlen(name)));
        mavlink_msg_named_value_float_pack(vehicle->id(), component, &message, 0, field, number);
        group.handleMessage(vehicle, message);
    };
    value(191, "USV_VLD", 1);
    QCOMPARE(group.fieldSequence("spectrometerValid"), 1.0);
    value(191, "USV_VLD", 1);
    QCOMPARE(group.fieldSequence("spectrometerValid"), 2.0);
    value(240, "USV_VLD", 0);
    QCOMPARE(group.fieldSequence("spectrometerValid"), 2.0);
    QTest::qWait(5100);
    value(1, "PUMP_X", 12);
    QVERIFY(group.freshFields().contains("pumpX"));
    QVERIFY(!group.freshFields().contains("spectrometerValid"));

    QSignalSpy events(&group, &USVPayloadFactGroup::payloadEventReceived);
    QJsonObject event{{"v", 1},
                      {"session", 12},
                      {"request", 3},
                      {"tcp_session", 4},
                      {"command", 31010},
                      {"sender_system", 255},
                      {"sender_component", 190},
                      {"seq", 2},
                      {"phase", "terminal"},
                      {"outcome", "failed"},
                      {"reason", QStringLiteral("测量过期")},
                      {"preflight_phase", "settling"},
                      {"attempt_id", "1234567890abcdef1234567890abcdef"}};
    int chunkId = 100;
    auto send = [&](int system, int component, bool missing) {
        const QByteArray bytes = "USVE1:" + QJsonDocument(event).toJson(QJsonDocument::Compact) + '\0';
        ++chunkId;
        for (int offset = 0; offset < bytes.size(); offset += 50) {
            if (missing && offset == 50)
                continue;
            char chunk[50]{};
            memcpy(chunk, bytes.constData() + offset, qMin(qsizetype(50), bytes.size() - offset));
            mavlink_message_t message{};
            mavlink_msg_statustext_pack(system, component, &message, MAV_SEVERITY_NOTICE, chunk, chunkId, offset / 50);
            group.handleMessage(vehicle, message);
        }
    };
    send(vehicle->id() + 1, 191, false);
    send(vehicle->id(), 1, false);
    send(vehicle->id(), 191, true);
    QCOMPARE(events.count(), 0);
    send(vehicle->id(), 191, false);
    QCOMPARE(events.count(), 1);
    QCOMPARE(events.last()[0].toMap().value("attempt_id").toString(), event["attempt_id"].toString());
    event["request"] = 1.5;
    send(vehicle->id(), 191, false);
    QCOMPARE(events.count(), 1);
    event["request"] = 3;
    event["attempt_id"] = "truncated-uuid";
    send(vehicle->id(), 191, false);
    QCOMPARE(events.count(), 1);
    _disconnectMockLink();
}

SendMavCommandWithSignallingTest::TestCase_t SendMavCommandWithSignallingTest::_rgTestCases[] = {
    {MockLink::MAV_CMD_MOCKLINK_ALWAYS_RESULT_ACCEPTED, MAV_RESULT_ACCEPTED, Vehicle::MavCmdResultCommandResultOnly, 1},
    {MockLink::MAV_CMD_MOCKLINK_ALWAYS_RESULT_FAILED, MAV_RESULT_FAILED, Vehicle::MavCmdResultCommandResultOnly, 1},
    {MockLink::MAV_CMD_MOCKLINK_SECOND_ATTEMPT_RESULT_ACCEPTED, MAV_RESULT_ACCEPTED,
     Vehicle::MavCmdResultCommandResultOnly, 2},
    {MockLink::MAV_CMD_MOCKLINK_SECOND_ATTEMPT_RESULT_FAILED, MAV_RESULT_FAILED, Vehicle::MavCmdResultCommandResultOnly,
     2},
    {MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE, MAV_RESULT_FAILED, Vehicle::MavCmdResultFailureNoResponseToCommand,
     Vehicle::_mavCommandMaxRetryCount},
    {MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE_NO_RETRY, MAV_RESULT_FAILED,
     Vehicle::MavCmdResultFailureNoResponseToCommand, 1},
    {MockLink::MAV_CMD_MOCKLINK_RESULT_IN_PROGRESS_ACCEPTED, MAV_RESULT_ACCEPTED,
     Vehicle::MavCmdResultCommandResultOnly, 1},
    {MockLink::MAV_CMD_MOCKLINK_RESULT_IN_PROGRESS_FAILED, MAV_RESULT_FAILED, Vehicle::MavCmdResultCommandResultOnly,
     1},
    {MockLink::MAV_CMD_MOCKLINK_RESULT_IN_PROGRESS_NO_ACK, MAV_RESULT_FAILED,
     Vehicle::MavCmdResultFailureNoResponseToCommand, 1},
};

void SendMavCommandWithSignallingTest::_testCaseWorker(TestCase_t& testCase)
{
    _connectMockLinkNoInitialConnectSequence();

    MultiVehicleManager* vehicleMgr = MultiVehicleManager::instance();
    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QSignalSpy spyResult(vehicle, &Vehicle::mavCommandResult);

    _mockLink->clearReceivedMavCommandCounts();

    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, testCase.command, true /* showError */);

    QCOMPARE(spyResult.wait(15000), true);
    QList<QVariant> arguments = spyResult.takeFirst();

    // Gimbal controler requests MAVLINK_MSG_ID_GIMBAL_MANAGER_INFORMATION on vehicle connection,
    // and that messes with this test, as it receives response to that command instead. So if we
    // are taking the response to that MAV_CMD_REQUEST_MESSAGE, we discard it and take the next
    // Also, the camera manager requests MAVLINK_MSG_ID_CAMERA_INFORMATION on vehicle connection,
    // so we need to ignore that as well.
    while (arguments.at(2).toInt() == MAV_CMD_REQUEST_MESSAGE ||
           arguments.at(2).toInt() == MAV_CMD_REQUEST_CAMERA_INFORMATION) {
        qDebug() << "Received response to MAV_CMD_REQUEST_MESSAGE(512), ignoring, waiting for: " << testCase.command;
        QCOMPARE(spyResult.wait(10000), true);
        arguments = spyResult.takeFirst();
    }

    QCOMPARE(arguments.count(), 5);
    QCOMPARE(arguments.at(0).toInt(), vehicle->id());
    QCOMPARE(arguments.at(1).toInt(), MAV_COMP_ID_AUTOPILOT1);
    QCOMPARE(arguments.at(2).toInt(), testCase.command);
    QCOMPARE(arguments.at(3).toInt(), testCase.expectedCommandResult);
    QCOMPARE(arguments.at(4).value<Vehicle::MavCmdResultFailureCode_t>(), testCase.expectedFailureCode);
    QCOMPARE(vehicle->_findMavCommandListEntryIndex(MAV_COMP_ID_AUTOPILOT1,
                                                    MockLink::MAV_CMD_MOCKLINK_ALWAYS_RESULT_ACCEPTED),
             -1);
    QCOMPARE(_mockLink->receivedMavCommandCount(testCase.command), testCase.expectedSendCount);

    _disconnectMockLink();
}

void SendMavCommandWithSignallingTest::_performTestCases(void)
{
    int index = 0;
    for (TestCase_t& testCase : _rgTestCases) {
        qDebug() << "Testing case" << index++;
        _testCaseWorker(testCase);
    }
}

void SendMavCommandWithSignallingTest::_duplicateCommand(void)
{
    _connectMockLinkNoInitialConnectSequence();

    MultiVehicleManager* vehicleMgr = MultiVehicleManager::instance();
    Vehicle* vehicle = vehicleMgr->activeVehicle();

    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE, true /* showError */);
    QVERIFY(QTest::qWaitFor(
        [&]() { return _mockLink->receivedMavCommandCount(MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE) == 1; }, 10));
    QSignalSpy spyResult(vehicle, &Vehicle::mavCommandResult);
    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE, true /* showError */);

    // Duplicate command returns immediately
    QCOMPARE(spyResult.count(), 1);
    QList<QVariant> arguments = spyResult.takeFirst();
    QCOMPARE(arguments.count(), 5);
    QCOMPARE(arguments.at(0).toInt(), vehicle->id());
    QCOMPARE(arguments.at(2).toInt(), (int)MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE);
    QCOMPARE(arguments.at(3).toInt(), (int)MAV_RESULT_FAILED);
    QCOMPARE(arguments.at(4).value<Vehicle::MavCmdResultFailureCode_t>(), Vehicle::MavCmdResultFailureDuplicateCommand);
    QCOMPARE(_mockLink->receivedMavCommandCount(MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE), 1);
    QVERIFY(vehicle->_findMavCommandListEntryIndex(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE) !=
            -1);
}

void SendMavCommandWithSignallingTest::_retryRestartsAckDeadline(void)
{
    _connectMockLinkNoInitialConnectSequence();
    auto* vehicle = MultiVehicleManager::instance()->activeVehicle();
    const auto command = MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE;
    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, command, false);
    const int index = vehicle->_findMavCommandListEntryIndex(MAV_COMP_ID_AUTOPILOT1, command);
    QVERIFY(index >= 0);
    QTest::qWait(80);
    vehicle->_sendMavCommandFromList(index);
    QCOMPARE(vehicle->_mavCommandList[index].tryCount, 2);
    QVERIFY(vehicle->_mavCommandList[index].elapsedTimer.elapsed() < 60);
    _disconnectMockLink();
}

void SendMavCommandWithSignallingTest::_payloadRetryPolicy(void)
{
    _connectMockLinkNoInitialConnectSequence();
    auto* vehicle = MultiVehicleManager::instance()->activeVehicle();
    // Inspect immediately, before MockLink can answer these custom commands.
    for (int command = 31010; command <= 31019; ++command) {
        vehicle->sendMavCommand(191, static_cast<MAV_CMD>(command), false, 0, 0, 1, 1);
        const int index = vehicle->_findMavCommandListEntryIndex(191, static_cast<MAV_CMD>(command));
        QVERIFY(index >= 0);
        const auto& entry = vehicle->_mavCommandList[index];
        const bool stopping = command == 31011 || command == 31016 || command == 31019;
        QCOMPARE(entry.maxTries, 3);
        QCOMPARE(entry.usvTotalTimeoutMSecs, command == 31018 ? 40000 : stopping ? 15000 : 5000);
        QCOMPARE(entry.ackTimeoutMSecs, 1000);
        vehicle->_mavCommandList.removeAt(index);
    }
    // Protocol capability may be unavailable: keep the existing safe STOP
    // retries for the legacy path, without retrying uncorrelated starts.
    for (const int command : {31010, 31011, 31016, 31019}) {
        vehicle->sendMavCommand(191, static_cast<MAV_CMD>(command), false);
        const int index = vehicle->_findMavCommandListEntryIndex(191, static_cast<MAV_CMD>(command));
        if (command == 31010) {
            QCOMPARE(index, -1); // No protocol capability: starts are refused.
            continue;
        }
        QVERIFY(index >= 0);
        const auto &entry = vehicle->_mavCommandList[index];
        QCOMPARE(entry.rgParam3, 0.0f);
        QCOMPARE(entry.maxTries, 3);
        QCOMPARE(entry.ackTimeoutMSecs, 5000);
        vehicle->_mavCommandList.removeAt(index);
    }
    _disconnectMockLink();
}

void SendMavCommandWithSignallingTest::_payloadStopRetirementAndTotalDeadline(void)
{
    _connectMockLinkNoInitialConnectSequence();
    auto* vehicle = MultiVehicleManager::instance()->activeVehicle();
    const auto stop = static_cast<MAV_CMD>(31011);
    const auto start = static_cast<MAV_CMD>(31010);
    vehicle->sendMavCommand(191, stop, false, 0, 0, 1, 1);
    vehicle->sendMavCommand(191, start, false, 0, 0, 2, 1);
    QCOMPARE(vehicle->_findMavCommandListEntryIndex(191, start), -1);
    int index = vehicle->_findMavCommandListEntryIndex(191, stop);
    QVERIFY(index >= 0);
    mavlink_message_t progress{};
    mavlink_msg_command_ack_pack(vehicle->id(), 191, &progress, stop, MAV_RESULT_IN_PROGRESS, 1, 0, 255, 190);
    vehicle->_handleCommandAck(progress);
    QCOMPARE(vehicle->_findMavCommandListEntryIndex(191, stop), index);
    // Expire the real total timer without waiting fifteen seconds. Progress
    // may renew its ACK timer but must not renew this independent deadline.
    vehicle->_mavCommandList[index].usvTotalTimeoutMSecs = 1;
    QTest::qSleep(5);
    QSignalSpy result(vehicle, &Vehicle::mavCommandResult);
    vehicle->_sendMavCommandResponseTimeoutCheck();
    QCOMPARE(vehicle->_findMavCommandListEntryIndex(191, stop), -1);
    QCOMPARE(result.count(), 1);
    QCOMPARE(result.first().at(4).toInt(), int(Vehicle::MavCmdResultFailureNoResponseToCommand));
    vehicle->_handleCommandAck(progress);
    QCOMPARE(vehicle->_findMavCommandListEntryIndex(191, stop), -1);
    _disconnectMockLink();
}

void SendMavCommandWithSignallingTest::_payloadReceiptOrderingAndButtons()
{
    _connectMockLinkNoInitialConnectSequence();
    auto *vehicle = MultiVehicleManager::instance()->activeVehicle();
    const auto disconnect = qScopeGuard([&] { _disconnectMockLink(); });
    USVPayloadFactGroup facts;
    facts.setVehicleId(vehicle->id());
    connect(&facts, &USVPayloadFactGroup::payloadEventReceived, vehicle, &Vehicle::payloadCommandReceipt);
    QQmlEngine engine;
    engine.addImportPath("qrc:/qml");
    QQmlEngine::setObjectOwnership(vehicle, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(&facts, QQmlEngine::CppOwnership);
    engine.rootContext()->setContextProperty("testVehicle", vehicle);
    engine.rootContext()->setContextProperty("testFacts", &facts);
    for (const auto *name : {"USV_PROTO", "USV_VLD", "USV_BSET"}) {
        mavlink_message_t message{};
        char field[10]{};
        memcpy(field, name, strlen(name));
        mavlink_msg_named_value_float_pack(vehicle->id(), 191, &message, 0, field, 1);
        facts.handleMessage(vehicle, message);
    }
    QQmlComponent component(&engine, QUrl::fromLocalFile(QFINDTESTDATA("USVPayloadLifecycleFixture.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));
    std::unique_ptr<QObject> fixture(component.create());
    QVERIFY2(fixture, qPrintable(component.errorString()));
    QObject *commands = fixture->property("commands").value<QObject*>();
    QObject *button = fixture->property("detectorButton").value<QObject*>();
    QObject *stopButton = fixture->property("stopButton").value<QObject*>();
    auto request = [&]() { return commands->property("request").value<QJSValue>().toVariant().toMap(); };
    auto ack = [&](int command, MAV_RESULT result) {
        mavlink_message_t message{};
        mavlink_msg_command_ack_pack(vehicle->id(), 191, &message, command, result, 0, 0, 255, 190);
        vehicle->_handleCommandAck(message);
    };
    auto receipt = [&](const QVariantMap &identity, int systemOffset = 0) {
        QJsonObject event = QJsonObject::fromVariantMap(identity);
        // Only wire identities are serialized, never the QML Vehicle reference.
        for (auto it = event.begin(); it != event.end();) {
            if (!QStringList({"session", "request", "command", "sender_system", "sender_component"}).contains(it.key()))
                it = event.erase(it);
            else
                ++it;
        }
        event.insert("v", 1); event.insert("seq", 1); event.insert("tcp_session", 1);
        event.insert("phase", "request"); event.insert("outcome", "accepted");
        event.insert("reason", ""); event.insert("attempt_id", ""); event.insert("preflight_phase", "");
        deliverPayloadFrames(facts, vehicle, payloadEventFrames(event, vehicle->id() + systemOffset));
    };
    QVERIFY(button->property("enabled").toBool());
    for (const bool ackFirst : {false, true}) {
        QVERIFY(QMetaObject::invokeMethod(button, "clicked"));
        const QVariantMap first = request();
        QVERIFY(vehicle->isMavCommandPending(191, 31018));
        QVERIFY(!button->property("enabled").toBool());
        int index = vehicle->_findMavCommandListEntryIndex(191, static_cast<MAV_CMD>(31018));
        // First two requests may be lost. Retry the identical payload, then
        // leave the last copy waiting until the original total deadline.
        for (int attempt = 2; attempt <= 3; ++attempt) {
            vehicle->_mavCommandList[index].ackTimeoutMSecs = 1;
            QTest::qSleep(3);
            vehicle->_sendMavCommandResponseTimeoutCheck();
            QCOMPARE(vehicle->_mavCommandList[index].tryCount, attempt);
            QCOMPARE(vehicle->_mavCommandList[index].rgParam3, first.value("request").toFloat());
            QCOMPARE(vehicle->_mavCommandList[index].rgParam4, first.value("session").toFloat());
        }
        QTest::qSleep(3);
        vehicle->_sendMavCommandResponseTimeoutCheck();
        QCOMPARE(vehicle->_mavCommandList[index].tryCount, 3);
        if (ackFirst) ack(31018, MAV_RESULT_ACCEPTED);
        QVERIFY(vehicle->isMavCommandPending(191, 31018));
        receipt(first, 1); // Wrong Vehicle cannot release the native queue.
        QVERIFY(!button->property("enabled").toBool());
        receipt(first);
        QVERIFY(!vehicle->isMavCommandPending(191, 31018));
        QTRY_VERIFY(button->property("enabled").toBool());
        QVERIFY(QMetaObject::invokeMethod(button, "clicked"));
        const QVariantMap second = request();
        QVERIFY(second.value("request") != first.value("request"));
        ack(31018, MAV_RESULT_ACCEPTED); // The first request's late standard ACK.
        ack(31018, MAV_RESULT_FAILED);
        receipt(first); // Its delayed correlated event also cannot release the new request.
        QVERIFY(vehicle->isMavCommandPending(191, 31018));
        QVERIFY(!button->property("enabled").toBool());
        receipt(second);
        QTRY_VERIFY(button->property("enabled").toBool());
        QVERIFY(QMetaObject::invokeMethod(stopButton, "clicked"));
        const QVariantMap stop = request();
        QVERIFY(!stopButton->property("enabled").toBool());
        QVERIFY(!button->property("enabled").toBool());
        receipt(stop);
        QTRY_VERIFY(stopButton->property("enabled").toBool());
        QTRY_VERIFY(button->property("enabled").toBool());
    }
    QVERIFY(QMetaObject::invokeMethod(button, "clicked"));
    QVERIFY(QMetaObject::invokeMethod(fixture.get(), "expireReceipt"));
    QVERIFY(!button->property("enabled").toBool()); // Native send is still waiting.
    const int index = vehicle->_findMavCommandListEntryIndex(191, static_cast<MAV_CMD>(31018));
    QVERIFY(index >= 0);
    vehicle->_mavCommandList[index].usvTotalTimeoutMSecs = 1;
    QTest::qSleep(3);
    vehicle->_sendMavCommandResponseTimeoutCheck();
    QVERIFY(!vehicle->isMavCommandPending(191, 31018));
    QTRY_VERIFY(button->property("enabled").toBool());
}

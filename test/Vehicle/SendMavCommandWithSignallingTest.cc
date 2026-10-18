/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SendMavCommandWithSignallingTest.h"
#include "MultiVehicleManager.h"
#include "MockLink.h"
#include "../../custom/src/USVPayloadFactGroup.h"
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QLockFile>
#include <QtCore/QScopeGuard>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QUuid>

#include <QtTest/QSignalSpy>
#include <QtTest/QTest>

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
    for (const QVariant &invalid : {QVariant("corrupt"), QVariant(0xFFFFFF)}) {
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
    QVERIFY(QDir().mkdir(path)); // An unusable store must not fall back to volatile IDs.
    USVPayloadFactGroup unwritable;
    QVERIFY(unwritable.allocateRequest().isEmpty());
}

void SendMavCommandWithSignallingTest::_payloadFactsFreshnessAndEvents()
{
    _connectMockLinkNoInitialConnectSequence();
    Vehicle *vehicle = MultiVehicleManager::instance()->activeVehicle();
    USVPayloadFactGroup group;
    group.setVehicleId(vehicle->id());
    auto value = [&](int component, const char *name, float number) {
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
    QJsonObject event{{"v", 1}, {"session", 12}, {"request", 3}, {"tcp_session", 4},
                      {"command", 31010}, {"sender_system", 255}, {"sender_component", 190},
                      {"seq", 2}, {"phase", "terminal"}, {"outcome", "failed"},
                      {"reason", QStringLiteral("测量过期")}, {"preflight_phase", "settling"},
                      {"attempt_id", "1234567890abcdef1234567890abcdef"}};
    int chunkId = 100;
    auto send = [&](int system, int component, bool missing) {
        const QByteArray bytes = "USVE1:" + QJsonDocument(event).toJson(QJsonDocument::Compact) + '\0';
        ++chunkId;
        for (int offset = 0; offset < bytes.size(); offset += 50) {
            if (missing && offset == 50) continue;
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
    {  MockLink::MAV_CMD_MOCKLINK_ALWAYS_RESULT_ACCEPTED,           MAV_RESULT_ACCEPTED,    Vehicle::MavCmdResultCommandResultOnly,             1 },
    {  MockLink::MAV_CMD_MOCKLINK_ALWAYS_RESULT_FAILED,             MAV_RESULT_FAILED,      Vehicle::MavCmdResultCommandResultOnly,             1 },
    {  MockLink::MAV_CMD_MOCKLINK_SECOND_ATTEMPT_RESULT_ACCEPTED,   MAV_RESULT_ACCEPTED,    Vehicle::MavCmdResultCommandResultOnly,             2 },
    {  MockLink::MAV_CMD_MOCKLINK_SECOND_ATTEMPT_RESULT_FAILED,     MAV_RESULT_FAILED,      Vehicle::MavCmdResultCommandResultOnly,             2 },
    {  MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE,                      MAV_RESULT_FAILED,      Vehicle::MavCmdResultFailureNoResponseToCommand,    Vehicle::_mavCommandMaxRetryCount },
    {  MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE_NO_RETRY,             MAV_RESULT_FAILED,      Vehicle::MavCmdResultFailureNoResponseToCommand,    1 },
    {  MockLink::MAV_CMD_MOCKLINK_RESULT_IN_PROGRESS_ACCEPTED,      MAV_RESULT_ACCEPTED,    Vehicle::MavCmdResultCommandResultOnly,             1 },
    {  MockLink::MAV_CMD_MOCKLINK_RESULT_IN_PROGRESS_FAILED,        MAV_RESULT_FAILED,      Vehicle::MavCmdResultCommandResultOnly,             1 },
    {  MockLink::MAV_CMD_MOCKLINK_RESULT_IN_PROGRESS_NO_ACK,        MAV_RESULT_FAILED,      Vehicle::MavCmdResultFailureNoResponseToCommand,    1 },
};

void SendMavCommandWithSignallingTest::_testCaseWorker(TestCase_t& testCase)
{
    _connectMockLinkNoInitialConnectSequence();

    MultiVehicleManager*    vehicleMgr  = MultiVehicleManager::instance();
    Vehicle*                vehicle     = vehicleMgr->activeVehicle();
    QSignalSpy              spyResult(vehicle, &Vehicle::mavCommandResult);

    _mockLink->clearReceivedMavCommandCounts();

    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, testCase.command, true /* showError */);

    QCOMPARE(spyResult.wait(15000), true);
    QList<QVariant> arguments = spyResult.takeFirst();

    // Gimbal controler requests MAVLINK_MSG_ID_GIMBAL_MANAGER_INFORMATION on vehicle connection,
    // and that messes with this test, as it receives response to that command instead. So if we
    // are taking the response to that MAV_CMD_REQUEST_MESSAGE, we discard it and take the next
    // Also, the camera manager requests MAVLINK_MSG_ID_CAMERA_INFORMATION on vehicle connection,
    // so we need to ignore that as well.
    while (arguments.at(2).toInt() == MAV_CMD_REQUEST_MESSAGE || arguments.at(2).toInt() == MAV_CMD_REQUEST_CAMERA_INFORMATION) {
        qDebug() << "Received response to MAV_CMD_REQUEST_MESSAGE(512), ignoring, waiting for: " << testCase.command;
        QCOMPARE(spyResult.wait(10000), true);
        arguments = spyResult.takeFirst();
    }

    QCOMPARE(arguments.count(),                                             5);
    QCOMPARE(arguments.at(0).toInt(),                                       vehicle->id());
    QCOMPARE(arguments.at(1).toInt(),                                       MAV_COMP_ID_AUTOPILOT1);
    QCOMPARE(arguments.at(2).toInt(),                                       testCase.command);
    QCOMPARE(arguments.at(3).toInt(),                                       testCase.expectedCommandResult);
    QCOMPARE(arguments.at(4).value<Vehicle::MavCmdResultFailureCode_t>(),   testCase.expectedFailureCode);
    QCOMPARE(vehicle->_findMavCommandListEntryIndex(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_ALWAYS_RESULT_ACCEPTED), -1);
    QCOMPARE(_mockLink->receivedMavCommandCount(testCase.command),          testCase.expectedSendCount);

    _disconnectMockLink();
}

void SendMavCommandWithSignallingTest::_performTestCases(void)
{
    int index = 0;
    for (TestCase_t& testCase: _rgTestCases) {
        qDebug() << "Testing case" << index++;
        _testCaseWorker(testCase);
    }
}

void SendMavCommandWithSignallingTest::_duplicateCommand(void)
{
    _connectMockLinkNoInitialConnectSequence();

    MultiVehicleManager*    vehicleMgr  = MultiVehicleManager::instance();
    Vehicle*                vehicle     = vehicleMgr->activeVehicle();

    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE, true /* showError */);
    QVERIFY(QTest::qWaitFor([&]() { return _mockLink->receivedMavCommandCount(MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE) == 1; }, 10));
    QSignalSpy spyResult(vehicle, &Vehicle::mavCommandResult);
    vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE, true /* showError */);

    // Duplicate command returns immediately
    QCOMPARE(spyResult.count(),                                                         1);
    QList<QVariant> arguments = spyResult.takeFirst();
    QCOMPARE(arguments.count(),                                                         5);
    QCOMPARE(arguments.at(0).toInt(),                                                   vehicle->id());
    QCOMPARE(arguments.at(2).toInt(),                                                   (int)MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE);
    QCOMPARE(arguments.at(3).toInt(),                                                   (int)MAV_RESULT_FAILED);
    QCOMPARE(arguments.at(4).value<Vehicle::MavCmdResultFailureCode_t>(),               Vehicle::MavCmdResultFailureDuplicateCommand);
    QCOMPARE(_mockLink->receivedMavCommandCount(MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE),    1);
    QVERIFY(vehicle->_findMavCommandListEntryIndex(MAV_COMP_ID_AUTOPILOT1, MockLink::MAV_CMD_MOCKLINK_NO_RESPONSE) != -1);
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
        QCOMPARE(entry.maxTries, stopping ? 3 : 1);
        QCOMPARE(entry.usvTotalTimeoutMSecs, command == 31018 ? 40000 : stopping ? 15000 : 5000);
        QCOMPARE(entry.ackTimeoutMSecs, command == 31018 ? 40000 : 5000);
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

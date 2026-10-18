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

#include <QtTest/QSignalSpy>
#include <QtTest/QTest>

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
        vehicle->sendMavCommand(191, static_cast<MAV_CMD>(command), false);
        const int index = vehicle->_findMavCommandListEntryIndex(191, static_cast<MAV_CMD>(command));
        QVERIFY(index >= 0);
        const auto& entry = vehicle->_mavCommandList[index];
        const bool stopping = command == 31011 || command == 31016 || command == 31019;
        QCOMPARE(entry.maxTries, stopping ? 3 : 1);
        QVERIFY(entry.ackTimeoutMSecs >= (command == 31018 ? 40000 : stopping ? 15000 : 5000));
    }
    _disconnectMockLink();
}

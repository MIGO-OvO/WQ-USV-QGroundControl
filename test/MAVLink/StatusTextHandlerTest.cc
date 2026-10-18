/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "StatusTextHandlerTest.h"
#include "StatusTextHandler.h"
#include "MAVLinkLib.h"

#include <QtTest/QTest>
#include <QtTest/QSignalSpy>

namespace {
void deliver(StatusTextHandler &handler, int component, int id, int seq, const QByteArray &text)
{
    mavlink_message_t message{};
    char bytes[50]{};
    memcpy(bytes, text.constData(), qMin(text.size(), qsizetype(50)));
    mavlink_msg_statustext_pack(1, component, &message, MAV_SEVERITY_INFO, bytes, id, seq);
    handler.mavlinkMessageReceived(message);
}
}

void StatusTextHandlerTest::_testCompleteChunks()
{
    StatusTextHandler handler;
    QSignalSpy complete(&handler, &StatusTextHandler::completeTextMessageReceived);
    const QByteArray bytes = QByteArray(49, 'a') + QStringLiteral("测量").toUtf8() + QByteArray(52, 'b');
    deliver(handler, 191, 7, 2, bytes.mid(100));
    deliver(handler, 191, 7, 0, bytes.left(50));
    deliver(handler, 191, 7, 0, bytes.left(50));
    deliver(handler, 190, 7, 0, "other component");
    QCOMPARE(complete.count(), 1);
    deliver(handler, 191, 7, 1, bytes.mid(50, 50));
    QCOMPARE(complete.count(), 2);
    QCOMPARE(complete.last().at(2).toString(), QString::fromUtf8(bytes));
}

void StatusTextHandlerTest::_testIncompleteAndConflictingChunks()
{
    StatusTextHandler handler;
    QSignalSpy complete(&handler, &StatusTextHandler::completeTextMessageReceived);
    deliver(handler, 191, 1, 0, QByteArray(50, 'a'));
    deliver(handler, 191, 1, 0, QByteArray(50, 'b'));
    deliver(handler, 191, 1, 1, "end");
    QCOMPARE(complete.count(), 0);
    deliver(handler, 191, 2, 0, QByteArray(50, 'a'));
    deliver(handler, 191, 2, 2, "missing middle");
    QTest::qWait(1300);
    QCOMPARE(complete.count(), 0);
    deliver(handler, 191, 2, 1, QByteArray(50, 'b'));
    QCOMPARE(complete.count(), 0);
}

void StatusTextHandlerTest::_testAbsoluteChunkDeadline()
{
    StatusTextHandler handler;
    QSignalSpy complete(&handler, &StatusTextHandler::completeTextMessageReceived);
    deliver(handler, 191, 3, 0, QByteArray(50, 'a'));
    QTest::qWait(700);
    deliver(handler, 191, 3, 0, QByteArray(50, 'a'));
    QTest::qWait(400);
    deliver(handler, 191, 3, 1, "late end");
    QCOMPARE(complete.count(), 0);
}

void StatusTextHandlerTest::_testGetMessageText()
{
    mavlink_message_t message;
    (void) mavlink_msg_statustext_pack(255, MAV_COMP_ID_USER1, &message, MAV_SEVERITY_INFO,"StatusTextHandlerTest", 0, 0);

    const QString messageText = StatusTextHandler::getMessageText(message);
    QCOMPARE(messageText, "StatusTextHandlerTest");
}

void StatusTextHandlerTest::_testHandleTextMessage()
{
    StatusTextHandler* statusTextHandler = new StatusTextHandler(this);

    statusTextHandler->handleHTMLEscapedTextMessage(MAV_COMP_ID_USER1, MAV_SEVERITY_INFO, "StatusTextHandlerTestInfo", "This is the StatusTextHandlerTestInfo Test");
    QString messages = statusTextHandler->formattedMessages();
    QVERIFY(!messages.isEmpty());
    QVERIFY(messages.contains("StatusTextHandlerTestInfo"));
    QCOMPARE(statusTextHandler->getNormalCount(), 1);
    QCOMPARE(statusTextHandler->messageCount(), 1);

    statusTextHandler->handleHTMLEscapedTextMessage(MAV_COMP_ID_USER1, MAV_SEVERITY_WARNING, "StatusTextHandlerTestWarning", "This is the StatusTextHandlerTestWarning Test");
    messages = statusTextHandler->formattedMessages();
    QVERIFY(messages.contains("StatusTextHandlerTestInfo"));
    QVERIFY(messages.contains("StatusTextHandlerTestWarning"));
    QCOMPARE(statusTextHandler->getNormalCount(), 1);
    QCOMPARE(statusTextHandler->getWarningCount(), 1);
    QCOMPARE(statusTextHandler->messageCount(), 2);

    statusTextHandler->clearMessages();
    messages = statusTextHandler->formattedMessages();
    QVERIFY(messages.isEmpty());
    QCOMPARE(statusTextHandler->getNormalCount(), 0);
    QCOMPARE(statusTextHandler->getWarningCount(), 0);
    QCOMPARE(statusTextHandler->messageCount(), 0);
}

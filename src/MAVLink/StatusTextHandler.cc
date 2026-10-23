/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "StatusTextHandler.h"
#include <QGCLoggingCategory.h>

#include <QtCore/QTimer>
#include <QtCore/QDateTime>

QGC_LOGGING_CATEGORY(StatusTextHandlerLog, "MAVLink.StatusTextHandler")

StatusText::StatusText(MAV_COMPONENT componentid, MAV_SEVERITY severity, const QString &text)
    : m_compId(componentid)
    , m_severity(severity)
    , m_text(text)
{
    // qCDebug(StatusTextHandlerLog) << Q_FUNC_INFO << this;
}

bool StatusText::severityIsError() const
{
    switch (m_severity) {
        case MAV_SEVERITY_EMERGENCY:
        case MAV_SEVERITY_ALERT:
        case MAV_SEVERITY_CRITICAL:
        case MAV_SEVERITY_ERROR:
            return true;

        default:
            return false;
    }
}

StatusTextHandler::StatusTextHandler(QObject *parent)
    : QObject(parent)
    , m_chunkedStatusTextTimer(new QTimer(this))
{
    // qCDebug(StatusTextHandlerLog) << Q_FUNC_INFO << this;

    m_chunkedStatusTextTimer->setInterval(250);
    (void) connect(m_chunkedStatusTextTimer, &QTimer::timeout, this, &StatusTextHandler::_chunkedStatusTextTimeout);
}

StatusTextHandler::~StatusTextHandler()
{
    clearMessages();

    // qCDebug(StatusTextHandlerLog) << Q_FUNC_INFO << this;
}

QString StatusTextHandler::getMessageText(const mavlink_message_t &message)
{
    // Warning: There is a bug in mavlink which causes mavlink_msg_statustext_get_text to work incorrect.
    // It ends up copying crap off the end of the buffer, so don't use it for now.

    mavlink_statustext_t statusText;
    mavlink_msg_statustext_decode(&message, &statusText);

    char buffer[MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN + 1];
    memcpy(buffer, statusText.text, MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN);
    buffer[MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN] = '\0';

    return QString(buffer);
}

QString StatusTextHandler::formattedMessages() const
{
    QString result;
    for (const StatusText *message: messages()) {
        (void) result.prepend(message->getFormattedText());
    }

    return result;
}

void StatusTextHandler::clearMessages()
{
    qDeleteAll(m_messages);
    m_messages.clear();

    m_errorCount = 0;
    m_warningCount = 0;
    m_normalCount = 0;

    _handleTextMessage(0);
}

void StatusTextHandler::resetAllMessages()
{
    const uint32_t count = messageCount();
    const MessageType type = m_messageType;

    m_errorCount = 0;
    m_warningCount = 0;
    m_normalCount = 0;
    m_messageCount = 0;
    m_messageType = MessageType::MessageNone;

    if (count != messageCount()) {
        emit messageCountChanged(0);
    }

    if (type != m_messageType) {
        emit messageTypeChanged();
    }
}

void StatusTextHandler::resetErrorLevelMessages()
{
    const uint32_t prevMessageCount = messageCount();
    const MessageType prevMessagetype = m_messageType;

    m_messageCount -= getErrorCount();
    m_errorCount = 0;

    if (getWarningCount() > 0) {
        m_messageType = MessageType::MessageWarning;
    } else if (getNormalCount() > 0) {
        m_messageType = MessageType::MessageNormal;
    } else {
        m_messageType = MessageType::MessageNone;
    }

    if (prevMessageCount != messageCount()) {
        emit messageCountChanged(messageCount());
    }

    if (prevMessagetype != m_messageType) {
        emit messageTypeChanged();
    }
}

void StatusTextHandler::handleHTMLEscapedTextMessage(MAV_COMPONENT compId, MAV_SEVERITY severity, const QString &text, const QString &description)
{
    QString htmlText(text);

    (void) htmlText.replace("\n", "<br/>");

    // TODO: handle text + description separately in the UI
    if (!description.isEmpty()) {
        QString htmlDescription(description);
        (void) htmlDescription.replace("\n", "<br/>");
        (void) htmlText.append(QStringLiteral("<br/><small><small>"));
        (void) htmlText.append(htmlDescription);
        (void) htmlText.append(QStringLiteral("</small></small>"));
    }

    if (m_activeComponent == MAV_COMPONENT::MAV_COMPONENT_ENUM_END) {
        m_activeComponent = compId;
    }

    if (compId != m_activeComponent) {
        m_multiComp = true;
    }

    MessageType messageType = MessageType::MessageNone;

    // Color the output depending on the message severity. We have 3 distinct cases:
    // 1: If we have an ERROR or worse, make it bigger, bolder, and highlight it red.
    // 2: If we have a warning or notice, just make it bold and color it orange.
    // 3: Otherwise color it the standard color, white.
    QString style;
    switch (severity) {
        case MAV_SEVERITY_EMERGENCY:
        case MAV_SEVERITY_ALERT:
        case MAV_SEVERITY_CRITICAL:
        case MAV_SEVERITY_ERROR:
            style = QStringLiteral("<#E>");
            messageType = MessageType::MessageError;
            break;

        case MAV_SEVERITY_NOTICE:
        case MAV_SEVERITY_WARNING:
            style = QStringLiteral("<#I>");
            messageType = MessageType::MessageWarning;
            break;

        default:
            style = QStringLiteral("<#N>");
            messageType = MessageType::MessageNormal;
            break;
    }

    QString severityText;
    switch (severity) {
        case MAV_SEVERITY_EMERGENCY:
            severityText = tr("EMERGENCY");
            break;

        case MAV_SEVERITY_ALERT:
            severityText = tr("ALERT");
            break;

        case MAV_SEVERITY_CRITICAL:
            severityText = tr("Critical");
            break;

        case MAV_SEVERITY_ERROR:
            severityText = tr("Error");
            break;

        case MAV_SEVERITY_WARNING:
            severityText = tr("Warning");
            break;

        case MAV_SEVERITY_NOTICE:
            severityText = tr("Notice");
            break;

        case MAV_SEVERITY_INFO:
            severityText = tr("Info");
            break;

        case MAV_SEVERITY_DEBUG:
            severityText = tr("Debug");
            break;

        default:
            qCWarning(StatusTextHandlerLog) << Q_FUNC_INFO << "Invalid MAV_SEVERITY";
            break;
    }

    QString compString;
    if (m_multiComp) {
        compString = QString("COMP:%1").arg(compId);
    }

    const QString dateString = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");

    const QString formatText = QString("<font style=\"%1\">[%2 %3] %4: %5</font><br/>").arg(style, dateString, compString, severityText, htmlText);

    StatusText* const message = new StatusText(compId, severity, text);
    message->setFormatedText(formatText);

    emit newFormattedMessage(formatText);

    (void) m_messages.append(message);
    const uint32_t count = m_messages.count();

    _handleTextMessage(count, messageType);

    if (message->severityIsError()) {
        emit newErrorMessage(message->getText());
    }
}

void StatusTextHandler::mavlinkMessageReceived(const mavlink_message_t &message)
{
    if (message.msgid != MAVLINK_MSG_ID_STATUSTEXT) {
        return;
    }

    _handleStatusText(message);
}

void StatusTextHandler::_handleStatusText(const mavlink_message_t &message)
{
    mavlink_statustext_t statustext{};
    mavlink_msg_statustext_decode(&message, &statustext);
    QByteArray bytes(statustext.text, MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN);
    const int terminator = bytes.indexOf('\0');
    if (terminator >= 0) {
        bytes.truncate(terminator);
    }
    const MAV_COMPONENT compId = static_cast<MAV_COMPONENT>(message.compid);
    if (message.compid == 191) {
        qCDebug(StatusTextHandlerLog) << "USV chunk rx" << "handler" << this << "source" << int(message.sysid)
                                      << int(message.compid) << "mavSeq" << int(message.seq) << "id" << statustext.id
                                      << "chunk" << int(statustext.chunk_seq) << "bytes" << bytes.size() << "tail"
                                      << (terminator >= 0);
    }
    if (m_chunkedStatusTextInfoMap.contains(compId)
            && (m_chunkedStatusTextInfoMap.value(compId).chunkId != statustext.id
                || m_chunkedStatusTextInfoMap.value(compId).age.elapsed() >= 1000)) {
        _chunkedStatusTextCompleted(compId);
    }
    if (statustext.id == 0) {
        const QString text = QString::fromUtf8(bytes);
        emit textMessageReceived(compId, static_cast<MAV_SEVERITY>(statustext.severity), text, "");
        if (statustext.chunk_seq == 0) {
            emit completeTextMessageReceived(compId, static_cast<MAV_SEVERITY>(statustext.severity), text);
        }
        return;
    }
    if (!m_chunkedStatusTextInfoMap.contains(compId)) {
        ChunkedStatusTextInfo_t info;
        info.chunkId = statustext.id;
        info.severity = static_cast<MAV_SEVERITY>(statustext.severity);
        info.age.start();
        m_chunkedStatusTextInfoMap.insert(compId, info);
    }
    auto &info = m_chunkedStatusTextInfoMap[compId];
    const int sequence = statustext.chunk_seq; // uint8_t: at most 256 chunks
    info.invalid |= info.severity != statustext.severity;
    if (info.received.contains(sequence)) {
        info.invalid |= info.chunks[sequence] != bytes;
    } else {
        while (info.chunks.size() <= sequence) {
            info.chunks.append(QByteArray());
        }
        info.chunks[sequence] = bytes;
        info.received.insert(sequence);
    }
    if (terminator >= 0) {
        info.invalid |= info.lastSequence >= 0 && info.lastSequence != sequence;
        info.lastSequence = sequence;
    }
    if (!m_chunkedStatusTextTimer->isActive()) {
        m_chunkedStatusTextTimer->start();
    }
    if (info.lastSequence >= 0 && info.received.size() == info.lastSequence + 1
            && info.chunks.size() == info.lastSequence + 1) {
        _chunkedStatusTextCompleted(compId, !info.invalid);
    }
}

void StatusTextHandler::_chunkedStatusTextTimeout()
{
    for (auto compId : m_chunkedStatusTextInfoMap.keys()) {
        if (m_chunkedStatusTextInfoMap[compId].age.elapsed() >= 1000) {
            _chunkedStatusTextCompleted(compId);
        }
    }
}

void StatusTextHandler::_chunkedStatusTextCompleted(MAV_COMPONENT compId, bool complete)
{
    const ChunkedStatusTextInfo_t& chunkedInfo = m_chunkedStatusTextInfoMap.value(compId);
    const MAV_SEVERITY severity = chunkedInfo.severity;
    if (compId == 191) {
        qCDebug(StatusTextHandlerLog) << "USV assembly" << "handler" << this << "id" << chunkedInfo.chunkId
                                      << "complete" << complete << "invalid" << chunkedInfo.invalid << "tail"
                                      << chunkedInfo.lastSequence << "received" << chunkedInfo.received << "ageMs"
                                      << chunkedInfo.age.elapsed();
    }

    QByteArray joined;
    for (int index = 0; index < chunkedInfo.chunks.size(); ++index) {
        if (!chunkedInfo.received.contains(index)) {
            joined.append(" ... ");
        } else {
            joined.append(chunkedInfo.chunks[index]);
        }
    }
    if (!complete && chunkedInfo.lastSequence < 0) {
        joined.append(" ... ");
    }
    const QString messageText = QString::fromUtf8(joined);
    (void) m_chunkedStatusTextInfoMap.remove(compId);
    if (m_chunkedStatusTextInfoMap.isEmpty()) {
        m_chunkedStatusTextTimer->stop();
    }
    emit textMessageReceived(compId, severity, messageText, "");
    if (complete) {
        emit completeTextMessageReceived(compId, severity, messageText);
    }
}

void StatusTextHandler::_handleTextMessage(uint32_t newCount, MessageType messageType)
{
    if (newCount == 0) {
        resetAllMessages();
        return;
    }

    switch (messageType) {
        case MessageType::MessageNormal:
            m_normalCount++;
            break;

        case MessageType::MessageWarning:
            m_warningCount++;
            break;

        case MessageType::MessageError:
            m_errorCount++;
            m_errorCountTotal++;
            break;

        case MessageType::MessageNone:
        default:
            qCWarning(StatusTextHandlerLog) << Q_FUNC_INFO << "Invalid MessageType";
            break;
    }

    const uint32_t count = getErrorCount() + getWarningCount() + getNormalCount();
    if (count != messageCount()) {
        m_messageCount = count;
        emit messageCountChanged(messageCount());
    }

    // messageType represents the worst message which hasn't been viewed yet
    MessageType newMessageType = MessageType::MessageNone;
    if (getErrorCount() > 0) {
        newMessageType = MessageType::MessageError;
    } else if (getWarningCount() > 0) {
        newMessageType = MessageType::MessageWarning;
    } else if (getNormalCount() > 0) {
        newMessageType = MessageType::MessageNormal;
    }

    if (newMessageType != m_messageType) {
        m_messageType = newMessageType;
        emit messageTypeChanged();
    }
}

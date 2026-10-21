/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "AudioOutputTest.h"
#include "AudioOutput.h"
#include "AppSettings.h"
#include "Fact.h"
#include "QGCPalette.h"
#include "SettingsManager.h"

#include <QtQml/QQmlComponent>
#include <QtQml/QQmlContext>
#include <QtQml/QQmlEngine>
#include <QtQuick/QQuickItem>
#include <QtTest/QTest>
#include <memory>

void AudioOutputTest::_testSpokenReplacements()
{
    QString result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("-10.5m, -10.5m. -10.5 m"));
    QCOMPARE(result, QStringLiteral("negative 10 point 5 meters, negative 10 point 5 meters. negative 10 point 5  meters"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("-10m -10 m"));
    QCOMPARE(result, QStringLiteral("negative 10 meters negative 10  meters"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("foo -10m -10 m bar"));
    QCOMPARE(result, QStringLiteral("foo negative 10 meters negative 10  meters bar"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("-foom"));
    QCOMPARE(result, QStringLiteral("-foom"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("10 moo"));
    QCOMPARE(result, QStringLiteral("10 moo"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("10moo"));
    QCOMPARE(result, QStringLiteral("10moo"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("10ms"));
    QCOMPARE(result, QStringLiteral("10ms"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("1000ms"));
    QCOMPARE(result, QStringLiteral("1 second"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("1001ms"));
    QCOMPARE(result, QStringLiteral("1 second and 1 millisecond"));
}

void AudioOutputTest::_speechConfiguration()
{
    auto *muted = SettingsManager::instance()->appSettings()->audioMuted();
    QQmlEngine engine;
    engine.addImportPath("qrc:/qml");
    QGCPalette palette;
    engine.rootContext()->setContextProperty("qgcPal", &palette);
    QQmlComponent component(&engine, QUrl("qrc:/qml/QGroundControl/FlyView/PreFlightSoundCheck.qml"));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));
    QQuickItem parent;
    std::unique_ptr<QObject> check(component.createWithInitialProperties({{"parent", QVariant::fromValue(&parent)}}));
    QVERIFY2(check, qPrintable(component.errorString()));
#ifdef DISABLE_SPEECH
    QVERIFY(!muted->property("visible").toBool());
    QVERIFY(check->property("passed").toBool());
    QVERIFY(check->property("manualText").toString().isEmpty());
    QVERIFY(!check->property("telemetryFailure").toBool());
    AudioOutput output;
    output.init(nullptr);
    output.setMuted(false);
    output.say(QStringLiteral("Muted test"));
    QVERIFY(output.isMuted());
    QVERIFY(output.children().isEmpty());
#else
    QVERIFY(muted->property("visible").toBool());
    QVERIFY(check->property("_speechAvailable").toBool());
    QVERIFY(!check->property("manualText").toString().isEmpty());
#endif
}

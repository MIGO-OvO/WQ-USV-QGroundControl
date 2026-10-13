"""Render real USV QML with mock Facts; never connect to a vehicle.

Requires the already available PySide6 runtime. Generated imports and previews
are disposable build artifacts, not production dependencies.
"""
import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import PySide6

_qt_dll_directory = None
if os.name == "nt":
    _qt_dll_directory = os.add_dll_directory(str(Path(PySide6.__file__).parent))

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QMetaObject, QObject, QUrl, Q_RETURN_ARG, qInstallMessageHandler
from PySide6.QtGui import QFont, QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6 import QtQuick, QtQuickControls2
from PySide6.QtTest import QTest

ROOT = Path(__file__).resolve().parents[2]


def install_mock_imports(directory):
    controls = directory / "QGroundControl" / "Controls"
    controls.mkdir(parents=True)
    (directory / "QGroundControl" / "qmldir").write_text(
        "module QGroundControl\nsingleton QGroundControl 1.0 QGroundControl.qml\n", encoding="utf-8")
    (directory / "QGroundControl" / "QGroundControl.qml").write_text(
        "pragma Singleton\nimport QtQuick\nQtObject { property var multiVehicleManager: null }", encoding="utf-8")
    stubs = {
        "ScreenTools.qml": """pragma Singleton
import QtQuick
QtObject {
    property real fontFactor: 1
    property real defaultFontPixelWidth: 9 * fontFactor
    property real defaultFontPixelHeight: 20 * fontFactor
    property real defaultFontPointSize: 12 * fontFactor
    property real smallFontPointSize: 10 * fontFactor
    property real minTouchPixels: 44
    property bool isTinyScreen: false
}""",
        "QGCLabel.qml": """import QtQuick
import QtQuick.Controls
Label {
    font.pointSize: ScreenTools.defaultFontPointSize
    color: labelPalette.text
    QGCPalette { id: labelPalette }
}""",
        "QGCPalette.qml": """import QtQuick
QtObject {
    enum Theme { Light, Dark }
    property int globalTheme: QGCPalette.Dark
    property bool colorGroupEnabled: true
    property color window: globalTheme === QGCPalette.Dark ? "#222222" : "#ffffff"
    property color text: globalTheme === QGCPalette.Dark ? "#ffffff" : "#333333"
    property color colorBlue: globalTheme === QGCPalette.Dark ? "#536dff" : "#1a72ff"
    property color buttonHighlight: "#3A9BDC"
    property color primaryButton: "#3A9BDC"
    property color mapIndicator: "#3A9BDC"
    property color colorGreen: globalTheme === QGCPalette.Dark ? "#00e04b" : "#008f2d"
    property color colorOrange: globalTheme === QGCPalette.Dark ? "#de8500" : "#bf7539"
    property color colorRed: globalTheme === QGCPalette.Dark ? "#f32836" : "#b52b2b"
}""",
    }
    entries = ["module QGroundControl.Controls"]
    for filename, source in stubs.items():
        (controls / filename).write_text(source, encoding="utf-8")
        prefix = "singleton " if filename == "ScreenTools.qml" else ""
        entries.append(f"{prefix}{Path(filename).stem} 1.0 {filename}")
    (controls / "qmldir").write_text("\n".join(entries) + "\n", encoding="utf-8")
    module = directory / "USV"
    module.mkdir()
    entries = ["module USV"]
    for source in (ROOT / "custom" / "res").glob("*"):
        if source.suffix not in (".qml", ".js"):
            continue
        shutil.copy2(source, module / source.name)
        if source.suffix == ".qml":
            entries.append(f"{source.stem} 1.0 {source.name}")
    (module / "qmldir").write_text("\n".join(entries) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--map-image", type=Path)
    args = parser.parse_args()
    messages = []
    qInstallMessageHandler(lambda kind, context, message: messages.append(message))
    app = QGuiApplication(sys.argv[:1])
    if os.name == "nt":
        QFontDatabase.addApplicationFont("C:/Windows/Fonts/msyh.ttc")
        app.setFont(QFont("Microsoft YaHei", 12))
    with tempfile.TemporaryDirectory(prefix="usv-ui-") as temporary:
        imports = Path(temporary)
        install_mock_imports(imports)
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(imports))
        engine.load(QUrl.fromLocalFile(str(ROOT / "custom" / "tests" / "OperationsFixture.qml")))
        if not engine.rootObjects():
            raise RuntimeError("\n".join(messages))
        window = engine.rootObjects()[0]
        if args.map_image:
            window.setProperty("mapImage", QUrl.fromLocalFile(str(args.map_image.resolve())).toString())
        QTest.qWait(100)
        checks = json.loads(QMetaObject.invokeMethod(window, "verify", Q_RETURN_ARG("QVariant")))
        print(f"PASS: {len(checks)} behavior checks")
        if args.output:
            args.output.mkdir(parents=True, exist_ok=True)
            scenarios = [(1280, 720, 0, "normal"), (1920, 1080, 0, "normal"),
                         (1280, 720, 1, "normal"), (1280, 720, 2, "normal"),
                         (1280, 720, 3, "normal"), (1280, 720, 0, "disconnected"),
                         (1280, 720, 0, "fault"), (1280, 720, 0, "unarmed-auto"),
                         (1280, 720, 0, "task-feedback"), (1280, 720, 0, "emergency-accepted")]
            for width, height, tab, scenario in scenarios:
                window.setWidth(width)
                window.setHeight(height)
                window.setProperty("tabIndex", tab)
                window.scenario(scenario)
                QTest.qWait(100)
                page = window.findChild(QObject, "operationsContent")
                scrollbar = window.findChild(QObject, "operationsScrollBar")
                if page is None or scrollbar is None or page.property("width") + 1 >= scrollbar.property("x"):
                    raise RuntimeError(f"Content overlaps the scroll lane: {width}x{height}, tab {tab}, {scenario}")
                target = args.output / f"operations-{width}x{height}-tab{tab}-{scenario}.png"
                if not window.grabWindow().save(str(target)):
                    raise RuntimeError(f"Cannot save {target}")
                print(target)
        # Real QML runtime warnings are failures, including binding loops.
        problems = [m for m in messages if "TypeError" in m or "ReferenceError" in m
                    or "Unable to assign" in m or "Binding loop" in m or "Error:" in m]
        if problems:
            raise RuntimeError("\n".join(dict.fromkeys(problems)))
        window.close()
        engine.deleteLater()
        app.processEvents()
        print("PASS: no QML binding or type errors")


if __name__ == "__main__":
    main()

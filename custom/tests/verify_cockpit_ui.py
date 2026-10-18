"""Render production cockpit QML against simulated Facts and command ACKs.

The map is a labeled schematic. Navigation instruments use QGC source files;
application services and toolbar integration controls are fixture substitutes.
No vehicle connection or hardware command is made.
"""
import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import PySide6

if os.name == "nt":
    qt_dll_directory = os.add_dll_directory(str(Path(PySide6.__file__).parent))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QMetaObject, QUrl, Qt, Q_RETURN_ARG, qInstallMessageHandler
from PySide6.QtGui import QFont, QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6 import QtQuick, QtQuickControls2
from PySide6.QtTest import QTest

ROOT = Path(__file__).resolve().parents[2]


def install_imports(directory):
    controls = directory / "QGroundControl/Controls"
    controls.mkdir(parents=True)
    (directory / "QGroundControl/qmldir").write_text(
        "module QGroundControl\nsingleton QGroundControl 1.0 QGroundControl.qml\n", encoding="utf-8")
    (directory / "QGroundControl/QGroundControl.qml").write_text('''pragma Singleton
import QtQuick
import QGroundControl.Controls
QtObject {
    property QtObject multiVehicleManager: QtObject { property var activeVehicle: null }
    property QGCPalette globalPalette: QGCPalette {}
    property QtObject settingsManager: QtObject {
        property QtObject flyViewSettings: QtObject {
            property var showAdditionalIndicatorsCompass: ({value: false})
            property var lockNoseUpCompass: ({value: false})
        }
    }
}''', encoding="utf-8")
    stubs = {
        "ScreenTools": '''pragma Singleton
import QtQuick
QtObject {
    property real fontFactor: 1
    property real defaultFontPixelWidth: 9 * fontFactor
    property real defaultFontPixelHeight: 20 * fontFactor
    property real defaultFontPointSize: 12 * fontFactor
    property real smallFontPointSize: 10 * fontFactor
    property real minTouchPixels: 44
    property real toolbarHeight: 60 * fontFactor
    property real panelOpacity: 0.5
}''',
        "QGCLabel": '''import QtQuick
import QtQuick.Controls.Basic
Label { font.pointSize: ScreenTools.defaultFontPointSize; color: "white" }''',
        "QGCPalette": '''import QtQuick
QtObject {
    enum Theme { Light, Dark }
    property int globalTheme: QGCPalette.Dark
    property bool colorGroupEnabled: true
    property color window: "#263139"
    property color windowTransparent: "#df263139"
    property color text: "#f4f7f8"
    property color buttonHighlight: "#258ce3"
    property color mapIndicator: "#258ce3"
    property color colorGreen: "#3bda98"
    property color colorOrange: "#e9a42d"
    property color colorRed: "#ee303d"
}''',
        "QGCToolBarButton": '''import QtQuick
import QtQuick.Controls.Basic
Button { property bool logo: false; implicitWidth: 56; contentItem: Label {text: "Q"; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter} background: Rectangle {color: "#3d446b"} }''',
        "QGCButton": "import QtQuick.Controls.Basic\nButton {}",
        "MainStatusIndicator": '''import QtQuick
import QtQuick.Controls.Basic
Button { property bool armingAllowed: true; property bool compact: false; implicitWidth: 75; text: qsTr("飞控状态"); function dropMainStatusIndicator() {} }''',
        "GuidedActionConfirm": '''import QtQuick
Rectangle { property var guidedController; property var guidedValueSlider; property var messageDisplay; property bool utmspSliderTrigger; property string message: qsTr("原生任务确认区域"); width: 200; color: "#335970"; visible: guidedController && guidedController.confirming }''',
        "ParameterDownloadProgress": "import QtQuick\nItem {}",
    }
    entries = ["module QGroundControl.Controls"]
    for name, source in stubs.items():
        (controls / f"{name}.qml").write_text(source, encoding="utf-8")
        entries.append(f"{'singleton ' if name == 'ScreenTools' else ''}{name} 1.0 {name}.qml")
    shutil.copy2(ROOT / "src/QmlControls/QGCToolInsets.qml", controls)
    entries.append("QGCToolInsets 1.0 QGCToolInsets.qml")
    (controls / "qmldir").write_text("\n".join(entries) + "\n", encoding="utf-8")
    module = directory / "USV"
    module.mkdir()
    entries = ["module USV"]
    for source in (ROOT / "custom/res").iterdir():
        if source.suffix in (".qml", ".js"):
            shutil.copy2(source, module / source.name)
            if source.suffix == ".qml":
                entries.append(f"{source.stem} 1.0 {source.name}")
    (module / "qmldir").write_text("\n".join(entries) + "\n", encoding="utf-8")
    flightmap = directory / "QGroundControl/FlightMap"
    flightmap.mkdir()
    entries = ["module QGroundControl.FlightMap"]
    for name in ("IntegratedCompassAttitude", "IntegratedAttitudeIndicator", "QGCCompassWidget", "CompassDial", "CompassHeadingIndicator"):
        source = (ROOT / f"src/FlightMap/Widgets/{name}.qml").read_text(encoding="utf-8")
        for filename in ("cOGPointer.svg", "compassDottedLine.svg"):
            source = source.replace(f'"/qmlimages/{filename}"', json.dumps((ROOT / f"src/FlightMap/Images/{filename}").as_uri()))
        (flightmap / f"{name}.qml").write_text(source, encoding="utf-8")
        entries.append(f"{name} 1.0 {name}.qml")
    (flightmap / "qmldir").write_text("\n".join(entries) + "\n", encoding="utf-8")
    flyview = directory / "QGroundControl/FlyView"
    flyview.mkdir()
    (flyview / "Unused.qml").write_text("import QtQuick\nQtObject {}", encoding="utf-8")
    (flyview / "qmldir").write_text("module QGroundControl.FlyView\nUnused 1.0 Unused.qml\n", encoding="utf-8")


def call(window, method):
    value = QMetaObject.invokeMethod(window, method, Q_RETURN_ARG("QVariant"))
    return json.loads(value) if isinstance(value, str) else value


def intersects(a, b):
    return a["x"] < b["x"] + b["width"] - 1 and b["x"] < a["x"] + a["width"] - 1 and a["y"] < b["y"] + b["height"] - 1 and b["y"] < a["y"] + a["height"] - 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "build/cockpit-qa-20261014")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    messages = []
    qInstallMessageHandler(lambda kind, context, message: messages.append(message))
    app = QGuiApplication(sys.argv[:1])
    if os.name == "nt":
        QFontDatabase.addApplicationFont("C:/Windows/Fonts/msyh.ttc")
        app.setFont(QFont("Microsoft YaHei", 12))
    with tempfile.TemporaryDirectory(prefix="usv-cockpit-") as temporary:
        imports = Path(temporary)
        install_imports(imports)
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(imports))
        engine.load(QUrl.fromLocalFile(str(ROOT / "custom/tests/CockpitFixture.qml")))
        if not engine.rootObjects():
            raise RuntimeError("\n".join(messages))
        window = engine.rootObjects()[0]
        QTest.qWait(150)
        checks = call(window, "verifyBehavior")
        if not isinstance(checks, list) or len(checks) < 30:
            raise RuntimeError(f"Behavior checks incomplete: {checks}\n" + "\n".join(messages))
        evidence = {"qt": PySide6.__version__, "fixture": __doc__, "behavior": checks, "geometry": [], "runtimeErrors": []}
        cases = [(1920, 1080, 1, False, name) for name in ("sampling", "offline", "emergency")]
        cases += [(1280, 720, 1, False, name) for name in ("sampling", "offline", "emergency", "partial", "timeout", "devices", "diagnostics", "disconnected", "fault", "signal", "baseline", "missing-fields", "collapsed", "confirmation")]
        cases += [(1280, 720, 1.4, False, name) for name in ("sampling", "emergency", "devices", "confirmation")]
        cases += [(1280, 720, 1, True, "sampling"), (900, 600, 1, False, "sampling")]
        failures = []
        for width, height, factor, pip, name in cases:
            window.setWidth(width); window.setHeight(height)
            window.setProperty("fontFactor", factor); window.setProperty("pipVisible", pip)
            window.scenario(name)
            QTest.qWait(150)
            geometry = call(window, "inspectGeometry")
            label = f"{width}x{height}-{factor:g}-{'pip-' if pip else ''}{name}"
            if not isinstance(geometry, dict):
                raise RuntimeError(f"Geometry failed: {geometry}\n" + "\n".join(messages))
            for panel in geometry["panels"]:
                if panel["x"] < -1 or panel["y"] < geometry["toolbarHeight"] - 1 or panel["x"] + panel["width"] > width + 1 or panel["y"] + panel["height"] > height + 1:
                    failures.append(f"{label}: outside viewport: {panel}")
                for obstacle in (geometry["instrument"], geometry["pip"]):
                    if obstacle and intersects(panel, obstacle):
                        failures.append(f"{label}: overlaps native control: {panel['name']}")
            for i, panel in enumerate(geometry["panels"]):
                for other in geometry["panels"][i + 1:]:
                    if intersects(panel, other): failures.append(f"{label}: panel overlap: {panel['name']}, {other['name']}")
            for child in geometry["childBounds"]:
                parent = next(panel for panel in geometry["panels"] if panel["name"] == child["parent"])
                if child["y"] < -1 or child["y"] + child["height"] > parent["height"] + 1:
                    failures.append(f"{label}: panel child overflow: {child['name']}")
                if child["name"].endswith("Body") and child["height"] < 16:
                    failures.append(f"{label}: unreadable scroll viewport: {child['name']}")
            target = args.output / f"cockpit-{label}.png"
            if not window.grabWindow().save(str(target)):
                raise RuntimeError(f"Cannot capture {target}")
            evidence["geometry"].append({"scenario": label, **geometry})
        window.setWidth(900); window.setHeight(600)
        window.setProperty("fontFactor", 1); window.setProperty("pipVisible", False)
        call(window, "prepareKeyboardNavigation")
        QTest.qWait(150)
        keyboard_checks = []
        for _ in range(64):
            QTest.keyClick(window, Qt.Key_Tab)
            QTest.qWait(5)
            focused = call(window, "inspectKeyboardFocus")
            if focused["inside"]:
                keyboard_checks.append(focused)
                if focused["top"] < -1 or focused["bottom"] > focused["height"] + 1:
                    failures.append(f"900x600: keyboard focus hidden by control viewport: {focused}")
        if not keyboard_checks or not any(item["contentY"] > 0 for item in keyboard_checks):
            failures.append("900x600: keyboard test did not reach a scrolled operation")
        evidence["keyboard"] = keyboard_checks
        problems = [message for message in messages if any(marker in message for marker in ("TypeError", "ReferenceError", "Unable to assign", "Binding loop", "Error:", "is not a type", "Cannot assign"))]
        evidence["runtimeErrors"] = list(dict.fromkeys(problems))
        evidence["geometryFailures"] = failures
        (args.output / "qa-evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
        if problems or failures:
            raise RuntimeError("\n".join(problems + failures))
        print(f"PASS: {len(checks)} behavior checks; {len(cases)} viewport/state cases; {len(keyboard_checks)} visible keyboard targets; no QML runtime errors")
        print(args.output)
        window.close()
        engine.deleteLater()
        app.processEvents()


if __name__ == "__main__":
    main()

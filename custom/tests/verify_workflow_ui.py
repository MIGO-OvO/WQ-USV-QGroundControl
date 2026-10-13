"""Exercise the production FlyView overlay with mock telemetry, never hardware.

The QGC toolbar in the fixture is a labeled stand-in; the compass/attitude
components and USV custom layer are loaded from the actual project sources.
"""
import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from verify_operations_ui import (
    ROOT, QFont, QFontDatabase, QGuiApplication, QMetaObject, QObject, QTest,
    QUrl, Q_RETURN_ARG, QQmlApplicationEngine, install_mock_imports,
    qInstallMessageHandler,
)


def install_navigation_imports(directory):
    controls = directory / "QGroundControl" / "Controls"
    shutil.copy2(ROOT / "src/QmlControls/QGCToolInsets.qml", controls)
    with (controls / "qmldir").open("a", encoding="utf-8") as stream:
        stream.write("QGCToolInsets 1.0 QGCToolInsets.qml\n")
    (directory / "QGroundControl/QGroundControl.qml").write_text("""pragma Singleton
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
}""", encoding="utf-8")
    flightmap = directory / "QGroundControl/FlightMap"
    flightmap.mkdir()
    entries = ["module QGroundControl.FlightMap"]
    for name in ("IntegratedCompassAttitude", "IntegratedAttitudeIndicator",
                 "QGCCompassWidget", "CompassDial", "CompassHeadingIndicator"):
        source = (ROOT / f"src/FlightMap/Widgets/{name}.qml").read_text(encoding="utf-8")
        # Resolve fixture assets without registering application-wide resources.
        source = source.replace('"/qmlimages/cOGPointer.svg"',
            json.dumps((ROOT / "src/FlightMap/Images/cOGPointer.svg").as_uri()))
        source = source.replace('"/qmlimages/compassDottedLine.svg"',
            json.dumps((ROOT / "src/FlightMap/Images/compassDottedLine.svg").as_uri()))
        (flightmap / f"{name}.qml").write_text(source, encoding="utf-8")
        entries.append(f"{name} 1.0 {name}.qml")
    (flightmap / "qmldir").write_text("\n".join(entries) + "\n", encoding="utf-8")
    flyview = directory / "QGroundControl/FlyView"
    flyview.mkdir()
    (flyview / "Unused.qml").write_text("import QtQuick\nQtObject {}", encoding="utf-8")
    (flyview / "qmldir").write_text("module QGroundControl.FlyView\nUnused 1.0 Unused.qml\n", encoding="utf-8")


def call(window, method, *args):
    if args:
        # All fixture scenario names are controlled constants.
        window.scenario(*args)
        return None
    value = QMetaObject.invokeMethod(window, method, Q_RETURN_ARG("QVariant"))
    return json.loads(value) if isinstance(value, str) else value


def intersects(a, b):
    return (a["x"] < b["x"] + b["width"] - 1 and b["x"] < a["x"] + a["width"] - 1
            and a["y"] < b["y"] + b["height"] - 1 and b["y"] < a["y"] + a["height"] - 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "build/workflow-ui-preview")
    args = parser.parse_args()
    messages = []
    qInstallMessageHandler(lambda kind, context, message: messages.append(message))
    app = QGuiApplication(sys.argv[:1])
    if os.name == "nt":
        QFontDatabase.addApplicationFont("C:/Windows/Fonts/msyh.ttc")
        app.setFont(QFont("Microsoft YaHei", 12))
    with tempfile.TemporaryDirectory(prefix="usv-workflow-") as temporary:
        imports = Path(temporary)
        install_mock_imports(imports)
        install_navigation_imports(imports)
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(imports))
        engine.load(QUrl.fromLocalFile(str(ROOT / "custom/tests/WorkflowFixture.qml")))
        if not engine.rootObjects():
            raise RuntimeError("\n".join(messages))
        window = engine.rootObjects()[0]
        QTest.qWait(350)
        dock = window.findChild(QObject, "usvSamplingWorkflow")
        if dock is None:
            raise RuntimeError("Production workflow was not created\n" + "\n".join(messages))
        window.setProperty("workflow", dock)
        checks = call(window, "verifyBehavior")
        if not isinstance(checks, list) or len(checks) < 20:
            raise RuntimeError(f"Behavior check did not complete: {checks}\n" + "\n".join(messages))
        args.output.mkdir(parents=True, exist_ok=True)
        evidence = {"behavior": checks, "geometry": [], "animations": [],
                    "fixture": "Production QML, mock Facts, labeled toolbar stand-in, official compass sources"}

        def capture(name):
            target = args.output / f"workflow-{name}.png"
            if not window.grabWindow().save(str(target)):
                raise RuntimeError(f"Cannot capture {target}")

        cases = [(1280, 720, 1, False, "signal"), (1920, 1080, 1, False, "ready"),
                 (1280, 720, 1, False, "collapsed"), (1280, 720, 1, False, "devices"),
                 (1280, 720, 1, False, "diagnostics"), (1280, 720, 1, False, "accepted"),
                 (1280, 720, 1, False, "preparing"),
                 (1280, 720, 1, False, "paused"), (1280, 720, 1, False, "disconnected"),
                 (1280, 720, 1, False, "collapsed-fault"), (900, 600, 1, False, "ready"),
                 (1280, 720, 1.4, False, "devices"), (1280, 720, 1, True, "devices")]
        for width, height, factor, pip, scenario in cases:
            window.setWidth(width)
            window.setHeight(height)
            window.setProperty("fontFactor", factor)
            window.setProperty("pipVisible", pip)
            call(window, "scenario", scenario)
            QTest.qWait(500)
            geometry = call(window, "inspectGeometry")
            if not isinstance(geometry, dict):
                raise RuntimeError(f"Geometry check failed: {geometry}\n" + "\n".join(messages))
            name = f"{width}x{height}-{factor:g}-{'pip-' if pip else ''}{scenario}"
            if (geometry["x"] < 0 or geometry["y"] < 0
                    or geometry["x"] + geometry["width"] > width + 1
                    or geometry["y"] + geometry["height"] > height + 1):
                raise RuntimeError(f"Dock outside viewport: {name}: {geometry}")
            for obstacle in (geometry["instrument"], geometry["pip"]):
                if obstacle and intersects(geometry, obstacle):
                    raise RuntimeError(f"Dock overlaps native controls: {name}: {geometry}")
            content = window.findChild(QObject, "workflowContent")
            scrollbar = window.findChild(QObject, "workflowScrollBar")
            if content.property("x") + content.property("width") >= scrollbar.property("x"):
                raise RuntimeError(f"No scroll lane: {name}")
            evidence["geometry"].append({"scenario": name, **geometry})
            if scenario in ("devices", "diagnostics"):
                detail = call(window, "inspectDetailVisibility")
                if detail["returnY"] < -1 or detail["returnY"] + detail["returnHeight"] > detail["bodyHeight"] + 1:
                    raise RuntimeError(f"Detail return actions out of view: {name}: {detail}")
                if not detail["controls"] or any(rect["y"] < -1 or rect["y"] + rect["height"] > detail["bodyHeight"] + 1 for rect in detail["controls"]):
                    raise RuntimeError(f"Expanded detail controls out of view: {name}: {detail}")
                evidence["geometry"][-1]["detailVisibility"] = detail
            capture(name)

        window.setWidth(1280)
        window.setHeight(720)
        window.setProperty("fontFactor", 1)
        window.setProperty("pipVisible", False)
        call(window, "scenario", "ready")
        QTest.qWait(400)
        start = dock.property("height")
        QMetaObject.invokeMethod(dock, "toggleExpanded")
        QTest.qWait(80)
        middle = dock.property("height")
        body = window.findChild(QObject, "workflowBody")
        if body.property("enabled") or not middle < start:
            raise RuntimeError("Collapse did not immediately disable content and animate height")
        capture("collapse-midpoint")
        QTest.qWait(250)
        end = dock.property("height")
        toggle = window.findChild(QObject, "workflowExpandButton")
        if not end < middle or not toggle.property("activeFocus"):
            raise RuntimeError("Collapse did not settle or restore header focus")
        QMetaObject.invokeMethod(dock, "toggleExpanded")
        QTest.qWait(50)
        QMetaObject.invokeMethod(dock, "toggleExpanded")
        QTest.qWait(40)
        QMetaObject.invokeMethod(dock, "toggleExpanded")
        QTest.qWait(300)
        if not dock.property("expanded") or abs(dock.property("height") - start) > 1:
            raise RuntimeError("Rapid toggle did not settle at the expanded height")
        evidence["animations"].append({"start": start, "middle": middle, "end": end,
            "hiddenContentDisabled": True, "focusReturned": True, "rapidToggleSettled": True})

        emergency = dock.property("emergencyController")
        QMetaObject.invokeMethod(emergency, "requestEmergencyStop")
        QTest.qWait(100)
        dialog = window.findChild(QObject, "usvEmergencyDialog")
        if dialog is None or not dialog.property("visible"):
            raise RuntimeError("Hidden controller cannot open emergency confirmation")
        capture("emergency-confirmation")
        QMetaObject.invokeMethod(dialog, "close")
        problems = [m for m in messages if any(marker in m for marker in
            ("TypeError", "ReferenceError", "Unable to assign", "Binding loop", "Error:", "is not a type", "Cannot assign"))]
        if problems:
            raise RuntimeError("\n".join(dict.fromkeys(problems)))
        evidence["runtimeErrors"] = []
        (args.output / "qa-evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"PASS: {len(checks)} behavior checks, {len(cases)} viewport/state cases, animation, focus, emergency dialog")
        print(args.output)
        window.close()
        engine.deleteLater()
        app.processEvents()


if __name__ == "__main__":
    main()

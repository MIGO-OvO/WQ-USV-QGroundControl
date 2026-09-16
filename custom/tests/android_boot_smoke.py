"""CI-only, no vehicle: install, launch, background/resume and retain evidence."""
import pathlib
import re
import subprocess
import sys
import time

PACKAGE = "org.wqusv.qgroundcontrol"
ACTIVITY = "org.mavlink.qgroundcontrol.QGCActivity"


def adb(*args):
    return subprocess.check_output(["adb", *args], text=True, stderr=subprocess.STDOUT)


def main():
    apk, output = sys.argv[1:]
    output = pathlib.Path(output)
    output.mkdir(parents=True, exist_ok=True)
    try:
        adb("logcat", "-c")
        adb("shell", "wm", "size", "1280x800")
        adb("shell", "wm", "density", "160")
        adb("install", "-r", apk)
        # Same signer/version upgrade must also be accepted, without clearing data.
        adb("install", "-r", apk)
        adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/{ACTIVITY}")
        for _ in range(12):
            time.sleep(5)
            assert adb("shell", "pidof", PACKAGE).strip(), "Application exited during cold boot"
        log = adb("logcat", "-d", "-v", "threadtime")
        assert "USV boot: root QML object created" in log, "No positive QML boot marker"
        assert re.search(r"Override resource check:.*FlyViewCustomLayer.qml.*exists: true", log), "USV override missing"
        assert not re.search(r"QQmlApplicationEngine failed|module .* is not installed|Type USV\w+ unavailable|FATAL EXCEPTION|Fatal signal", log), "Boot errors in logcat"
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(3)
        adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/{ACTIVITY}")
        time.sleep(5)
        assert adb("shell", "pidof", PACKAGE).strip(), "Application exited on resume"
        resumed_log = adb("logcat", "-d", "-v", "threadtime")
        assert not re.search(r"QQmlApplicationEngine failed|module .* is not installed|Type USV\w+ unavailable|FATAL EXCEPTION|Fatal signal", resumed_log), "Resume errors in logcat"
        with (output / "tablet.png").open("wb") as screenshot:
            subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=screenshot, check=True)
    finally:
        (output / "logcat.txt").write_text(adb("logcat", "-d", "-v", "threadtime"), encoding="utf-8")
        (output / "activity.txt").write_text(adb("shell", "dumpsys", "activity", "activities"), encoding="utf-8")


if __name__ == "__main__":
    main()

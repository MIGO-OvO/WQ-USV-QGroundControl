"""Offline checks of the APK payload gate itself. No APK or SDK required."""
import pathlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = pathlib.Path(__file__).with_name("verify_apk_payload.py")
LIBRARY = "lib/arm64-v8a/libQGroundControl_arm64-v8a.so"


def build_apk(directory, names, encoding="utf-16-le", library=LIBRARY):
    apk = pathlib.Path(directory) / "fake.apk"
    with zipfile.ZipFile(apk, "w") as archive:
        if library:
            archive.writestr(library, b"\x00".join(name.encode(encoding) for name in names))
    return apk


def run(apk):
    return subprocess.run([sys.executable, str(SCRIPT), str(apk)], capture_output=True, text=True)


class ApkPayloadGateTests(unittest.TestCase):
    def test_utf16_payload_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = build_apk(directory, ("FlyViewCustomLayer.qml", "USVSamplingDataView.qml", "usv_zh_CN.qm"))
            result = run(apk)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("USV payload present", result.stdout)

    def test_ascii_payload_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = build_apk(directory, ("FlyViewCustomLayer.qml", "USVSamplingDataView.qml", "usv_zh_CN.qm"),
                             encoding="ascii")
            result = run(apk)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_translation_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = build_apk(directory, ("FlyViewCustomLayer.qml", "USVSamplingDataView.qml"))
            result = run(apk)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usv_zh_CN.qm", result.stdout + result.stderr)

    def test_missing_override_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = build_apk(directory, ("USVSamplingDataView.qml", "usv_zh_CN.qm"))
            result = run(apk)
        self.assertNotEqual(result.returncode, 0)

    def test_no_native_library_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = build_apk(directory, (), library=None)
            result = run(apk)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No QGroundControl native library", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()

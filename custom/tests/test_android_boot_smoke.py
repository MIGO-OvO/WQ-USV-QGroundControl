"""Exercise the boot gate itself without claiming to emulate Android."""
import pathlib
import subprocess
import tempfile
import unittest
from unittest import mock

import android_boot_smoke as smoke


GOOD_LOG = (
    "USV boot: root QML object created\n"
    'Override resource check: ":/USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml" exists: true\n'
)


class AndroidBootGateTests(unittest.TestCase):
    def run_gate(self, cold_log=GOOD_LOG, resume_log=GOOD_LOG, missing_process=False, install_error=False):
        logs = iter([cold_log, resume_log, resume_log])

        def adb(*args):
            if args[0] == "install" and install_error:
                raise subprocess.CalledProcessError(1, ["adb", *args])
            if args[:2] == ("logcat", "-d"):
                return next(logs, resume_log)
            if args[:2] == ("shell", "pidof"):
                return "" if missing_process else "1234"
            return "OK"

        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(smoke.sys, "argv", ["smoke", "test.apk", directory]), \
                    mock.patch.object(smoke, "adb", side_effect=adb), \
                    mock.patch.object(smoke.time, "sleep"), \
                    mock.patch.object(smoke.subprocess, "run"):
                try:
                    smoke.main()
                finally:
                    self.assertTrue((pathlib.Path(directory) / "logcat.txt").is_file())
                    self.assertTrue((pathlib.Path(directory) / "activity.txt").is_file())

    def test_positive_boot_and_resume(self):
        self.run_gate()

    def test_live_process_without_qml_is_failure(self):
        with self.assertRaisesRegex(AssertionError, "QML boot marker"):
            self.run_gate(cold_log="alive")

    def test_missing_custom_resource_is_failure(self):
        with self.assertRaisesRegex(AssertionError, "override missing"):
            self.run_gate(cold_log="USV boot: root QML object created")

    def test_process_exit_is_failure(self):
        with self.assertRaisesRegex(AssertionError, "exited"):
            self.run_gate(missing_process=True)

    def test_missing_qml_module_is_failure(self):
        with self.assertRaisesRegex(AssertionError, "Boot errors"):
            self.run_gate(cold_log=GOOD_LOG + '\nmodule "USV" is not installed')

    def test_resume_crash_is_failure(self):
        with self.assertRaisesRegex(AssertionError, "Resume errors"):
            self.run_gate(resume_log=GOOD_LOG + "\nFATAL EXCEPTION: main")

    def test_install_failure_still_collects_logs(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_gate(install_error=True)


if __name__ == "__main__":
    unittest.main()

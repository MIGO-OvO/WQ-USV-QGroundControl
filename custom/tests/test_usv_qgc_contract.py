import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKSPACE_ROOT = REPO_ROOT.parent
OLD_STATUS_THREE_TEXT = "载荷故障，" + "请检查采样模块"

PAYLOAD_NAMED_VALUE_FIELDS = {
    "USV_VOLT": ("voltage", "voltage"),
    "USV_ABS": ("absorbance", "absorbance"),
    "PUMP_X": ("pump_x", "pumpX"),
    "PUMP_Y": ("pump_y", "pumpY"),
    "PUMP_Z": ("pump_z", "pumpZ"),
    "PUMP_A": ("pump_a", "pumpA"),
    "USV_STAT": ("status", "status"),
    "USV_PKT": ("pkt_count", "packetCount"),
    "USV_STEP": ("automation_step", "stepCurrent"),
    "USV_STOT": ("automation_total", "stepTotal"),
    "USV_SCNT": ("sample_count", "sampleCount"),
    "USV_PERR": ("pid_error", "pidError"),
    "USV_PMOD": ("pid_mode", "pidMode"),
    "USV_BSET": ("baseline_set", "baselineSet"),
    "USV_REF": ("reference_voltage", "referenceVoltage"),
    "USV_BASE": ("baseline_voltage", "baselineVoltage"),
    "USV_VLD": ("spectrometer_valid", "spectrometerValid"),
    "USV_JTMP": ("jetson_temp", "jetsonTemp"),
    "USV_ETMP": ("detector_temp", "detectorTemp"),
    "USV_JCPU": ("jetson_cpu", "jetsonCpu"),
    "USV_JMEM": ("jetson_memory", "jetsonMemory"),
    "USV_EHEAP": ("detector_heap", "detectorHeap"),
}


class USVQGCContractTests(unittest.TestCase):
    def test_fact_group_declares_and_parses_baseline_and_detector_valid_facts(self):
        header = (REPO_ROOT / "custom" / "src" / "USVPayloadFactGroup.h").read_text(encoding="utf-8")
        source = (REPO_ROOT / "custom" / "src" / "USVPayloadFactGroup.cc").read_text(encoding="utf-8")
        metadata = (REPO_ROOT / "custom" / "res" / "USVPayloadFactGroup.json").read_text(encoding="utf-8")

        for fact_name in (
            "baselineSet",
            "referenceVoltage",
            "baselineVoltage",
            "spectrometerValid",
            "jetsonTemp",
            "detectorTemp",
            "jetsonCpu",
            "jetsonMemory",
            "detectorHeap",
        ):
            self.assertIn(fact_name, header)
            self.assertIn(fact_name, metadata)
        for mav_name in ("USV_BSET", "USV_REF", "USV_BASE", "USV_VLD", "USV_JTMP", "USV_ETMP", "USV_JCPU", "USV_JMEM", "USV_EHEAP"):
            self.assertIn(mav_name, source)

    def test_ui_exposes_detector_baseline_sampling_and_survey_workflow(self):
        payload_panel = (REPO_ROOT / "custom" / "res" / "USVPayloadPanel.qml").read_text(encoding="utf-8")
        action_bar = (REPO_ROOT / "custom" / "res" / "USVActionBar.qml").read_text(encoding="utf-8")
        actions = json.loads((REPO_ROOT / "custom" / "res" / "actions" / "usv_actions.json").read_text(encoding="utf-8"))
        action_cmds = {entry["mavCmd"] for entry in actions["actions"]}

        for cmd in (31010, 31015, 31016, 31017, 31018, 31019):
            self.assertIn(f"_cmd", payload_panel)
            self.assertIn(str(cmd), payload_panel)
            self.assertIn(str(cmd), action_bar)
            self.assertIn(cmd, action_cmds)
        self.assertIn("param1", action_bar)
        self.assertIn("baselineSet", payload_panel)
        self.assertIn("spectrometerValid", payload_panel)
        self.assertIn("启动信号采集", payload_panel)
        self.assertIn("设基线", payload_panel)
        self.assertIn("开始点采样", payload_panel)
        self.assertIn("任务前准备", payload_panel)
        self.assertIn("飞控连接", payload_panel)
        self.assertIn("载荷链路", payload_panel)
        self.assertIn("有效信号", payload_panel)
        self.assertIn("_readyForPointSample", payload_panel)
        self.assertIn("!!vehicle && _linkOk && spectrometerValid && baselineSet && _canStartPointSample", payload_panel)
        self.assertNotIn('_canStartPointSample ? qsTr("可执行")', payload_panel)
        self.assertNotIn("任务已上传", payload_panel)
        self.assertNotIn("vehicle.sendCommand(_payloadCompId, cmdId, true", payload_panel)
        self.assertNotIn(OLD_STATUS_THREE_TEXT, payload_panel)
        self.assertNotIn(OLD_STATUS_THREE_TEXT, action_bar)

    def test_status_three_is_task_failure_not_hardware_fault(self):
        layout = (REPO_ROOT / "custom" / "res" / "USVFlyViewLayout.js").read_text(encoding="utf-8")
        payload_panel = (REPO_ROOT / "custom" / "res" / "USVPayloadPanel.qml").read_text(encoding="utf-8")
        fly_layer = (REPO_ROOT / "custom" / "res" / "USVFlyViewCustomLayer.qml").read_text(encoding="utf-8")
        summary_strip = (REPO_ROOT / "custom" / "res" / "USVPayloadSummaryStrip.qml").read_text(encoding="utf-8")
        data_tokens = (REPO_ROOT / "custom" / "res" / "USVSamplingDataTokens.js").read_text(encoding="utf-8")
        data_view = (REPO_ROOT / "custom" / "res" / "USVSamplingDataView.qml").read_text(encoding="utf-8")
        metadata = json.loads((REPO_ROOT / "custom" / "res" / "USVPayloadFactGroup.json").read_text(encoding="utf-8"))
        status_fact = next(entry for entry in metadata["QGC.MetaData.Facts"] if entry["name"] == "status")

        self.assertIn('case StatusFault: return "任务失败"', layout)
        self.assertIn("USVLayout.statusText(payloadStatus)", payload_panel)
        self.assertIn("采样任务失败，请检查流程前置条件", fly_layer)
        self.assertIn("USVLayout.statusText(payloadStatus)", summary_strip)
        self.assertIn("USVLayout.statusText(payloadStatus)", data_view)
        self.assertNotIn("function statusText(st)", payload_panel)
        self.assertNotIn("function statusText(st)", summary_strip)
        self.assertNotIn("function statusText(status)", data_tokens)
        self.assertNotIn("SDTokens.statusText", data_view)
        self.assertIn("任务失败", status_fact["enumStrings"].split(",")[3])
        self.assertNotIn(OLD_STATUS_THREE_TEXT, fly_layer)
        self.assertNotIn("故障", status_fact["enumStrings"].split(",")[3])
        self.assertNotIn('return qsTr("故障")', payload_panel)
        self.assertNotIn('return qsTr("故障")', summary_strip)

    def test_layout_declares_surveying_status_and_absorbance_gate(self):
        layout = (REPO_ROOT / "custom" / "res" / "USVFlyViewLayout.js").read_text(encoding="utf-8")
        tokens = (REPO_ROOT / "custom" / "res" / "USVSamplingDataTokens.js").read_text(encoding="utf-8")
        data_view = (REPO_ROOT / "custom" / "res" / "USVSamplingDataView.qml").read_text(encoding="utf-8")

        self.assertIn("StatusSurveying = 14", layout)
        self.assertIn("shouldSampleAbsorbance", layout)
        self.assertIn("baselineSet", data_view)
        self.assertIn("shouldSampleAbsorbance", data_view)
        self.assertNotIn("SDTokens.Status", data_view)

    def test_payload_named_value_fields_match_across_ros_firmware_and_qgc(self):
        bridge = (WORKSPACE_ROOT / "src" / "usv_ros" / "scripts" / "usv_mavlink_router_bridge.py").read_text(encoding="utf-8")
        firmware_cache = (WORKSPACE_ROOT / "ardupilot-usv" / "Rover" / "GCS_MAVLink_Rover.cpp").read_text(encoding="utf-8")
        firmware_forward = (WORKSPACE_ROOT / "ardupilot-usv" / "Rover" / "sensors.cpp").read_text(encoding="utf-8")
        rover_header = (WORKSPACE_ROOT / "ardupilot-usv" / "Rover" / "Rover.h").read_text(encoding="utf-8")
        qgc_source = (REPO_ROOT / "custom" / "src" / "USVPayloadFactGroup.cc").read_text(encoding="utf-8")
        metadata = json.loads((REPO_ROOT / "custom" / "res" / "USVPayloadFactGroup.json").read_text(encoding="utf-8"))
        fact_names = {entry["name"] for entry in metadata["QGC.MetaData.Facts"]}

        for mav_name, (firmware_member, qgc_fact) in PAYLOAD_NAMED_VALUE_FIELDS.items():
            with self.subTest(mav_name=mav_name):
                self.assertIn(mav_name, bridge)
                self.assertIn(mav_name, firmware_cache)
                self.assertIn(mav_name, firmware_forward)
                self.assertIn(firmware_member, rover_header)
                self.assertIn(mav_name, qgc_source)
                self.assertIn(qgc_fact, fact_names)

    def test_custom_readme_scopes_px4_support_to_ui_layer(self):
        readme = (REPO_ROOT / "custom" / "README.md").read_text(encoding="utf-8")

        self.assertIn("PX4 | 1.14+ | ⚠️ UI 兼容", readme)
        self.assertIn("完整 USV 采样 mission 闭环当前以 ArduRover 定制固件为准", readme)
        self.assertNotIn("| PX4 | 1.14+ | ✅ 完全支持 |", readme)

    def test_sampling_data_view_avoids_qtcharts_heap_sensitive_series_mutation(self):
        data_view = (REPO_ROOT / "custom" / "res" / "USVSamplingDataView.qml").read_text(encoding="utf-8")

        self.assertNotIn("import QtCharts", data_view)
        self.assertNotIn("ChartView", data_view)
        self.assertNotIn("LineSeries", data_view)
        self.assertNotIn(".remove(0)", data_view)
        self.assertIn("Canvas", data_view)
        self.assertIn("_voltagePoints", data_view)
        self.assertIn("_absorbancePoints", data_view)
        self.assertIn("requestPaint", data_view)

    def test_sampling_data_view_has_quiet_teardown_path(self):
        data_view = (REPO_ROOT / "custom" / "res" / "USVSamplingDataView.qml").read_text(encoding="utf-8")
        custom_qml = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (REPO_ROOT / "custom" / "res").glob("*.qml")
        )

        self.assertNotIn("Component.onDestruction", data_view)
        self.assertNotIn("onWidthChanged: requestPaint()", data_view)
        self.assertNotIn("onHeightChanged: requestPaint()", data_view)
        self.assertIn("property bool _pageActive: true", data_view)
        self.assertIn("function prepareForUnload()", data_view)
        self.assertIn("sampleTimer.stop()", data_view)
        self.assertIn("durationTimer.stop()", data_view)
        self.assertIn("running: root._pageActive && root._hasPayloadGroup", data_view)
        self.assertIn("function _requestChartPaint()", data_view)
        self.assertIn("if (!root._pageActive)", data_view)
        self.assertEqual(data_view.count("chartCanvas.requestPaint()"), 1)
        self.assertNotIn("import QtCharts", custom_qml)
        self.assertNotIn("ChartView", custom_qml)
        self.assertNotIn("LineSeries", custom_qml)

    def test_main_window_prepares_tool_page_before_loader_unload(self):
        main_window = (REPO_ROOT / "src" / "UI" / "MainWindow.qml").read_text(encoding="utf-8")

        self.assertIn("function _prepareToolDrawerItemForUnload()", main_window)
        self.assertIn("prepareForUnload", main_window)
        self.assertIn("_prepareToolDrawerItemForUnload()", main_window)
        self.assertLess(
            main_window.index("_prepareToolDrawerItemForUnload()"),
            main_window.index('toolDrawerLoader.source = ""'),
        )

    def test_usv_payload_member_facts_are_cpp_owned(self):
        header = (REPO_ROOT / "custom" / "src" / "USVPayloadFactGroup.h").read_text(encoding="utf-8")
        source = (REPO_ROOT / "custom" / "src" / "USVPayloadFactGroup.cc").read_text(encoding="utf-8")

        self.assertIn("void _markFactsCppOwned();", header)
        self.assertIn("#include <QtQml/QQmlEngine>", source)
        self.assertIn("USVPayloadFactGroup::_markFactsCppOwned()", source)
        self.assertIn("_markFactsCppOwned();", source)
        self.assertIn("const std::array<Fact*, 23> facts", source)
        self.assertIn("QQmlEngine::setObjectOwnership", source)
        self.assertIn("QQmlEngine::CppOwnership", source)

        for fact_member in (
            "_voltageFact",
            "_absorbanceFact",
            "_pumpXFact",
            "_pumpYFact",
            "_pumpZFact",
            "_pumpAFact",
            "_statusFact",
            "_linkActiveFact",
            "_packetCountFact",
            "_stepCurrentFact",
            "_stepTotalFact",
            "_sampleCountFact",
            "_pidErrorFact",
            "_pidModeFact",
            "_baselineSetFact",
            "_referenceVoltageFact",
            "_baselineVoltageFact",
            "_spectrometerValidFact",
            "_jetsonTempFact",
            "_detectorTempFact",
            "_jetsonCpuFact",
            "_jetsonMemoryFact",
            "_detectorHeapFact",
        ):
            self.assertIn(f"&{fact_member}", source)

    def test_windows_crt_assert_hook_prints_stack_trace(self):
        platform_source = (REPO_ROOT / "src" / "Utilities" / "Platform.cc").read_text(encoding="utf-8")
        cmake = (REPO_ROOT / "src" / "CMakeLists.txt").read_text(encoding="utf-8")

        self.assertIn("DumpWindowsStackTrace", platform_source)
        self.assertIn("CaptureStackBackTrace", platform_source)
        self.assertIn("SymFromAddr", platform_source)
        self.assertIn("SymGetLineFromAddr64", platform_source)
        self.assertIn("QGC: CRT assert stack", platform_source)
        self.assertIn("qgc-crt-assert-stack.log", platform_source)
        self.assertIn("CreateFileA", platform_source)
        self.assertLess(
            platform_source.index("_CrtSetReportHook2"),
            platform_source.index("if (quietWindowsAsserts)"),
        )
        self.assertIn("Dbghelp", cmake)

    def test_qgc_declares_diagnostics_manual_tool_page_and_web_api_client(self):
        dropdown = (REPO_ROOT / "custom" / "res" / "USVSelectViewDropdown.qml").read_text(encoding="utf-8")
        page = REPO_ROOT / "custom" / "res" / "USVDiagnosticsManualView.qml"
        cmake = (REPO_ROOT / "custom" / "CMakeLists.txt").read_text(encoding="utf-8")
        page_text = page.read_text(encoding="utf-8") if page.exists() else ""

        self.assertIn("USVDiagnosticsManualView.qml", dropdown)
        self.assertIn("USVDiagnosticsManualView.qml", cmake)
        self.assertIn("http://10.42.0.1:5000", page_text)
        self.assertIn("/api/diagnostics/link", page_text)
        self.assertIn("/api/manual/pump-step", page_text)
        self.assertIn("/api/manual/mode", page_text)
        self.assertIn("LocalStorage", page_text)
        self.assertIn("XMLHttpRequest", page_text)

    def test_payload_panel_has_pending_command_feedback_and_timeout(self):
        payload_panel = (REPO_ROOT / "custom" / "res" / "USVPayloadPanel.qml").read_text(encoding="utf-8")

        self.assertIn("_pendingCommand", payload_panel)
        self.assertIn("_commandTimeoutMs", payload_panel)
        self.assertIn("commandTimeoutTimer", payload_panel)
        self.assertIn("发送中", payload_panel)
        self.assertIn("_clearPendingCommand", payload_panel)
        self.assertIn("enabled: modelData.en && !_hasPendingCommand", payload_panel)
        self.assertIn("_clearPendingCommand(command)", payload_panel)

    def test_payload_panel_allows_sampling_restart_after_completion_or_hold(self):
        payload_panel = (REPO_ROOT / "custom" / "res" / "USVPayloadPanel.qml").read_text(encoding="utf-8")

        self.assertIn("property bool _canStartPointSample", payload_panel)
        self.assertIn("payloadStatus === _stSamplingDone", payload_panel)
        self.assertIn("payloadStatus === _stHoldNoMission", payload_panel)
        self.assertIn("en: vehicle && _linkOk && spectrometerValid && baselineSet && _canStartPointSample", payload_panel)
        self.assertNotIn("spectrometerValid && baselineSet && payloadStatus === _stIdle", payload_panel)

    def test_rover_plan_metadata_keeps_manual_actions_out(self):
        metadata = json.loads((REPO_ROOT / "src" / "MissionManager" / "MavCmdInfoRover.json").read_text(encoding="utf-8"))
        actions = json.loads((REPO_ROOT / "custom" / "res" / "actions" / "usv_actions.json").read_text(encoding="utf-8"))
        payload_panel = (REPO_ROOT / "custom" / "res" / "USVPayloadPanel.qml").read_text(encoding="utf-8")
        commands = {entry["id"]: entry for entry in metadata["mavCmdInfo"]}
        action_cmds = {entry["mavCmd"] for entry in actions["actions"]}

        self.assertIn(42702, commands)
        for manual_cmd in range(31010, 31020):
            self.assertNotIn(manual_cmd, commands)
            self.assertIn(manual_cmd, action_cmds)
        self.assertNotIn(42702, action_cmds)
        self.assertNotIn("42702", payload_panel)
        sample = commands[42702]
        self.assertEqual(sample["rawName"], "MAV_CMD_NAV_SCRIPT_TIME")
        self.assertEqual(sample["friendlyName"], "定点采样任务项")
        self.assertEqual(sample["category"], "USV")
        self.assertFalse(sample["specifiesCoordinate"])
        self.assertTrue(sample["friendlyEdit"])
        self.assertEqual(sample["param1"]["default"], 1)
        self.assertEqual(sample["param1"]["min"], 1)
        self.assertEqual(sample["param1"]["max"], 1)
        self.assertEqual(sample["param2"]["default"], 255)
        self.assertEqual(sample["param2"]["max"], 255)
        self.assertIn("Plan only", sample["description"])
        self.assertIn("USV_SMPL", sample["description"])
        self.assertIn("USV_DONE", sample["description"])
        self.assertIn("param1 固定为 1", sample["description"])
        self.assertIn("不要作为载荷面板手动命令发送", sample["description"])

    def test_action_bar_does_not_bypass_payload_panel_gates(self):
        action_bar = (REPO_ROOT / "custom" / "res" / "USVActionBar.qml").read_text(encoding="utf-8")

        self.assertIn('vehicle.getFact("usvPayload.linkActive")', action_bar)
        self.assertIn('vehicle.getFact("usvPayload.baselineSet")', action_bar)
        self.assertIn('vehicle.getFact("usvPayload.spectrometerValid")', action_bar)
        self.assertIn("payloadStatus === USVLayout.StatusNavigating", action_bar)
        self.assertIn("payloadStatus === USVLayout.StatusHolding", action_bar)
        self.assertIn("payloadStatus === USVLayout.StatusWaitingStable", action_bar)
        self.assertIn("payloadStatus === USVLayout.StatusResumingAuto", action_bar)
        self.assertIn("en: vehicle && _linkOk && spectrometerValid && payloadStatus !== USVLayout.StatusFault", action_bar)
        self.assertIn("en: vehicle && _linkOk && spectrometerValid && baselineSet && _canStartPointSample", action_bar)
        self.assertIn("en: vehicle && _linkOk && spectrometerValid && baselineSet && payloadStatus !== USVLayout.StatusFault && payloadStatus !== USVLayout.StatusSurveying", action_bar)
        self.assertIn('cmd: _cmdSpectroStop, param1: 0, en: vehicle && _linkOk', action_bar)


if __name__ == "__main__":
    unittest.main()

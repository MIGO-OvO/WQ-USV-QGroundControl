# WQ-USV-QGroundControl Agent Knowledge Base

Generated: 2026-06-15
Branch: codex/qgc-mission-sampling-metadata
Commit: 0bf769338

## OVERVIEW

定制 QGroundControl 仓库。USV 项目改动优先落在 `custom/`，上游 QGC `src/` 只在定制层无法完成时小范围修改。

## WHERE TO LOOK

| 任务 | 位置 |
|---|---|
| USV 定制说明 | `custom/README.md` |
| 构建入口 | `Makefile`、`CMakeLists.txt`、`custom/CMakeLists.txt` |
| 固件插件 | `custom/src/FirmwarePlugin/USVFirmwarePlugin.cc` |
| 载荷 Fact | `custom/src/USVPayloadFactGroup.cc`、`.h` |
| 载荷面板 | `custom/res/USVPayloadPanel.qml`、`USVPayloadDetailPanel.qml` |
| FlyView 定制 | `custom/res/USVFlyViewCustomLayer.qml` |
| 采样数据页 | `custom/res/USVSamplingDataView.qml` |
| 命令动作 | `custom/res/actions/usv_actions.json` |

## CONVENTIONS

- 遵守 `.github/copilot-instructions.md`：参数用 Fact System，active vehicle 必须判空，固件差异走 `vehicle->firmwarePlugin()`。
- MAVLink 字段和命令先核对 `../ardupilot-usv/Rover/` 和 `../src/usv_ros/scripts/`。
- 航线定点采样使用 `MAV_CMD_NAV_SCRIPT_TIME(param1=1)`；`31010` 仅为手动点采样。
- `usvPayload` FactGroup 是 QML 访问载荷状态的主入口。
- QML 尺寸使用 `ScreenTools.defaultFontPixelHeight/Width`，颜色使用 `QGCPalette`，避免硬编码。
- QGC 构建由用户本地 Qt/QGC 环境最终验证；Agent 当前可做静态核对和局部文本检查。

## ANTI-PATTERNS

- 在 QGC 第一阶段实现污染物热力图；当前热力图归 ROS/Web。
- 大范围改上游 QGC 通用模块来实现 USV 可在 `custom/` 完成的需求。
- 提交 `build/`、`.cache/`、Qt Creator 临时目录。

## COMMANDS

```bash
rg -n "USVPayload|usvPayload|31010|31019|MAV_CMD_NAV_SCRIPT_TIME|NAMED_VALUE_FLOAT" custom
```

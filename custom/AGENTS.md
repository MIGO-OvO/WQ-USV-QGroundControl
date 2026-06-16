# QGC custom Agent Rules

## OVERVIEW

USV 定制层：QML 覆盖、USV QML 模块、固件插件、载荷 FactGroup、采样数据页和动作定义。

## STRUCTURE

```text
custom/
├── cmake/CustomOverrides.cmake
├── CMakeLists.txt
├── custom.qrc
├── res/
│   ├── USVPayloadPanel.qml
│   ├── USVPayloadDetailPanel.qml
│   ├── USVSamplingDataView.qml
│   ├── USVFlyViewCustomLayer.qml
│   ├── USVPayloadFactGroup.json
│   └── actions/usv_actions.json
└── src/
    ├── USVPlugin.h/cc
    ├── USVPayloadFactGroup.h/cc
    └── FirmwarePlugin/USVFirmwarePlugin.h/cc
```

## WHERE TO LOOK

| 任务 | 位置 |
|---|---|
| NAMED_VALUE_FLOAT 映射 | `src/USVPayloadFactGroup.cc` |
| Fact 元数据 | `res/USVPayloadFactGroup.json` |
| 手动命令按钮 | `res/USVPayloadPanel.qml`、`res/USVActionBar.qml` |
| 顶层采样数据页 | `res/USVSamplingDataView.qml` |
| 固件 FactGroup 注册 | `src/FirmwarePlugin/USVFirmwarePlugin.cc` |
| qrc 覆盖 | `custom.qrc` |

## CONVENTIONS

- custom QML 使用 `import QGroundControl`、`QGroundControl.Controls` 等可用全局导出。
- 继续使用 `ScreenTools.defaultFontPixelHeight/Width` 和 `QGCPalette` 类型；但不要写不可用模块 import：`QGroundControl.ScreenTools`、`QGroundControl.Palette`、`QGroundControl.Vehicle`。
- `activeVehicle`、`vehicle`、FactGroup、Fact 都必须判空。
- qrc 覆盖文件不要同时注册进 `qt_add_qml_module(... QML_FILES ...)`，避免双重加载。
- `USVPayloadPanel.qml` 发 `31010..31019`；Plan 航线采样不走 `31010`。
- 新增 Fact 时同步：ROS bridge 字段、ArduRover 缓存/转发、`USVPayloadFactGroup.json`、QML 引用。

## ANTI-PATTERNS

- 在 QML 中假定 `activeVehicle`、`vehicle`、FactGroup 永远存在。
- 使用不可用的 QGC import 导致组件加载崩溃。
- 只改面板按钮，不改 `actions/usv_actions.json` 或反向。

## VERIFY

```bash
rg -n "QGroundControl.ScreenTools|QGroundControl.Palette|QGroundControl.Vehicle" res src
rg -n "usvPayload|USVPayload|31010|31019|NAMED_VALUE_FLOAT" res src
```

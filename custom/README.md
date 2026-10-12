# QGroundControl USV (无人船) 定制构建

## safety1 匹配固件

Plan 中定点采样的超时说明已改为 HOLD，须配套 safety1 ArduRover 与 ROS；UI 文案不会让旧固件自动获得安全行为。22 个显示遥测字段、component 191、手动命令 31010..31019 保持不变。链路整体超时会清除分光有效位，源测量过期由 ROS 的 `USV_VLD=0` 传递。完整验收仍需要实际构建与端到端链路测试。

静态契约：`python -m unittest discover -s custom/tests -p test_usv_qgc_contract.py`。协议与现场步骤见总仓库 `docs/current/40_interfaces.md`、`70_verification.md`。

## 概述

这是一个针对无人船 (Unmanned Surface Vehicle, USV) 的 QGroundControl 定制构建。

### 主要特性

- 🚤 **载具类型锁定**：仅支持 Rover/Boat 类型载具
- 🔧 **双固件入口**：兼容 ArduPilot (ArduRover) 和 PX4 Rover/Boat UI
- ✂️ **功能精简**：隐藏不适用于无人船的功能（起飞、降落、高度控制等）
- 📋 **专用检查清单**：无人船预航检查清单（含载荷状态自动检测）
- 🎨 **可选品牌定制**：支持自定义 Logo 和主题颜色
- 📊 **作业 Tab 面板**：系统状态、传感器数据、自动任务、调试信息；默认突出 GPS、船速、航向、任务进度和采样状态
- 🧭 **系统状态栏与航行控制**：顶部汇总五类系统状态，底部集中模式、任务、暂停、返航与紧急停止
- ⚠️ **作业预警**：显示通信中断、姿态异常、采样失败和低电量；离线时屏蔽陈旧遥测

## 支持的固件

| 固件 | 版本 | 状态 |
|------|------|------|
| ArduPilot (ArduRover) | 4.x+ | ✅ 完整 USV 采样闭环 |
| PX4 | 1.14+ | ⚠️ UI 兼容，基础 Rover/Boat 规划与遥测 |

用户可以在设置中选择使用 ArduPilot 或 PX4 固件进行离线任务规划。完整 USV 采样 mission 闭环当前以 ArduRover 定制固件为准；PX4 仅支持基础 Rover/Boat UI 和部分手动/遥测能力，除非实现等价的 mission trigger / done / payload forwarding 机制。

## 构建方法

Android 平板测试 APK 优先通过 GitHub Actions 获取，无需本地 Qt/NDK。
参见 [Android 构建、侧载与现场验收](ANDROID.md)（签名/升级限制、链路边界及验证矩阵）。

1. 确保 `custom` 目录位于 QGC 源码根目录
2. 清理之前的构建：
   ```bash
   rm -rf build
   ```
3. 重新配置和构建：
   ```bash
   cmake -B build -S .
   cmake --build build
   ```

## 目录结构

```
custom/
├── cmake/
│   └── CustomOverrides.cmake           # CMake 配置覆盖
├── res/
│   ├── img/
│   │   ├── usv-logo-white.png          # 白色 Logo (深色主题)
│   │   └── usv-logo-black.png          # 黑色 Logo (浅色主题)
│   ├── actions/
│   │   └── usv_actions.json            # MAVLink Actions 定义
│   ├── USVChecklist.qml                # 无人船预航检查清单 (qrc 覆盖)
│   ├── USVFlyViewCustomLayer.qml       # 飞行视图自定义层 (qrc 覆盖)
│   ├── USVFlyViewToolBar.qml           # 系统状态栏与原生确认入口 (qrc 覆盖)
│   ├── USVOperationsPanel.qml          # 四 Tab 作业面板
│   ├── USVOperationsState.qml          # 航行/任务/采样状态汇总
│   ├── USVOperationsTheme.qml          # 局部工业深色主题
│   ├── USVActionBar.qml                # 底部航行与紧急停止控制
│   ├── USVFlyViewCustomLayer_TEST.qml  # 覆盖机制测试文件
│   ├── USVFlyViewBottomRightRowLayout.qml  # 隐藏原版遥测条 (qrc 覆盖)
│   ├── USVInstrumentPanel.qml          # 综合仪表盘 (qrc 覆盖 IntegratedCompassAttitude)
│   ├── USVPayloadPanel.qml             # 水质载荷控制面板 (USV QML 模块)
│   ├── USVPayloadFactGroup.json        # 载荷 FactGroup 元数据
│   ├── USVSelectViewDropdown.qml       # 中文化视图选择菜单 (qrc 覆盖)
│   └── USVToolBarButton.qml            # 主题感知 Logo 按钮 (qrc 覆盖)
├── src/
│   ├── USVPlugin.h/cc                  # 主插件 + URL 拦截器
│   ├── USVOptions.h/cc                 # 选项配置 (功能开关/检查清单)
│   ├── USVPayloadFactGroup.h/cc        # 水质载荷 FactGroup (MAVLink 数据)
│   ├── FirmwarePlugin/
│   │   ├── USVFirmwarePlugin.h/cc      # 双固件插件 (ArduPilot + PX4)
│   │   └── USVFirmwarePluginFactory.h/cc
│   └── AutoPilotPlugin/
│       └── USVAutoPilotPlugin.h/cc     # 双固件自动驾驶插件
├── CMakeLists.txt                      # 构建配置 + USV QML 模块定义
├── custom.qrc                          # qrc 覆盖资源映射
└── README.md
```

## 架构说明

### QML 覆盖机制

通过 `USVQmlOverrideInterceptor`（`QQmlAbstractUrlInterceptor`）实现 QML 文件替换：
- 拦截器检查 `:/USV` + 原始路径是否存在，存在则返回覆盖 URL
- 覆盖映射在 `custom.qrc` 中定义
- 例：`qrc:/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml` → `qrc:/USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml`

### USV QML 模块

通过 `qt_add_qml_module(USVModule URI USV VERSION 1.0)` 注册：
- `USVPayloadPanel.qml` 作为模块组件，通过 `import USV 1.0` 引用
- `addImportPath("qrc:/qml")` 使模块可被发现
- 注意：通过 qrc 覆盖加载的文件（Checklist、FlyViewCustomLayer 等）**不应**同时在 USV 模块的 QML_FILES 中注册，避免双重加载冲突

### 载荷数据流

```
Jetson Nano → NAMED_VALUE_FLOAT MAVLink → Vehicle → USVPayloadFactGroup.handleMessage()
                                                   → QML: vehicle.getFact("usvPayload.xxx")
```

- `USVPayloadFactGroup` 通过 FirmwarePlugin 的 `factGroups()` 注册到 Vehicle
- Vehicle 自动将 MAVLink 消息分发给所有注册的 FactGroup
- QML 通过 `vehicle.getFact("usvPayload.status")` 等访问数据

### QML Import 规范

custom QML 文件应遵循以下 import 风格：
```qml
import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
```

**禁止使用**以下 import（当前构建中不可用，会导致组件加载失败和崩溃）：
- `import QGroundControl.ScreenTools`
- `import QGroundControl.Palette`
- `import QGroundControl.Vehicle`

`ScreenTools`、`QGCPalette`、`Vehicle` 等类型通过 `import QGroundControl` 全局暴露。

## 定制内容

### 1. 载具类型限制
- 离线编辑默认使用 Rover/Boat 类型
- 用户无法在设置中切换到其他载具类型（固定翼、多旋翼等）

### 2. 固件选择
- 默认使用 ArduPilot
- 用户可以在设置中切换到 PX4
- 两种固件都针对无人船进行了优化

### 3. 隐藏的功能
- 空速计校准
- 悬停/上升/下降速度设置
- 任务绝对高度显示
- Orbit 模式
- ROI 功能
- 固定翼/VTOL 降落模式
- VTOL 相关设置

### 4. 保留的功能
- 航点导航
- Survey 测量任务（水域测量）
- 走廊扫描（河道巡检）
- 返航 (RTL)
- 紧急停止
- 罗盘/加速度计/陀螺仪校准

### 5. 无人船专用检查清单
- 船体/螺旋桨/电池/GPS/罗盘/遥控器检查
- 解锁前电机/舵机/任务检查
- 下水前水域/天气/通信/载荷/安全检查
- 载荷状态自动检测（通过 `usvPayload.status` FactGroup）

### 6. 作业 Tab 面板 (USVOperationsPanel)
- 地图优先布局，以 Windows 笔记本 1280×720 和 1920×1080 为主要验证尺寸
- 系统状态：GPS、船速、航向、距返航点、航线任务项位置、采样步骤与次数
- 传感器数据：检测电压、吸光度、有效信号、baseline、设备温度；提供启动/停止信号和设基线入口
- 自动任务：任务与采样状态，手动点采样/停止/暂停/恢复/走航控制
- 调试信息：泵组角度、PID、参考/基线电压、CPU/内存/堆、接收计数和维护动作
- 载荷按钮根据链路、有效采样、baseline 和任务状态启用；发送、处理中、接受与超时分别反馈，接受不代表设备已执行完成
- `USV_STAT=3` 显示为任务失败/采样失败，不再直接提示“载荷故障”
- MAVLink 指令：CMD `31010..31019`
  - `31010` 仅用于手动点采样；航线定点采样使用 Plan 任务项 `MAV_CMD_NAV_SCRIPT_TIME(param1=1)`
  - `31015` 开始走航，默认 `param1=5s`
  - `31016` 停止走航
  - `31017` 设置 baseline，`param1=0` 使用最新有效分光电压
  - `31018` 启动分光检测器信号采集
  - `31019` 停止分光检测器信号采集

### 7. 系统状态栏 (USVFlyViewToolBar / USVSystemStatusBar)
- 顶部显示 GPS、飞控连接、电池、网络/船载链路、任务状态
- 网络状态由现有载荷遥测链路推断，不代表 Wi-Fi 或互联网连接质量
- 自动模式且已解锁并载有任务时显示“自动执行”；未解锁明确显示“待解锁”
- 保留 QGC 菜单、飞控检查与任务确认入口、任务下载进度
- 工业深色仅作用于作业界面，不改写 QGC 全局主题设置

### 8. 航行控制与作业预警 (USVActionBar)
- 底部集中手动/自动、开始或继续任务、暂停、返航、紧急停止；模式与任务沿用 QGC 原生确认
- 暂停航行调用固件提供的保持模式；载荷采样的暂停与恢复位于自动任务 Tab
- 紧急停止确认后调用 QGC 原生推进急停，并向 component 191 发送既有停止采样命令 31011
- 急停反馈仅跟踪本次目标车辆的待响应命令；拒绝、超时、车辆切换和晚到结果有明确处理，实际停止仍需核对设备
- 横滚 > 25° 或俯仰 > 20° 时显示姿态异常；链路中断、采样失败和低电量保持可见

### 9. 采样数据独立页面 (USVSamplingDataView)
- 与航行/规划/配置/分析同级的独立顶层页面
- 实时电压/吸光度双Y轴滚动曲线（60秒窗口，2Hz刷新）
- baseline 未设置时只采集/显示电压，不累计吸光度曲线和吸光度统计
- 采样任务概览：连接状态、采样步骤进度、已采集样本数、包计数、采样时长
- 泵组状态详情：四路步进泵角度实时显示、PID模式/误差值、链路状态
- 统计分析：电压与吸光度的最小/最大/平均/标准差（增量在线算法）
- MAVLink 遥测字段：`USV_STEP`, `USV_STOT`, `USV_SCNT`, `USV_PERR`, `USV_PMOD`, `USV_BSET`, `USV_REF`, `USV_BASE`, `USV_VLD`
- `USV_STAT=14` 显示为“走航检测”
- `USV_VLD=1` 表示分光检测器当前采样有效，可用于启用“设基线”

## 主界面验证

以下检查使用模拟 Facts 和生产 QML 组件，不连接设备、不发送实际控制命令：

```powershell
python -B -m unittest discover -s custom/tests -p test_usv_qgc_contract.py
python -B custom/tests/verify_operations_ui.py --output build/operations-ui-preview
Start-Process -FilePath 'C:/Qt/6.10.1/msvc2022_64/bin/qmltestrunner.exe' -ArgumentList @('-platform','offscreen','-input','custom/tests/tst_USVFlyViewLayoutLogic.qml','-o','build/operations-qmltest.txt,txt') -Wait -WindowStyle Hidden
```

离屏预览需要可用的 PySide6。覆盖 720p/1080p、四个 Tab、飞控断连、采样失败和未解锁自动模式；检查滚动区域不遮挡数据，验证采样准入与急停响应归属。顶部预览只呈现系统状态组件，不覆盖完整原生工具栏；完整菜单与确认交互还需在实际 QGC 窗口验证。预览可通过 `--map-image` 传入参考地图截图，地图上的旧标注不属于模拟遥测。

实船仍需验证飞控检查、模式/任务确认、暂停与返航、推进和载荷急停，以及户外强光下的屏幕表现。既有链路的源码依据：推进急停沿用 `src/Vehicle/Vehicle.cc:2317`；手动载荷命令由 `custom/res/USVPayloadCommandController.qml:80` 发往 component 191，ROS 在 `../src/usv_ros/scripts/usv_mavlink_router_bridge.py:541` 接收并发布给采样状态机；载荷遥测由 `../ardupilot-usv/Rover/GCS_MAVLink_Rover.cpp:595` 缓存并转发。协议保持不变。

## 飞行模式对照

### ArduPilot (ArduRover)
| 模式 | 说明 |
|------|------|
| Manual | 手动控制 |
| Steering | 转向模式 |
| Hold | 定点保持 |
| Loiter | GPS 定点 |
| Auto | 自动任务 |
| RTL | 返航 |
| SmartRTL | 智能返航 |
| Guided | 引导模式 |

### PX4
| 模式 | 说明 |
|------|------|
| Manual | 手动控制 |
| Stabilized | 稳定模式 |
| Position | 位置模式 |
| Hold | 定点保持 |
| Mission | 任务模式 |
| Return | 返航 |
| Offboard | 外部控制 |

## 回滚方法

如需恢复原版 QGC：

```bash
# 重命名 custom 目录
mv custom custom-backup

# 或删除
rm -rf custom

# 重新构建
cmake -B build -S .
cmake --build build
```

## 自定义品牌

1. 准备 Logo 图片（SVG 格式推荐）
2. 替换 `res/img/` 目录中的文件
3. 重新构建

## 许可证

遵循 QGroundControl 原始许可证 (Apache 2.0 / GPLv3)。

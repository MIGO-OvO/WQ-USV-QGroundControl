# QGroundControl USV (无人船) 定制构建

## 2026-10 跨端协议与安全门禁

当前协议为 `USV_PROTO=1`，26 个显示遥测字段。新增 `USV_ADS` 区分未知/停止确认/启动中/采集中/错误/停止未确认；源数据与单字段新鲜度分别校验，同值重发也记录接收序号。旧协议或能力过期时只保留停止入口。

载荷请求使用持久 session + request（24-bit，耗尽不回绕），`COMMAND_LONG.param3/4` 传递身份。关联请求由 `USVE1:` 结束原生和 QML 收执等待；标准 ACK 不释放或续期，避免旧 ACK 清除后续同命令请求。comp191 关联请求以 1 秒间隔最多发送三份相同身份和参数的帧，ROS RequestLedger 只执行一次。普通总预算 5 秒、STOP 15 秒、启动信号 40 秒，受理后停止重传，物理任务继续等待进度和终态。无关联兼容 STOP 保留 5 秒间隔、15 秒总预算。trigger 重启后旧请求拒绝续跑，须配套本次 ROS 更新。

泵组显示为 Web `calibration.json` 零点下的相对角度；未设置零点的轴显示“未校准”（线上值为 -1）。Web 与 31014 共用泵节点的相对 PID 回零，缺少零点或新鲜原始角度时拒绝运动。独立校准只回零，自动化仍执行原有回零、360°补偿与油相分隔。

驾驶舱独立急停通过同一载荷停止入口，断线/切船保留未知结果与核验锁；仍须人工现场确认执行器已停止。部署请退出旧进程后运行新产物，不能把旧窗口当本次构建。匹配 ROS、飞控和检测板成套更新，勿删除 `payload-request-identity.ini` 来绕过请求身份错误。

验证：`qmltestrunner -input custom/tests`（控制器/布局逻辑，不加载地图）；Debug 应用 `--allow-multiple --unittest:StatusTextHandlerTest`、`--unittest:SendMavCommandWithSignallingTest`、`--unittest:SendMavCommandWithHandlerTest`。所有结果必须包含实际测试数，零用例退出不算通过。没有设备或实船验收。

`_cockpitEmergencyStopReceipts` 实际调用驾驶舱 `emergencyStop()`，以真实 Vehicle/FactGroup 验证载荷成功/失败、ACK/USVE1 顺序、progress 和旧 ACK 隔离。无 handler 的关联结果通过 `mavCommandResult` 通知驾驶舱；停止 progress 继续等待最终结果。基线、启停分光、暂停/恢复和停止在匹配新遥测后显示具体确认状态；未设零轴在各页面显示“未校准”。

## safety1 匹配固件

Plan 中定点采样的超时说明已改为 HOLD，须配套 safety1 ArduRover 与 ROS；UI 文案不会让旧固件自动获得安全行为。当前 26 个显示遥测字段，component 191、手动命令 31010..31019 保持不变。链路整体超时会清除分光有效位，源测量过期由 ROS 的 `USV_VLD=0` 传递。完整验收仍需要端到端链路与台架测试。

静态契约：`python -m unittest discover -s custom/tests -p test_usv_qgc_contract.py`。协议与现场步骤见总仓库 `docs/current/40_interfaces.md`、`70_verification.md`。

## 载荷启动与停止验收

采样准备遥测 `USV_STAT=8` 时，流程带主按钮为“停止采样准备”；进入采样步骤后再提供暂停/恢复。普通停止在其他载荷命令或遥测确认等待期间可发送，同一停止命令等待响应时不重复发送。`31011` 的停止终态接受空闲、无任务保持、已中止或采样完成。

发送层和 QML 响应期限同步：分光启动 40 秒，停止类 `31011/31016/31019` 为 15 秒。该期限涵盖 ROS 的有界初始化重试与设备停机确认，不表示每次操作固定等待。载荷关联请求使用上述独立总预算，其他 MAVLink 命令沿用原重试策略。

重新编译后，在台架冷启动 ROS 并立即点击启动信号；使用同一 Web 配置核对点采样进样速度；准备中、采样中、暂停中分别执行普通停止。离屏按钮验证：`python -B custom/tests/verify_workflow_ui.py`，输出是模拟 Fact 场景，实际停泵仍需设备验收。

## 概述

这是一个针对无人船 (Unmanned Surface Vehicle, USV) 的 QGroundControl 定制构建。

### 主要特性

- 🚤 **载具类型锁定**：仅支持 Rover/Boat 类型载具
- 🔧 **双固件入口**：兼容 ArduPilot (ArduRover) 和 PX4 Rover/Boat UI
- ✂️ **功能精简**：隐藏不适用于无人船的功能（起飞、降落、高度控制等）
- 📋 **专用检查清单**：无人船预航检查清单（含载荷状态自动检测）
- 🎨 **可选品牌定制**：支持自定义 Logo 和主题颜色
- 📊 **采样准备流程带**：连接设备、获取有效信号、设置基线、手动点采样；设备控制和通信诊断按需展开
- 🧭 **原生航行 UI**：保留 QGC 官方顶栏、任务确认和 overlay 航行仪表；流程带避让原生工具、仪表、PIP 与虚拟摇杆
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

USV 构建默认 `DISABLE_SPEECH=ON`，也可显式传入 `-DDISABLE_SPEECH=ON`。此模式定义同名编译宏，不查找、链接或初始化 Qt TextToSpeech，隐藏语音设置、跳过声音起航检查及 Windows 语音打包依赖；其他多媒体保留。需要语音时先安装 Qt `qtspeech` 模块，再配置 `-DDISABLE_SPEECH=OFF`；Android 多 ABI 子构建转发同一变量，保留显式 OFF；CI 默认模块列表不再安装 qtspeech。

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
│   ├── USVSamplingWorkflow.qml         # 当前 FlyView 采样准备流程带
│   ├── USVFlyViewToolBar.qml           # 旧定制顶栏，当前不作 qrc 覆盖
│   ├── USVOperationsPanel.qml          # 旧四 Tab 组件，保留供兼容验证
│   ├── USVOperationsState.qml          # 航行/任务/采样状态汇总
│   ├── USVOperationsTheme.qml          # 局部工业深色主题
│   ├── USVActionBar.qml                # 复用急停确认与 ACK 跟踪
│   ├── USVFlyViewCustomLayer_TEST.qml  # 覆盖机制测试文件
│   ├── USVFlyViewBottomRightRowLayout.qml  # 旧覆盖文件，当前不启用
│   ├── USVInstrumentPanel.qml          # 旧自定义仪表组件，当前不启用
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

### 6. 采样准备流程带 (USVSamplingWorkflow)
- 地图优先布局，以 Windows 笔记本 1280×720 和 1920×1080 为主要验证尺寸
- 四阶段流程：连接设备 → 获取有效信号 → 设置基线 → 手动点采样；主按钮随真实准备状态变化
- 检测电压要求有效信号，吸光度同时要求有效信号与基线；离线或无效时显示“—”
- 设备控制：启动/停止信号、重设基线、校准泵组、走航检测、停止采样；泵组只展示真实角度
- 通信诊断：飞控链路、载荷报文计数、数据龄期及设备温度
- 载荷按钮根据链路、有效信号、基线和任务状态启用；ACK 接受后等待遥测更新，接受不代表执行完成，停止命令在等待期间仍可用
- `USVFlyViewLayout.workflowDock` 优先将面板停靠在仪表左侧；横向空间不足时放到原生底部控件上方，按字体单位切换双列/单列布局
- 底部锚点固定，220 ms 高度过渡与 140 ms 内容淡入淡出；收起立即禁用内容并返回标题按钮焦点；长内容使用受限滚动区
- 展开设备/诊断后，等待高度过渡完成，再用 180 ms 滚动将操作区及其切换/收回入口一起带入视野
- `USV_STAT=3` 显示为任务失败/采样失败，不再直接提示“载荷故障”
- MAVLink 指令：CMD `31010..31019`
  - `31010` 仅用于手动点采样；航线定点采样使用 Plan 任务项 `MAV_CMD_NAV_SCRIPT_TIME(param1=1)`
  - `31015` 开始走航，默认 `param1=5s`
  - `31016` 停止走航
  - `31017` 设置 baseline，`param1=0` 使用最新有效分光电压
  - `31018` 启动分光检测器信号采集
  - `31019` 停止分光检测器信号采集

### 7. 官方顶栏与航行仪表
- `custom.qrc` 不再覆盖 `FlyViewToolBar.qml` 和 `FlyViewBottomRightRowLayout.qml`，由官方组件显示状态、任务确认、遥测值与航行仪表
- `USVFlyViewOptions::showInstrumentPanel()` 为 true；保留用户选择的原生仪表设置
- 新增准备状态放在流程带标题同行，不改变 QGC 全局主题设置

### 8. 作业预警与紧急停止
- 模式、航线任务、暂停航行与返航沿用官方 QGC 交互；流程带的暂停/恢复只操作载荷采样
- 流程带标题保留急停按钮，复用 `USVActionBar.requestEmergencyStop()` 的原有确认与 ACK 跟踪
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
python -B custom/tests/verify_workflow_ui.py --output build/workflow-ui-preview
python -B custom/tests/verify_operations_ui.py --output build/operations-ui-preview
Start-Process -FilePath 'C:/Qt/6.10.1/msvc2022_64/bin/qmltestrunner.exe' -ArgumentList @('-platform','offscreen','-input','custom/tests/tst_USVFlyViewLayoutLogic.qml','-o','build/operations-qmltest.txt,txt') -Wait -WindowStyle Hidden
```

离屏预览需要可用的 PySide6。新流程带覆盖 720p/1080p、900×600、大字体、PIP、设备/诊断、等待遥测、暂停、断连、收起告警、动画中间态与快速反复切换；检查面板不碰撞原生控件、滚动条通道、键盘焦点及隐藏控制器的急停对话框。预览使用生产 USV QML、官方罗盘/姿态 QML 和模拟 Facts；顶部是明确标注的验证占位，完整官方工具栏需以整机 QGC 窗口验收。旧 `verify_operations_ui.py` 保留对旧四 Tab 组件的兼容检查。

实船仍需验证飞控检查、模式/任务确认、暂停与返航、推进和载荷急停，以及户外强光下的屏幕表现。既有链路的源码依据：推进急停沿用 `src/Vehicle/Vehicle.cc`；手动载荷命令由 `custom/res/USVPayloadCommandController.qml` 发往 component 191，ROS 在 `../src/usv_ros/scripts/usv_mavlink_router_bridge.py` 接收并发布给 `mavlink_trigger_node.py` 的采样状态机；载荷遥测由 `../ardupilot-usv/Rover/GCS_MAVLink_Rover.cpp:595` 缓存并转发。协议保持不变。

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

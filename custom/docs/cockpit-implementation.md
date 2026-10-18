# 无人船驾驶舱实施与启动验证

更新：2026-10-15。实现于 QGC 子仓库；未提交或推送。

## 实施范围

- 原生地图居中，顶部系统状态、左侧当前任务、右侧操作、底部实时数据；右上急停独立常驻。
- `USVFlyViewCustomLayer.qml` 集中连接 operations、commands、cockpit controller；各区域拆为原生 QML 组件。
- `USVFlyViewToolBar.qml` 保留原生主状态和任务确认，加入 GPS、通信、ROS、ADS、泵组、电源状态。
- QGCPalette/ScreenTools 派生颜色和尺寸。设置 → 常规 → 驾驶舱背景透明度统一调整背景，范围 0–100%，默认 50%；文字和图标保持不透明。SVG 图标、键盘焦点、滚动揭示焦点、PIP 和地图 inset 避让。
- 离线、字段缺失、过期、准备、采样、暂停、故障、断链、急停部分响应和超时均有独立语义。旧 `USVSamplingWorkflow.qml` 保留，但当前驾驶舱不实例化它。

## 真实状态与安全边界

### 顶栏与布局调整（2026-10-15）

- 顶部为菜单图标、原生飞控状态、六项系统状态和任务入口的一行布局；移除重复页面按钮、品牌说明及船名文字。
- 开始/继续航线统一从顶部进入。同一位置保留原生长按确认，关闭重复自动弹出和原生操作菜单内的任务启动入口；GPS、载荷状态及安全锁门禁不变。
- 左右面板不再为中央比例尺预留整行。原生操作菜单的实际展开宽度进入 inset；空间不足时暂隐任务卡，关闭菜单后恢复。
- 急停使用常规控制高度、较大文字，移除“推进 · 采样”；锁定、回执及现场核验提示保留。
- Windows 中文优先使用微软雅黑，驾驶舱正文至少 12pt，辅助文字按 1.125 比例缩小；继续响应 QGC 字体缩放。

本轮证据在 `build/cockpit-qa-20261015/`。Release 构建、45 项 Python 测试、24 项 QML 测试，以及模拟界面的 48 项行为/23 组视口检查通过。`verified/native-boot-evidence.json` 的原生 Windows 部署环境验证共 41 项通过，0 QML 运行错误，包含单行确认、透明度即时变化与持久化、设置页加载、菜单入口及操作菜单避让；不连接实船。Debug 编译到链接阶段后，因用户运行中的 EXE 被占用（LNK1168）无法替换；退出旧程序后重新构建即可使用新界面。Release 的离屏平台依赖 SDK 插件，部署验证使用 Windows 平台。

每条船持有独立 `USVPayloadFactGroup`。各字段 5 秒新鲜度与每秒失效通知；写入新 Fact 后再发布 freshnessChanged。拒绝非有限值及其他 system 的消息。

载荷遥测在线不能证明 ROS 所有节点健康；ADS 有效测量不代表硬件自检通过；泵组角度不代表运行或停止。航点、步骤、循环、采样计数分别展示。

急停先锁定操作，再分别调用推进急停和 comp191 的 31011 采样取消。两路 ACK 分别匹配车辆与组件，接受后仍要求实际停止核验；超时和断链不自动解锁。解除需要未解锁状态、有效采样结束遥测和现场确认。原生确认、解锁、任务控制、自定义动作、Vehicle 命令发送和摇杆输入遵守软件锁；按 system ID 保留切船及同进程重连锁。软件锁不跨 QGC 重启持久化，不替代硬件急停。

协议保持既有映射：QGC → comp191 → ROS 采样状态机；航线定点采样仍使用 NAV_SCRIPT_TIME，ROS 经 USV_DONE 通知固件继续航线。

源码依据：

- `custom/res/USVCockpitController.qml`：双停止、响应与核验状态。
- `src/Vehicle/Vehicle.cc`：`_usvSafetyCommandAllowed`、`_sendMavCommandWorker`、`_sendMavCommandFromList`、`sendJoystickDataThreadSafe`。
- `../ardupilot-usv/Rover/GCS_MAVLink_Rover.cpp:595`：NAMED_VALUE_FLOAT 缓存；`:657`：USV_DONE/USV_FAIL。
- `../ardupilot-usv/Rover/sensors.cpp:110`：载荷电压转发。
- `../src/usv_ros/scripts/mavlink_trigger_node.py:79`：31011 停止采样命令；`:1294`：USV_DONE 闭环说明。

## Qt Creator 不弹出窗口的原因与修复

用户日志明确显示 `USVFlyViewLayout.js` 未找到，随后 FlyView 和 MainWindow 创建失败。资源文件已注册，但覆盖 QML 的相对 JS 仍从原始 `/qml/QGroundControl/FlyView/` 解析；`USVQmlOverrideInterceptor` 原先只映射 QmlFile/UrlString。

修复：加入 `QQmlAbstractUrlInterceptor::JavaScriptFile`，复用 `/USV` 资源覆盖；启动检查包含该 JS。另补回原生 MainStatusIndicator 使用的 `_communicationLost`、`_mainStatusBGColor` 上下文，以及 GuidedActionConfirm 的消息计时器。关闭 3D 的 Debug 配置下，原生工具条的 viewer3DSettings 加空值保护。

不能仅以编译成功判定启动成功。新增 `verify_native_cockpit_boot.py`，从实际 Ninja 产物链接生产模块和资源，只替换验证入口，真实加载 MainWindow；未生成证据或出现 QML 错误均判失败。设置隔离在 QA 目录，所有自动连接关闭，QML 命令只发给模拟对象，C++ 命令门禁只测试无链路的 offlineEditingVehicle。

## 验证结果

证据目录：`build/cockpit-qa-20261014/`（构建产物，不提交）。

### Windows 插件部署修复（03:58 启动反馈）

Debug 目录此前只有复制到旁边的 Qt DLL，没有 `platforms/qwindowsd.dll` 和 QML 运行模块。之前验证入口额外设置了 `QT_PLUGIN_PATH`、`QML_IMPORT_PATH`，因而没有检出真实构建目录的部署缺口。用户在 Qt Creator 启动时，程序在创建 QApplication 阶段报平台插件不存在。

`cmake/platform/Windows.cmake` 现于可执行文件链接后调用当前 Qt Kit 的 `Qt6::windeployqt`，按 Debug/Release 匹配部署 Qt DLL、Windows 插件及原生/定制 QML 导入。现有安装打包规则保持独立；不修改全局环境变量或 Qt Creator 私有设置。

`verify_native_cockpit_boot.py` 默认不复制运行依赖、不注入 SDK 路径，并清除 Qt 插件/QML 搜索环境，将 PATH 限定为可执行文件目录和 Windows 系统目录。仅显式 `--sdk-runtime` 才使用旧开发环境路径。

同一 Debug 验证程序修复前失败（`deployment-before/native-boot.log`），部署后完整主窗口与 27 项检查通过，0 QML 错误，报告标记 `runtimeMode: deployed`（`deployment-after/native-boot-evidence.json`）。构建及部署记录为 `deployment-build.log`，实际离线窗口截图为 `deployment-after/qgc-offline.png`。该回归使用隔离设置和无硬件命令的测试入口。

| 检查 | 结果 / 证据 |
|---|---|
| Qt Creator Debug 构建 | 成功；`build-debug.log` |
| Release 构建 | 成功；`build.log` |
| Windows 原生 Debug 启动 | 27 项通过，0 QML 运行错误；`debug-native-windows/native-boot-evidence.json` |
| Debug 部署目录启动（无 SDK 路径） | 27 项通过，0 QML 运行错误；`deployment-after/native-boot-evidence.json` |
| Release 离屏启动（此前 SDK 环境） | 27 项通过，0 QML 运行错误；`native-boot-evidence.json` |
| Qt Quick Test | 23 通过；`qmltests.txt` |
| Python 契约测试 | 44 通过；`contracts.txt` |
| 生产 QML + 模拟 Facts | 48 行为、23 视口/状态、44 可见键盘焦点检查通过；`qa-evidence.json` |
| 静态 QML 检查 | 已运行，未全绿；`python-qml-lint.txt`、`qmllint.json` |

Windows 原生检查覆盖完整资源加载、确认框与布局、切船取消确认、旧目标拒绝、双停止、ACK 后保持锁定、解锁门禁、Vehicle 级启动拒绝/停止允许，以及 Fact 更新与新鲜度通知顺序。

截图边界：

- `debug-native-windows/qgc-offline.png`：实际 Debug 生产模块和资源、Windows 原生渲染、1280×720、离线主窗口。
- `cockpit-1920x1080-1-sampling.png` 等：生产驾驶舱 QML + 模拟 Facts + 示意地图 + 部分替代应用服务，用于多状态布局验证，不是实船遥测截图。

### 静态审查与剩余限制

六方向 QML 深度审查已执行并修复确认的绑定、布局、生命周期、原生确认与安全入口问题。24 个审查文件的 Python 扫描仍有 206 条记录，主要为动态 var、属性顺序、上游 JS 风格和必要滚动裁剪；qmllint 有 122 条诊断（含 info），主要涉及 QGC 动态上下文和保留的旧流程组件。原始记录保留，不能称全部 lint 通过。SVG 的 `http://www.w3.org/2000/svg` 是命名空间，无网络请求。

Debug 在 `offscreen` 测试平台触发 Qt 6.10.1 数值转换断言；Windows 原生 RHI 路径通过，未关闭断言或改变产品渲染设置。此离屏 Debug 限制尚未定位到 Qt 内部具体函数。定位权限告警、退出时数据库告警仍存在，但未阻止主窗口与测试完成。Release 链接报告上游 UVCReceiver 的局部 height 未初始化警告，本次未扩展到视频模块修复。

实船链路、泵和推进实际停止、断链恢复以及触屏/户外可读性仍需现场验收。软件与模拟测试不证明物理设备已停。

## 复验

在与构建目录一致的 MSVC 开发环境运行（Debug 14.51，Release 14.44）：

```powershell
cmake --build build/Desktop_Qt_6_10_1_MSVC2022_64bit-Debug-usv_ws --parallel 6
python custom/tests/verify_native_cockpit_boot.py --build build/Desktop_Qt_6_10_1_MSVC2022_64bit-Debug-usv_ws --output build/cockpit-qa-20261014/debug-native-windows --renderer rhi --platform windows
python -m unittest discover -s custom/tests -p 'test_*.py'
```

验证脚本读取本机构建目录的 MSVC 编译/链接规则，默认验证部署目录；可选 `--sdk-runtime` 仍针对本机 Qt 6.10.1/GStreamer 安装路径。Windows 验证会短暂显示隔离的测试窗口并自动退出。`--reuse-binary` 仅用于未改动源代码的运行环境对照；源代码更新后需重新链接。

正常使用：在原 Qt Creator 项目运行 `build/Desktop_Qt_6_10_1_MSVC2022_64bit-Debug-usv_ws/Debug/QGroundControl.exe`。测试用 `QGCCockpitBoot.exe` 不是日常启动入口。

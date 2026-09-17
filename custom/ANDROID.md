# Android 横屏平板构建与验收

适用：8–11 英寸 Android 横屏平板，Android 9/API 28 及以上，arm64。
QGC 是现场驾驶舱；历史任务、浓度、热力图/surface、科研图件与深度诊断仍归 ROS/Web。
已执行结果与明确的未验收项见 [验证记录](ANDROID_VALIDATION.md)。

## 获取 APK（不需要本地 Qt/NDK）

1. 打开本 fork 的 GitHub → Actions → **Android**。
2. 选择目标 commit 的成功运行；开发分支 push 和涉及 custom 的 PR 均触发。
3. 下载 `WQ-USV-QGroundControl-Android-arm64-linux.apk` artifact，解压 ZIP。
4. 将其中 `WQ-USV-QGroundControl-Android-arm64.apk` 复制到平板，允许该文件管理器安装未知应用后侧载。
5. 核对运行 commit、设备型号、Android 版本；不要把测试包当作已完成真船验收的发行版。

安装 ID 为 `org.wqusv.qgroundcontrol`，与官方 QGC 并存；Java/JNI namespace 保持
`org.mavlink.qgroundcontrol`，不改串口 native 注册。Qt 6.10 会优先从 Gradle namespace
提取 package，故 custom CMake 复制上游模板后追加 `qgcApplicationId`，由 Gradle
明确设置 install ID。没有复制维护第二份 Manifest；横屏复用 `sensorLandscape`。

普通提交默认 Debug；tag 默认 Release（也可 workflow_dispatch 选择）。目前两者都使用
**临时测试签名**，不连接 Play Store，不读取 production signing secret。每个 CI job 新建
密钥，密钥不上传、不提交；跨运行/跨宿主的测试包无法覆盖安装，需先导出任务与设置，
经操作员确认后卸载旧测试包。不要自动卸载或承诺保留应用数据。
同一个 APK 的 `adb install -r` 用于覆盖安装测试。正式连续升级发行前需另行建立受保护、
稳定的签名密钥和递增 versionCode 流程；tag 现在不是 production release。

## 构建基线与审计结论

真源 `.github/build-config.json`：Qt **6.10.1**、API **35**、minSdk **28**、
Java **17**、NDK **r27c / 27.2.12479018**、build-tools **35.0.0**。
Qt Android 包使用 `all_os/android` 下载入口；桌面 host tools 仍按宿主安装。

| 检查 | 源码事实 / 改动 |
|---|---|
| 是否包含 custom | 顶层 CMake 检测 custom 目录，add_subdirectory；CI 检查 USV configure 标记 |
| custom 是否触发 | Android PR 新增 custom、build-config；push 覆盖开发分支；custom-build 不再复制 custom-example |
| USVModule | 静态 QML 模块链接到主目标；补齐自身 Core/Qml/Quick 依赖；MAVLink 生成依赖沿用 src/MAVLink/CMakeLists.txt |
| QtCharts / Canvas | 主 QGC 仍链接 Charts；custom 不再声明多余 Charts；采样页保留有界 Canvas 数组、单一绘制入口和静默卸载 |
| 资源/翻译 | custom.qrc 加入 executable；USV QML 使用 /qml；修正翻译 source property 的目录作用域，使 qm 真正位于插件加载的 /i18n；构建后由 `custom/tests/verify_apk_payload.py` 强制校验 APK 原生库内确实含 override、custom QML 与 usv_zh_CN.qm |
| 签名/artifact | 所有宿主生成测试密钥，apksigner verify 后直接 upload-artifact；不依赖 AWS/商店 |
| 平台 API | custom 未发现必需的 Windows 专用 API；原 Windows assert hook 保持平台保护、不改 |
| Android overlay | 原仓库无 custom/android；本次在 build tree 生成上游模板副本，仅追加 applicationId 属性 |
| ID 冲突 | install ID 与官方包隔离；未更名 Java/JNI package；FileProvider 使用 applicationId |
| 日志/lint | tee 保存 configure/build（含 androiddeployqt/Gradle）；always 上传日志、deployment JSON、lint 报告；不上传 key/cache |

选择性参考 upstream Android workflow 的 debug keystore、lint、emulator 和诊断做法：
https://github.com/mavlink/qgroundcontrol/blob/master/.github/workflows/android.yml 。
未升级 QGC/Qt 主版本，未整体移植 upstream。
当前 Gradle 的 lintOptions.abortOnError=false 沿用上游：lint 报告是审查证据，
“Gradle 退出 0”不等于零 lint 问题。Gradle 执行错误仍使 job 失败。
首轮报告暴露的三个 Error 已针对性修复：唤醒锁标签（仅名称）、coarse location 声明、
ContextCompat receiver 注册（保留 NOT_EXPORTED，不新增串口驱动）。
启动审计还发现 Platform.cc 把 Android 当作普通 Unix 强制 stderr，导致 logcat 丢失
Qt/QML 日志；本次仅将 Android 排除出该分支，Windows assert hook 和桌面日志保持不变。

可复用的是固定工具链和 CI 入口，不承诺字节级可复现：上游仍含跟随 main/master 的
CPM 依赖、runner 镜像和 action major tag，且每次测试签名不同。正式发行需冻结这些依赖。

## 平板与生命周期

- FlyView 继续右上摘要、右侧详情、右下仪表、底部操作；避让 QGC tool insets，修正横纵 inset 混用。
- 操作栏按可用宽度换行；高频自绘按钮至少取 `max(minTouchPixels, 2.5 × 字高)`。
- 采样页宽度不足 130 个默认字体宽度时使用曲线/状态 tab，宽屏维持并排；状态卡按内容高度滚动。
- 详情抽屉内容可滚动、泵组改为两列；诊断页在窄窗口改单列。
- 补上原来没有打包/引用的 USVPayloadPanel：在详情抽屉内提供已有 pause/resume、校准、
  readiness、ACK 和 Jetson/ESP32 健康状态，命令实现与门控复用原文件。
- 后台暂停展示曲线和诊断轮询；不会暂停 ROS/飞控任务，也不重发载荷命令。
- 保留 C++ Fact ownership、prepareForUnload 和有界曲线数组；HTTP 页面卸载取消回调和请求，
  10 秒超时不自动重放 POST；车辆切换清除 UI pending，回前台按墙钟核对命令等待超时。
- 原生 AUTO/RTL/Hold 和危险操作确认流程不变。自定义 action bar 原本是直接发送载荷命令，
  不是所有红色按钮都有确认；本次不将其误描述为新增安全确认，也不改变紧急停止行为。
- CI 模拟器预授予运行时权限与 MANAGE_EXTERNAL_STORAGE appop，以避免首次启动停留在
  Android 存储设置页；真机 clean install 必须另验权限允许/拒绝/返回流程。CI 不代替权限 UX 验收。

### 屏幕唤醒已知风险

`android/src/org/mavlink/qgroundcontrol/QGCActivity.java` 已在 onCreate 设置 KEEP_SCREEN_ON，
并获取无 timeout 的 SCREEN_BRIGHT_WAKE_LOCK，onDestroy 释放；并非仅 active vehicle 时唤醒。
本次未添加任何锁，也没有在无硬件依据时改变后台通信行为。需真机检查后台、锁屏耗电与
设备省电策略；不能据此承诺 Android 后台始终接收 MAVLink。缩小锁的生命周期应单独验证。

## 链路边界

### A：USB OTG 数传（首轮实船优先）

复用 `QGCUsbSerialManager`、`QGCProber`、`device_filter.xml` 与
usb-serial-for-android 3.9.0；不实现新驱动。设备需 USB host、可用 OTG 线、驱动支持的
USB-UART 芯片及足够供电。检查权限弹窗、串口波特率、拔插重连、锁屏/回前台；无权限时
不能视为“已连接”。不承诺 USB 和充电同时工作，需验证平板与 hub。

### B：Wi-Fi → Jetson hotspot → mavlink-router（第二阶段）

`src/usv_ros/scripts/usv_mavlink_router_bridge.py` 默认 TCP `127.0.0.1:5760`；
工作区 runbook 和 `src/usv_ros/scripts/common_env.sh` 管理 router 的本地 UDP 端点
`127.0.0.1:14550/14551`。本次未改任何 router、ROS、飞控配置。
后续建议保留本地端点，另加 **定向平板 IP:14550 的 UDP client endpoint**，平板 QGC
监听 UDP 14550。固定 DHCP 租约、仅热点接口/可信客户端、限制防火墙来源；不要直接把
loopback 改成 0.0.0.0，也不要暴露 bridge TCP/Web 控制到公网。先核对 router 当前启动命令，
检查双链路重复路由和 compid 191 ACK，再决定具体变更。MAVLink 链路不是网络认证机制。

## 验收矩阵

每项记录 commit、APK SHA256、设备/系统/DPI、操作者、时间、日志及结果。状态只能使用
`CI verified` / `emulator verified` / `desktop verified` / `hardware verification required`；
没有对应执行记录的项目仍待验，不因静态测试通过而自动勾选。

| 场景 | 验证方式 / 必须观察 | 验收层 |
|---|---|---|
| CI / 下载 | custom 变更触发、USV configure、签名校验、下载解压 APK | CI verified（成功运行后） |
| 安装 | clean install、同包覆盖、跨 CI key 不匹配应明确报错 | emulator + 真机 |
| 启动 | cold/warm start，存活 60 秒、QML root 标记、USV override 存在、无 fatal/module 缺失 | emulator |
| 平板 UI | 1280×800、1920×1200 横屏，mdpi/hdpi/xhdpi、大字体 | 真机，截图留证 |
| 页面 | toolbar、FlyView、摘要/抽屉、action bar、仪表、采样 tabs/双栏、诊断滚动无遮挡/裁切 | 真机 |
| desktop | Windows 构建、现有 QML/Fact 生命周期、Rover/Boat、采样页 | desktop verified（执行后） |
| mission | connect → upload → AUTO → waypoint → NAV_SCRIPT_TIME(1) → USV_SMPL → ROS sampling → USV_DONE → mission continues | hardware verification required |
| 手动 | 31010..31019，compid 191，ACK、baseline/valid/link readiness、一致状态 | hardware verification required |
| 长时 | 连续数小时；曲线点数有界，内存无持续增长；前后台/锁屏/解锁/Activity 重建/页面反复开关 | hardware verification required |
| 链路 | MAVLink 断开/自动重连、USB 拔插、Jetson 重启、ESP32 重启、QGC restart | hardware verification required |
| 安全 | sampling 异常停止、AUTO 中 GCS 消失、RTL，确认飞控 failsafe 与任务状态 | hardware verification required |

源码闭环依据：`Rover/mode_auto.cpp::do_nav_script_time` 的 command==1 发 USV_SMPL；
`Rover/GCS_MAVLink_Rover.cpp` 处理 USV_DONE；ROS bridge 的完成条件与 compid 191；
QGC `src/MissionManager/MavCmdInfoRover.json` 和 `custom/res/actions/usv_actions.json`。
测试 `test_usv_qgc_contract.py` 在完整工作区执行跨仓库核对；单独 QGC checkout 明确 skip
该一项，仍运行本地全部字段、Fact metadata、资源、命令、mission 和生命周期检查。

## 高级本地构建

普通测试者无需执行本节。开发者安装与 build-config 相同版本的 desktop host Qt、
Android Qt/SDK/NDK、Java、Ninja，设置 ANDROID_SDK_ROOT、ANDROID_NDK_ROOT 后：

```sh
python -m unittest discover -s custom/tests -p 'test_*.py' -v
<Qt>/6.10.1/android_arm64_v8a/bin/qt-cmake -S . -B build/android-usv -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DQT_HOST_PATH=<Qt>/6.10.1/gcc_64 \
  -DQT_ANDROID_ABIS=arm64-v8a
cmake --build build/android-usv --parallel 3
```

Windows host path 用 msvc2022_64、macOS 用 macos。要显式测试签名，参照 workflow 创建
本地测试 key 并设置 QT_ANDROID_KEYSTORE_* 环境变量及 QT_ANDROID_SIGN_APK=ON。
不要提交 key、SDK、NDK、build 或真实设备日志。CI 失败先下载 `android-<host>-diagnostics`，
工具链安装阶段失败则查看 Actions step 日志；这时尚无 CMake/Gradle 输出是正常的。

已存在 x86_64 artifact 时，可手动运行 **Android APK Smoke**，输入原 Android build run ID，
仅重跑 emulator，避免重复编译。测试使用所选分支的 smoke 脚本和指定运行的 APK；验收记录
必须同时记下两者，不能把旧 APK 的启动结果归到新代码。
新 workflow 尚未合入默认分支时，也可从已有 **Android** workflow 的手动入口填写
`smoke_run_id`，此时仅调用同一 smoke workflow，不重新编译。

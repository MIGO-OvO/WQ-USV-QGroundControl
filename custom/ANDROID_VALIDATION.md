# Android 改造验证记录

验证时间：2026-09-16/17；分支 `codex/android-tablet`。
本文件不是实船放行单。验收操作矩阵见 [ANDROID.md](ANDROID.md)。

## 已执行

| 结果 | 证据与范围 |
|---|---|
| PASS | Python unittest：35 项，含本机完整 usv_ws 跨仓库字段检查、资源/JSON/mission/191、生命周期静态契约、boot 与 APK 载荷门控行为测试 |
| PASS | Qt 6.10.1 qmltestrunner：14 项（含不同分辨率/DPI/字体的断点逻辑）；不是像素级 UI 验收 |
| PASS | Windows MSVC/Qt 6.10.1 CMake configure、USVModule 和完整 QGroundControl Debug 编译 |
| PASS | Windows MissionCommandTreeTest 5 项、SimpleMissionItemTest 10 项、FactSystemTestGeneric 6 项；隔离 unittest 设置空间，退出码 0 |
| PASS | Windows `--simple-boot-test` 退出码 0；它只启动子系统，不证明 QML 页面渲染 |
| PASS | actionlint 1.7.12：android.yml、android-smoke.yml、custom-build.yml；JSON/Python 语法与 git diff --check |
| PASS | [Android build 35177617767](https://github.com/MIGO-OvO/WQ-USV-QGroundControl/actions/runs/35177617767)（commit `1b85bf7bd`，push 触发，**当前分支最终态**）：windows / linux / mac / linux-emulator 四宿主全部成功；linux 宿主 `Android lint` 成功；linux-emulator 宿主 `Tablet boot smoke` 成功；产出 4 个 APK + 4 份诊断 artifact |
| PASS | 同一次运行四宿主 `Verify USV payload in APK` 全部成功，输出形如 `lib/arm64-v8a/libQGroundControl_arm64-v8a.so :: usv_zh_CN.qm -> present`；x86_64 宿主输出 `lib/x86_64/libQGroundControl_x86_64.so :: ...`，说明打包门控不是靠单一 ABI 侥幸通过 |
| PASS | [Android build 35175330164](https://github.com/MIGO-OvO/WQ-USV-QGroundControl/actions/runs/35175330164)（commit `e32f20166`）：四宿主与上述门控同样全绿；两次运行互为对照 |
| PASS | [Android build 35119772116](https://github.com/MIGO-OvO/WQ-USV-QGroundControl/actions/runs/35119772116)（commit `c02dbb440`）：windows / linux / mac / linux-emulator 四宿主全部成功；各宿主均完成 USV 契约、configure、编译、签名校验、上传 |
| PASS | 该次运行内 linux 宿主 `Android lint` 执行成功，报告 `0 errors, 37 warnings`；三条 Error 已消除（其余为上游携带的警告，Gradle `abortOnError=false` 沿用上游，不能据此宣称零告警） |
| PASS | 该次运行内 linux-emulator 宿主 `Tablet boot smoke` 通过：1280×800/mdpi 下同包覆盖安装、60 秒存活、`USV boot: root QML object created`、`Override resource check: .../FlyViewCustomLayer.qml exists: true`、无 QML/模块/FATAL 错误，后台/前台恢复再次通过 |
| PASS | artifact 实际下载：`WQ-USV-QGroundControl-Android-arm64-linux.apk`；本机独立 `apksigner verify` 为 v3 方案、RSA 2048、DN `CN=USV CI Debug`；`aapt dump badging` 为 `org.wqusv.qgroundcontrol`、arm64-v8a、minSdk 28、targetSdk 35、landscape |
| PASS | 同一 APK 内 `lib/arm64-v8a/libQGroundControl_arm64-v8a.so` 含 UTF-16 资源名 `USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml`、`USVSamplingDataView.qml`、`usv_zh_CN.qm`，回答“翻译/自定义 qrc/QML override 是否进入 APK” |
| PASS | 新增 `custom/tests/verify_apk_payload.py` 门控已用上述真实 APK 复跑通过，并已在四宿主构建后强制校验，防止“编译成功但定制层未打包” |
| FAIL → FIX | 首轮 Qt Android 下载入口错误、NDK 缓存缺 clang、macOS Bash 不支持 mapfile；均依据 CI 日志修复，不升级 Qt/QGC |
| FAIL → FIX | 原始 emulator 首启停在存储权限设置；预授权后 UI 已加载，但 Unix 强制 stderr 隐藏 Qt 日志；Android 恢复 logcat，smoke 通过 |
| FAIL → FIX | 首轮 lint 3 Error/37 Warning；针对唤醒锁 tag、coarse location、receiver flags 修复 |
| FAIL → FIX | smoke 收尾采集全量 logcat 时 adb 偶发返回 255，导致断言已通过却整项判失败；改为进程级证据先落盘、附加诊断失败只告警 |
| FAIL → FIX | 首轮 lint 命令退出 0 曾被误当成无问题；现以 lint 报告 Error 计数为准 |

下载的 arm64 APK SHA256：

- commit `c02dbb440`（含翻译、lint、logcat 修复）：
  `2ba5178eeb662288b6c0fa67952963ac41b8fb5a3493ddbc4c07ef08ea137b44`
- 早期 commit `5618dc5ed`（不含上述修复，仅存档）：
  `40cab09959a1ff58b3a46c7ee03c92afa3c3bd87095c57cc92bc39226a30da31`

测试包每次 CI 用新密钥，SHA256 随之上变；获取最新包必须核对对应 run 的 commit。

## 验证边界

- `CI verified` 与 `emulator verified` 仅对应上述具体运行，不自动推广到后续 commit。
- 启动测试的预授权发生在一次性模拟器；真机权限拒绝/允许/返回路径仍需验证。
- 模拟器截图出现 SwiftShader/GLES 渲染伪影；不作为平板 visual QA 通过依据。- 1280×800/mdpi 模拟器只证明可启动与资源齐全，不证明 1920×1200、各 DPI、大字体下的排版。
- 普通 shallow CI 构建生成 fallback `versionName 0.0.0`；正式发布前须验证 tag/versionCode 递增与稳定签名。
- `NOT RUN`：正式生产签名/tag 发布、真机截图矩阵、长时压力与耗电验收。
- `HARDWARE REQUIRED`：USB OTG 供电/权限/拔插、Wi-Fi 链路、31010..31019 ACK、baseline gate、
  NAV_SCRIPT_TIME → USV_SMPL → ROS → USV_DONE 闭环、断链/重启/AUTO 中 GCS 消失/RTL。
- 未修改 ROS、ArduPilot、命令号、compid 或遥测字段，未推送 upstream/master，未配置 Play Store。

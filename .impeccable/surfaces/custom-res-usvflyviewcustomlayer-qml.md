---
version: 1
slug: "custom-res-usvflyviewcustomlayer-qml"
primary_target: "custom/res/USVFlyViewCustomLayer.qml"
related_targets: ["custom/res/USVFlyViewToolBar.qml","custom/res/USVCurrentTaskPanel.qml","custom/res/USVCockpitControlPanel.qml","custom/res/USVEmergencyStopPanel.qml","custom/res/USVRealtimeDataStrip.qml","custom/res/USVFlyViewLayout.js"]
---

# 地图边缘驾驶舱

Mode: Operate。

用户已批准采样、离线、急停多状态驾驶舱设计稿。地图为主，顶部系统状态、左侧只读任务、右侧操作、底部实时数据，右上独立常驻急停。原生 Qt/QML 延续 QGCPalette、ScreenTools 与原生主状态、任务确认和航行仪表。

半透明仅作用于背景，文字和操作保持不透明。布局通过地图 insets 避让仪表、PIP 和摇杆。目标 1280×720、1920×1080；大字体和短屏优先保留当前阶段、急停，次要内容可滚动。

设备控制和通信诊断按需查看。各字段以真实 Facts 和新鲜度为准；航点、采样计数、步骤、循环独立。推进与采样双停止分别记录响应，ACK 接受后仍保留实际停止核验锁。

键盘焦点可见，滚动自动揭示进入焦点的操作。旧流程带高度动画不用于当前驾驶舱。原生任务入口及解锁操作与驾驶舱安全状态互锁，Vehicle 级门禁也覆盖命令和摇杆输入。

历史方向：种子 c8468699 与 qgc-sampling-concepts.html 准备流程带。当前方向由用户批准的 usv-cockpit-assets 多状态设计取代，生产实现为 USVFlyViewCustomLayer.qml。模拟 Facts 场景与完整 QGC 离线启动分别验证；实船尚未验收。

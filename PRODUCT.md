# WQ-USV 作业主界面

<!-- impeccable:product-schema 1 -->

## Platform

Qt Quick 原生应用；本次以 Windows 笔记本为优先平台。

## Users

无人船驾驶员与水质采样操作员，在户外查看航线、船态和采样状态并控制自动任务。

## Operating Context

用户确认优先兼容 1280×720 和 1920×1080。地图是主要工作区域；户外强光下需要清楚的文字、状态和控制入口。

## Capabilities and Constraints

- 四个作业 Tab：系统状态、传感器数据、自动任务、调试信息。
- 默认呈现 GPS、船速、航向、任务进度、采样状态。
- 底部集中手动/自动、开始任务、暂停、返航和紧急停止。
- 使用 QGC 的 Vehicle、Fact、固件插件和任务控制器；保留现有命令与遥测协议。
- 采样链路以定制 ArduRover、ROS 与检测装置为准；PX4 保持已有 UI 兼容边界。
- 无遥测时显示未知或离线；命令发送、接受与实际执行状态分别呈现。
- QGC 不承担污染物浓度计算、历史数据持久化或热力图。

## Brand Commitments

用户指定现代工业深色界面；中文文案，清晰的信息层级和高对比阅读。

## Evidence on Hand

用户提供的两张现有界面截图；`custom/res/`、Vehicle 与 GuidedActionsController 源码；总工作区的固件和 ROS 源码。

## Product Principles

- 驾驶与任务信息优先。
- 低频诊断参数按需查看。
- 操作反馈以飞控和载荷返回为依据。
- 布局随可用逻辑尺寸与字体缩放适配。

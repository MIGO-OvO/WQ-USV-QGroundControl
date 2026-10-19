---
name: "WQ-USV 作业界面"
description: "继承原生 QGC 航行界面，以清晰采样准备与遥测反馈为核心的工业深色工具表面"
colors:
  qgc-action-blue: "#3A9BDC"
  qgc-ready-green-dark: "#00e04b"
  qgc-warning-orange-dark: "#de8500"
  qgc-danger-red-dark: "#f32836"
  qgc-window-dark: "#222222"
  qgc-text-dark: "#ffffff"
typography:
  title:
    fontFamily: "Open Sans"
    fontWeight: 700
  body:
    fontFamily: "Open Sans"
    fontWeight: 400
  label:
    fontFamily: "Open Sans"
    fontWeight: 700
  metric:
    fontFamily: "Open Sans"
    fontWeight: 700
components:
  button-primary:
    typography: "{typography.label}"
  button-secondary:
    typography: "{typography.label}"
  button-destructive:
    typography: "{typography.label}"
  button-emergency:
    typography: "{typography.label}"
  detail-navigation:
    typography: "{typography.label}"
  preparation-step:
    typography: "{typography.body}"
  workflow-dock:
    typography: "{typography.body}"
  measurement-value:
    typography: "{typography.metric}"
  data-row:
    typography: "{typography.body}"
---

# Design System: WQ-USV 作业界面

## 当前实现：地图边缘驾驶舱（2026-10-15）

用户批准的新设计取代原先底部准备流程带。当前生产入口为 `USVFlyViewCustomLayer.qml` 与 `USVFlyViewToolBar.qml`；下文旧流程带说明保留为设计历史，不用于指导当前驾驶舱布局。

| 区域 | 内容 | 交互边界 |
|---|---|---|
| 顶部 | 原生主状态与确认、GPS、通信、ROS、ADS、泵组、电源 | 系统状态持续可见 |
| 左侧 | 当前任务阶段、航点、流程步骤、循环、采样计数 | 只读；通信诊断按需展开 |
| 右侧 | 任务、准备、设备控制 | 与只读状态分区；滚动时键盘焦点自动可见 |
| 右上 | 推进与采样双停止、两路响应、实际停止核验 | 独立常驻，不随普通操作区折叠 |
| 底部 | 电压、吸光度、基线、泵角度、温度、新鲜度 | 只读；失效字段显示未知 |

`USVOperationsTheme` 从 QGCPalette 派生颜色，以 ScreenTools 度量尺寸。面板背景 alpha 为 0.92，顶部背景为 0.97，文字和控制前景保持不透明。图标使用 SVG；不使用整棵组件 opacity 或背景模糊。当前按钮最小高度为 `max(ScreenTools.minTouchPixels, line * 2.4)`。

`USVFlyViewLayout.cockpitLayout` 计算边缘区域并将占用空间反馈给地图 inset，避让原生仪表、PIP 和摇杆。目标视口为 1280×720、1920×1080，另验证大字体与更窄窗口。当前阶段与急停优先保留，次要内容滚动；不沿用旧流程带高度动画。

真实 Fact 字段分别判断新鲜度。ROS 遥测在线不代表所有节点健康，ADS 有效信号不代表自检通过，泵角度不代表运行状态，航点进度与采样计数独立。紧急停止直接发出推进停止与采样取消请求；接受 ACK 后仍显示“实际停止待核验”。解除需要停止条件遥测和现场确认。原生任务入口、解锁入口、命令发送与摇杆输入遵守 Vehicle 级软件锁，切船及同 system ID 重连保留锁；应用重启不持久化该锁。

Qt 模拟场景截图与完整 QGC 离线启动证据分开保存，均不能作为实船执行效果证明。实施与验证说明见 `custom/docs/cockpit-implementation.md`。

## 历史方案：底部准备流程带

## Overview

**Creative North Star: "工业作业台"**

地图是驾驶与任务判断的工作底面。官方 QGC 顶栏和 overlay 航行仪表继续承担航行信息，新增工具表面使用实色深色、清晰中文和稳定的状态语义。信息紧凑，当前条件、有效测量与可执行动作有明确层级，服务于户外使用 Windows 笔记本的驾驶员和采样操作员。

本系统记录当前生产作业组件的视觉规则，不定义上游 QGC 的全部页面。视觉事实来自 `custom/res/USVOperationsTheme.qml`、`USVOperationsButton.qml`、`USVSamplingWorkflow.qml`、`USVFlyViewCustomLayer.qml` 和 `USVActionBar.qml` 的急停确认。颜色、字体与逻辑尺寸继续继承 QGC；原生顶栏及仪表的形态由上游资源负责。

**Key Characteristics:**

- 不透明的工业深色表面，依靠明度与细边界分层。
- 蓝色操作与选中状态，绿色就绪，橙色警示，红色故障与急停。
- 当前步骤、测量数值、常规状态文字和次要标签组成可扫读的层级。
- 尺寸随 QGC 字体度量与可用逻辑空间变化。
- 操作提示区分发送、设备接受和遥测确认的实际状态。

## Colors

中性深色占据工具表面，功能色用于操作、当前条件和状态；颜色从原生 `QGCPalette` 派生。

前置 token 是 `src/QmlControls/QGCPalette.cc` 中默认启用深色调色板的真实输入，不是所有运行环境的最终界面色值。实际颜色以 `USVOperationsTheme.qml` 的 `Qt.lighter`、`Qt.darker` 和 `Qt.tint` 绑定为准；派生表达式记录在 `.impeccable/design.json` 的 `extensions.nativeQml` 中。浅色全局主题也会派生本地深色工具表面，组件不修改 QGC 全局主题。

### Primary

- **操作蓝**（`qgc-action-blue`）：加深后作为主要按钮、当前步骤标记和选中详情入口的底色，提亮后用于键盘焦点。

### Secondary

- **就绪绿**（`qgc-ready-green-dark`）：载荷在线状态点与已满足准备条件的步骤标记；状态点仍配合具体就绪文字。
- **警示橙**（`qgc-warning-orange-dark`）：等待、缺少条件、无遥测及需要核对设备实际状态的提示。
- **急停红**（`qgc-danger-red-dark`）：故障与异常告警、紧急停止入口及确认框边界。流程带入口使用红色浅染底面，确认发送按钮使用加深的红色底面。

这些是功能状态色，使用频率由设备状态决定。

### Neutral

- **工具深灰**（`qgc-window-dark`）：本地不透明工具表面的基础输入；提亮的派生表面区分常规按钮与未到达的步骤标记。
- **高对比白**（`qgc-text-dark`）：深色启用态下的正文与重要数值；次要文字和分隔线由当前文字色混入工具表面得到。

### Named Rules

**The 状态语义 Rule.** 蓝色指向操作、当前步骤与选中入口，绿色指向已满足条件，橙色指向等待与警示，红色指向故障与急停；颜色始终配合可读状态文字。

## Typography

**Body Font:** `ScreenTools.normalFontFamily`；当前中文使用场景的原生默认字体为 Open Sans，中文缺字回退由 Qt 与操作系统处理。

**Character:** 使用 QGC 原生 UI 字体，以常规字重区分标签、以粗体突出状态和操作。没有独立展示字体或诊断专用等宽字体；这一界面不以装饰字形表达工业感。

### Hierarchy

以运行时 `ScreenTools.defaultFontPointSize` 为基准，记为 **P**。字号比例记录实际源码用法，不固定为预览中的点数或像素数。

- **Title** (700, 流程带标题 1.15 × P): 标识采样准备区域；当前操作标题使用 1.2 × P，急停确认标题使用 1.35 × P。
- **Body** (400, 1 × P): 状态文字、数据行、说明与确认正文；角度及诊断数值保持同一行的常规字重。
- **Label** (700, 1 × P): 按钮文字与当前步骤名称；步骤补充说明继承 `ScreenTools.smallFontPointSize`（原生比例 0.75 × P），其他步骤名称使用常规字重。
- **Metric** (700, 1.45 × P): 检测电压与吸光度，数值和单位共同形成紧凑测量块。航行数值继续采用官方仪表的原生字号。

短标签可省略尾部文字；告警、操作反馈与确认说明允许换行。重要数据值保持可直接阅读，滚动容器处理纵向内容增加。

### Named Rules

**The 度量一致 Rule.** 字体继承 `ScreenTools.normalFontFamily`，字号与空间继承运行时 QGC 字体度量；预览夹具的字体、点数和像素尺寸不作为产品常量。

## Layout

布局采用地图底面与周边工具叠层。工具内容以当前步骤、测量块和行式信息组织，用间距与细分隔线分组；低频设备控制和通信诊断按需展开。以下停靠规则描述当前 FlyView 采样工具表面。

空间基准为 **u** = `ScreenTools.defaultFontPixelWidth`、**h** = `ScreenTools.defaultFontPixelHeight`。常规行间距与按钮内距使用 u，容器内边距与组间距使用 1.5 × u，紧密组内使用较小的 u 比例。尺寸表达式保留在 sidecar 中，前置 token 不用固定 px 代替这些运行时度量。

流程带停靠地图下方、原生仪表左侧，宽度不超过 110 × u。`USVFlyViewLayout.js` 根据原生工具 inset 避让左右工具、视频 PIP、虚拟摇杆和仪表；旁侧可用宽度小于 62 × u 时，才移到下部控件上方。overlay 已位于顶栏下方，不重复计算顶栏高度。

正文按流程带实际宽度切换：至少 93 × u 为三列，小于 93 × u 为两列，小于 62 × u 为单列。两列布局让主操作跨两列；紧凑布局隐藏步骤补充说明，保留步骤名称。设备按钮使用 Flow 随可用宽度换行。

高度由内容隐式尺寸和可用最大高度共同限制。正文纵向滚动且保留独立滚动条通道；标题、当前状态、告警和急停入口留在滚动内容之外。详情展开后定位到包含两个详情入口的区域，设备／诊断切换及收回入口保持可达。

用户确认的优先验证尺寸为 1280×720 和 1920×1080；它们是目标视口，不是硬编码断点。固定首屏构图与驾驶顺序由 `USVFlyViewCustomLayer.qml` 开头的方向契约约束，不推广到其他 QGC 页面。

## Elevation & Depth

新增作业组件没有阴影。深度由不透明深色表面、提亮的交互表面和细边界表达；流程带底面无外边框，内部细分隔线和常规按钮边框为 1 个逻辑像素。键盘焦点采用更亮的蓝色边界，宽度为 2 个逻辑像素。此规则不改写原生 QGC 控件的深度语言。

### Named Rules

**The 实色分层 Rule.** 新增作业工具表面和危险确认面使用实色底面；通过明度与必要边界分层，使地图内容不影响文字与控制的阅读。

## Shapes

按钮和确认框使用轻微圆角（0.5 × u）；流程带使用较柔和的停靠容器圆角（1.5 × u）。步骤标记与状态点为圆形，前者承载步骤编号或已满足条件的绘制勾线，后者辅助状态文字。长内容裁切在圆角容器内，滚动条沿用 Qt Quick 控件形态。

## Components

### Buttons

紧凑、清晰的文字按钮；`USVOperationsButton.qml` 是共同实现。

- **Shape:** 轻微圆角，内距 u，最小高度取 `max(ScreenTools.minTouchPixels, 2.7 × h)`。
- **Primary:** 加深的操作蓝底面、主要文字色；同一填色也表示选中的详情入口。
- **Secondary:** 提亮的中性底面与细边界，悬停时再次提亮。
- **Destructive:** 确认发送按钮使用加深的红色底面与红色边界；流程带急停入口使用 `flat` 危险变体，以红色浅染底面和边界标识风险。
- **Hover / Focus:** 悬停反馈与键盘焦点分别呈现；焦点蓝边框不会被危险边框覆盖。按下时使用提亮的主要底面或危险底面。
- **Disabled:** 回到基础表面，使用次要文字色；禁用状态仍保持可读。辅助说明复用原生 ToolTip。

### Cards / Containers

工具容器使用共享的实色表面、1.5 × u 常规内边距和克制分隔。流程带的圆角比按钮更柔和；测量块与状态行直接排在共同底面上。确认框使用危险色细边界。没有装饰阴影。

### Navigation

官方 QGC 顶栏、工具及任务确认入口保留原生组件。流程带内的“设备控制”和“通信诊断”使用共用文字按钮；选中项使用操作蓝底面，再次点击当前入口收回详情，点击另一入口切换详情。两项入口不取代 QGC 的任务导航。

### Preparation Workflow

四项准备条件沿同一行排列：连接设备、获取信号、设置基线、手动点采样。已满足条件使用绿色浅染圆标和绘制勾线，当前项使用操作蓝圆标及粗体名称，后续项使用中性圆标。它们反映当前载荷条件，不能视作历史完成记录。

展开／收起以 220 ms 的 OutCubic 高度过渡和 140 ms 内容透明度过渡表达空间变化。收起即禁用主体控件，并把键盘焦点交还标题区展开按钮；状态、告警、反馈与急停仍可用。详情先等待高度稳定，再以 180 ms 的 OutCubic 滚动定位，使入口和新内容一同可见。

### Measurements & Data Rows

检测电压、吸光度和基线状态来自载荷 Facts；电压需有效信号，吸光度还需已设置基线。未知、离线或测量条件失效的数值显示破折号，不保留过期测量，也不用零模拟有效遥测；基线条件未满足时显示“未设置”。次要数据使用标签与数值同排或可换行的行式文字。泵组只显示 X／Y／Z／A 角度，不推断运行状态；采样步骤、循环与执行状态以返回遥测为准。

### Feedback & Confirmation

操作反馈位于对应工具容器内，普通提示使用次要文字，异常与待核对提示使用警示橙；文本可以换行。命令发送、ACK 接受与遥测状态更新分别表述，等待响应或状态更新时禁用会重复发出的开始类操作，停止类操作保持可用条件。任务操作继续复用 QGC 原生确认入口。

紧急停止入口打开原生 Qt Quick Dialog，使用红色边界、明确风险正文、取消和确认发送按钮；沿用 `USVActionBar.qml` 的已有控制链路。动作发送与设备接受提示都要求核对实际停止，不能写成设备已停止。

## Do's and Don'ts

### Do:

- **Do** 复用 `USVOperationsTheme.qml` 和 `USVOperationsButton.qml`，让作业组件共享颜色、尺寸和交互状态。
- **Do** 让状态颜色与明确文字共同出现，并保留未知、离线、等待和故障的区别。
- **Do** 按运行时字体度量安排间距、圆角和控件高度，按可用逻辑宽度适配。
- **Do** 为长告警、操作反馈和确认正文保留换行空间，为诊断内容保留滚动通道。
- **Do** 使用可见的键盘焦点，并以设备条件控制按钮启用状态。
- **Do** 分开表达命令发送、设备接受与遥测确认的实际作业状态。
- **Do** 保留官方顶栏、航行仪表及任务确认交互，让新工具表面遵守原生 inset。
- **Do** 让详情入口、收起状态和急停入口在字体放大及内容滚动后仍可达。

### Don't:

- **Don't** 用预览夹具的字体、数值或固定像素尺寸替代 QGC 的运行时来源。
- **Don't** 让未知或离线数据看起来像有效的零值，或让命令接受看起来像设备已经完成动作。
- **Don't** 把航线进度与采样完成状态混为同一个指标。
- **Don't** 从泵组角度推断或伪造泵的运行状态。
- **Don't** 将本次作业界面的构图、演示地图标注或验证视口推广成全部上游 QGC 的视觉规则。

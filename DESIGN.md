---
name: "WQ-USV 作业界面"
description: "以地图为工作底面、以清晰船态与操作反馈为核心的工业深色界面"
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
  navigation:
    typography: "{typography.body}"
  status-segment:
    typography: "{typography.label}"
  data-row:
    typography: "{typography.body}"
---

# Design System: WQ-USV 作业界面

## Overview

**Creative North Star: "工业作业台"**

地图是驾驶与任务判断的工作底面。实色深色工具面板承载连接、船态、采样和操作反馈；清晰中文与稳定的状态语义服务于户外使用 Windows 笔记本的驾驶员和采样操作员。信息紧凑，重要数值与可执行动作有明确的视觉层级。

本系统只描述 `custom/res/` 中本次完成的作业主界面组件，不定义上游 QGC 的全部页面。视觉事实来自 `USVOperationsTheme.qml`、`USVOperationsButton.qml`、`USVOperationsPanel.qml`、`USVSystemStatusBar.qml`、`USVActionBar.qml` 和 `USVFlyViewToolBar.qml`。颜色与字体度量继续继承 QGC；不新增字体或外部视觉依赖。

**Key Characteristics:**

- 不透明的工业深色表面，依靠明度与细边界分层。
- 蓝色操作与选中状态，绿色就绪，橙色警示，红色故障与急停。
- 大号航行数值、常规状态文字和次要标签组成可扫读的层级。
- 尺寸随 QGC 字体度量与可用逻辑空间变化。
- 操作提示区分发送、设备接受和遥测确认的实际状态。

## Colors

中性深色占据工具表面，功能色用于操作、进度和状态；颜色从原生 `QGCPalette` 派生。

前置 token 是 `src/QmlControls/QGCPalette.cc` 中默认启用深色调色板的真实输入，不是所有运行环境的最终界面色值。实际颜色以 `USVOperationsTheme.qml` 的 `Qt.lighter`、`Qt.darker` 和 `Qt.tint` 绑定为准；派生表达式记录在 `.impeccable/design.json` 的 `extensions.nativeQml` 中。浅色全局主题也会派生本地深色工具表面，组件不修改 QGC 全局主题。

### Primary

- **操作蓝**（`qgc-action-blue`）：加深后作为主要按钮与已选模式的底色，提亮后用于选中 Tab 下划线、键盘焦点和进度填充。

### Secondary

- **就绪绿**（`qgc-ready-green-dark`）：GPS 就绪、链路正常、基线与采样准备等肯定状态。
- **警示橙**（`qgc-warning-orange-dark`）：等待、缺少条件、无遥测及需要核对设备实际状态的提示。
- **急停红**（`qgc-danger-red-dark`）：故障与姿态异常文字、紧急停止按钮及其确认框边界。按钮使用加深的红色底面。

这些是功能状态色，使用频率由设备状态决定。

### Neutral

- **工具深灰**（`qgc-window-dark`）：本地不透明工具表面的基础输入；提亮的派生表面区分按钮、选中 Tab 与进度轨道。
- **高对比白**（`qgc-text-dark`）：深色启用态下的正文与重要数值；次要文字和分隔线由当前文字色混入工具表面得到。

### Named Rules

**The 状态语义 Rule.** 蓝色指向操作、选中与进度，绿色指向就绪，橙色指向等待与警示，红色指向故障与急停；每种状态都同时提供可读文字。

## Typography

**Body Font:** `ScreenTools.normalFontFamily`；当前中文使用场景的原生默认字体为 Open Sans，中文缺字回退由 Qt 与操作系统处理。

**Character:** 使用 QGC 原生 UI 字体，以常规字重区分标签、以粗体突出状态和操作。没有独立展示字体或诊断专用等宽字体；这一界面不以装饰字形表达工业感。

### Hierarchy

以运行时 `ScreenTools.defaultFontPointSize` 为基准，记为 **P**。字号比例记录实际源码用法，不固定为预览中的点数或像素数。

- **Title**（700，面板标题 1.3 × P）：标识当前作业监控区域；章节标题使用略高于正文的 1.05 × P。
- **Body**（400，1 × P）：数据行标签、说明与确认正文；对应数值使用同字号粗体。
- **Label**（700，1 × P）：按钮文字；系统栏状态值使用 1.08 × P，系统栏标签及 Tab 文字使用 0.9 × P，补充反馈使用 0.95 × P。
- **Metric**（700，2.4 × P）：系统状态页的船速与航向。单位保持常规字号，数值不挤入重复卡片。

短标签可省略尾部文字；告警、操作反馈与确认说明允许换行。重要数据值保持可直接阅读，滚动容器处理纵向内容增加。

### Named Rules

**The 度量一致 Rule.** 字体继承 `ScreenTools.normalFontFamily`，字号与空间继承运行时 QGC 字体度量；预览夹具的字体、点数和像素尺寸不作为产品常量。

## Layout

布局采用地图底面与周边工具叠层。工作内容以纵向标签／数值行组织，用章节标题和细分隔线分组；高频航行数值可以并排，低频诊断内容按需加载。

空间基准为 **u** = `ScreenTools.defaultFontPixelWidth`、**h** = `ScreenTools.defaultFontPixelHeight`。常规行间距与按钮内距使用 u，容器内边距与组间距使用 1.5 × u，紧密组内使用较小的 u 比例。尺寸表达式保留在 sidecar 中，前置 token 不用固定 px 代替这些运行时度量。

右侧作业面板宽度由 `USVFlyViewLayout.js` 限制为 `min(44 × u, 0.32 × 可用逻辑宽度)`。内容区预留独立滚动条通道，超出高度时纵向滚动；切换 Tab 后回到内容顶部。底部操作组使用 Flow，随可用宽度换行，反馈文字增加时容器高度随之增加。地图避让区域沿用 QGC 工具 inset。

用户确认的优先验证尺寸为 1280×720 和 1920×1080；它们是目标视口，不是硬编码断点。固定首屏构图与驾驶顺序由 `USVFlyViewCustomLayer.qml` 开头的方向契约约束，不推广到其他 QGC 页面。

## Elevation & Depth

作业组件没有阴影。深度由不透明深色表面、提亮的交互表面和细边界表达；常规容器与按钮边框为 1 个逻辑像素。键盘焦点采用更亮的蓝色边界，宽度为 2 个逻辑像素。

### Named Rules

**The 实色分层 Rule.** 作业面板、控制栏和危险确认面使用实色底面；通过明度与边界分层，使地图内容不影响文字与控制的阅读。

## Shapes

容器和按钮使用轻微圆角，半径为 0.5 × u。Tab 保持相连的矩形区域，选中项在底部显示蓝色细线。状态点为圆形；进度轨道和滚动条将圆角半径设为自身高度或宽度的一半。这些几何形状各自对应状态、进度与滚动功能。

## Components

### Buttons

紧凑、清晰的文字按钮；`USVOperationsButton.qml` 是共同实现。

- **Shape:** 轻微圆角，内距 u，最小高度取 `max(ScreenTools.minTouchPixels, 2.7 × h)`。
- **Primary:** 加深的操作蓝底面、主要文字色；同一填色也表示已选航行模式。
- **Secondary:** 提亮的中性底面与细边界，悬停时再次提亮。
- **Destructive:** 加深的红色底面与红色边界；保留文字动作名称。
- **Hover / Focus:** 悬停反馈与键盘焦点分别呈现；焦点蓝边框不会被危险边框覆盖。按下时使用提亮的主要底面或危险底面。
- **Disabled:** 回到基础表面，使用次要文字色；禁用状态仍保持可读。辅助说明复用原生 ToolTip。

### Cards / Containers

工具容器使用共享的实色表面、细边界、轻微圆角和 1.5 × u 内边距。作业面板以行和章节承载内容，不为每个数值添加容器。没有装饰阴影。

### Navigation

四个 Tab 使用等宽文字入口。未选中项使用基础底面和次要文字；选中项使用提亮底面、主要文字与粗体，底部显示 2 个逻辑像素的操作蓝细线。键盘焦点显示独立蓝边框；内容不足时保留布局，内容增多时在面板内部滚动。

### Status Segments

系统栏以标签、圆形状态点、粗体状态值构成重复片段，相邻片段之间使用细竖线。颜色辅助表达状态，具体连接、定位、电池、船载链路与任务文字承担判断信息。

### Data Rows & Progress

数据行左侧为次要标签，右侧为粗体值；未知或不适用的数值显示破折号，不用零模拟有效遥测。进度使用蓝色线性填充与提亮轨道，并配合文字说明。航线进度表示当前任务项位置，采样状态来自载荷遥测。

### Feedback & Confirmation

操作反馈位于对应工具容器内，普通提示使用次要文字，异常与待核对提示使用警示橙；文本可以换行。开始任务、模式切换与返航复用 QGC 原生确认入口。紧急停止使用红色边界的专用确认框，动作发送与设备接受提示都要求核对实际停止，不能写成设备已停止。

## Do's and Don'ts

### Do:

- **Do** 复用 `USVOperationsTheme.qml` 和 `USVOperationsButton.qml`，让作业组件共享颜色、尺寸和交互状态。
- **Do** 让状态颜色与明确文字共同出现，并保留未知、离线、等待和故障的区别。
- **Do** 按运行时字体度量安排间距、圆角和控件高度，按可用逻辑宽度适配。
- **Do** 为长告警、操作反馈和确认正文保留换行空间，为诊断内容保留滚动通道。
- **Do** 使用可见的键盘焦点，并以设备条件控制按钮启用状态。
- **Do** 分开表达命令发送、设备接受与遥测确认的实际作业状态。

### Don't:

- **Don't** 用预览夹具的字体、数值或固定像素尺寸替代 QGC 的运行时来源。
- **Don't** 让未知或离线数据看起来像有效的零值，或让命令接受看起来像设备已经完成动作。
- **Don't** 把航线进度与采样完成状态混为同一个指标。
- **Don't** 将本次作业界面的构图、演示地图标注或验证视口推广成全部上游 QGC 的视觉规则。

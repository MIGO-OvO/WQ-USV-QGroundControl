<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="zh_CN" sourcelanguage="en_US">
<!--
    USV (无人船) 专用翻译文件
    用于覆盖 QGC 默认翻译中的航空术语，使其更适合无人船应用

    术语对照:
    - Fly/Flight → 航行
    - Takeoff → 启航
    - Land/Landing → 停泊
    - Flying → 航行中
    - Flight Mode → 航行模式
    - Flight Speed → 航行速度
-->

<!-- ========== 主视图和导航 ========== -->
<context>
    <name>SelectViewDropdown</name>
    <message>
        <source>Fly</source>
        <translation>航行</translation>
    </message>
</context>

<!-- ========== 状态指示器 ========== -->
<context>
    <name>MainStatusIndicator</name>
    <message>
        <source>Flying</source>
        <translation>航行中</translation>
    </message>
    <message>
        <source>Landing</source>
        <translation>停泊中</translation>
    </message>
</context>

<!-- ========== 引导操作控制器 ========== -->
<context>
    <name>GuidedActionsController</name>
    <message>
        <source>Takeoff</source>
        <translation>启航</translation>
    </message>
    <message>
        <source>Land</source>
        <translation>停泊</translation>
    </message>
    <message>
        <source>Land Abort</source>
        <translation>取消停泊</translation>
    </message>
    <message>
        <source>Takeoff and hold position</source>
        <translation>启航并保持位置</translation>
    </message>
    <message>
        <source>Takeoff and start the current mission</source>
        <translation>启航并开始当前任务</translation>
    </message>
    <message>
        <source>Takeoff and start the current mission for selected vehicles</source>
        <translation>启航并为选定船只开始当前任务</translation>
    </message>
    <message>
        <source>Land the vehicle at the current position</source>
        <translation>在当前位置停泊</translation>
    </message>
</context>

<!-- ========== 任务规划视图 ========== -->
<context>
    <name>PlanView</name>
    <message>
        <source>Takeoff</source>
        <translation>启航</translation>
    </message>
    <message>
        <source>Land</source>
        <translation>停泊</translation>
    </message>
    <message>
        <source>Alt Land</source>
        <translation>备选停泊</translation>
    </message>
</context>

<!-- ========== 飞行视图设置 ========== -->
<context>
    <name>SettingsPagesModel</name>
    <message>
        <source>Fly View</source>
        <translation>航行视图</translation>
    </message>
</context>

<context>
    <name>FlyViewSettings</name>
    <message>
        <source>Fly View Actions</source>
        <translation>航行视图操作</translation>
    </message>
</context>

<!-- ========== 飞行模式指示器 ========== -->
<context>
    <name>FlightModeIndicator</name>
    <message>
        <source>Flight Modes</source>
        <translation>航行模式</translation>
    </message>
</context>

<!-- ========== 任务项编辑器 ========== -->
<context>
    <name>SimpleItemEditor</name>
    <message>
        <source>Flight Speed</source>
        <translation>航行速度</translation>
    </message>
</context>

<context>
    <name>MissionSettingsEditor</name>
    <message>
        <source>Flight Speed</source>
        <translation>航行速度</translation>
    </message>
</context>

<!-- ========== 检查清单 ========== -->
<context>
    <name>DefaultChecklist</name>
    <message>
        <source>Flight area</source>
        <translation>航行区域</translation>
    </message>
    <message>
        <source>Launch area and path free of obstacles/people?</source>
        <translation>出发区域和航线是否无障碍物/人员？</translation>
    </message>
</context>

<context>
    <name>MultiRotorChecklist</name>
    <message>
        <source>Flight area</source>
        <translation>航行区域</translation>
    </message>
    <message>
        <source>Launch area and path free of obstacles/people?</source>
        <translation>出发区域和航线是否无障碍物/人员？</translation>
    </message>
</context>

<!-- ========== 飞行视图工具栏 ========== -->
<context>
    <name>FlyViewToolStripActionList</name>
    <message>
        <source>Fly</source>
        <translation>航行</translation>
    </message>
</context>

<!-- ========== 任务完成对话框 ========== -->
<context>
    <name>FlyViewMissionCompleteDialog</name>
    <message>
        <source>Flight Plan complete</source>
        <translation>航行计划完成</translation>
    </message>
</context>

<!-- ========== 多机列表 ========== -->
<context>
    <name>MultiVehicleList</name>
    <message>
        <source>Armed</source>
        <translation>已解锁</translation>
    </message>
    <message>
        <source>Disarmed</source>
        <translation>已锁定</translation>
    </message>
</context>

<!-- ========== 飞行视图顶部面板 ========== -->
<context>
    <name>FlyViewTopRightPanel</name>
    <message>
        <source>Arm</source>
        <translation>解锁</translation>
    </message>
    <message>
        <source>Disarm</source>
        <translation>锁定</translation>
    </message>
</context>

<!-- ========== 解锁指示器 ========== -->
<context>
    <name>ArmedIndicator</name>
    <message>
        <source>Armed</source>
        <translation>已解锁</translation>
    </message>
    <message>
        <source>Disarmed</source>
        <translation>已锁定</translation>
    </message>
    <message>
        <source>Arm</source>
        <translation>解锁</translation>
    </message>
    <message>
        <source>Disarm</source>
        <translation>锁定</translation>
    </message>
</context>

<!-- ========== 设置页面 ========== -->
<context>
    <name>SetupPage</name>
    <message>
        <source>armed</source>
        <translation>已解锁</translation>
    </message>
    <message>
        <source>flying</source>
        <translation>航行中</translation>
    </message>
</context>

<!-- ========== 测量任务编辑器 ========== -->
<context>
    <name>SurveyItemEditor</name>
    <message>
        <source>Fly alternate transects</source>
        <translation>交替航线航行</translation>
    </message>
</context>

<!-- ========== 固定翼降落模式编辑器 (隐藏或适配) ========== -->
<context>
    <name>FWLandingPatternEditor</name>
    <message>
        <source>Landing point</source>
        <translation>停泊点</translation>
    </message>
    <message>
        <source>Flight Speed</source>
        <translation>航行速度</translation>
    </message>
</context>

<!-- ========== VTOL 降落模式编辑器 ========== -->
<context>
    <name>VTOLLandingPatternEditor</name>
    <message>
        <source>Landing point</source>
        <translation>停泊点</translation>
    </message>
    <message>
        <source>Landing Dist</source>
        <translation>停泊距离</translation>
    </message>
</context>

<!-- ========== 降落区域地图可视化 ========== -->
<context>
    <name>FWLandingPatternMapVisual</name>
    <message>
        <source>Landing Area</source>
        <translation>停泊区域</translation>
    </message>
</context>

<context>
    <name>VTOLLandingPatternMapVisual</name>
    <message>
        <source>Land</source>
        <translation>停泊</translation>
    </message>
</context>

<!-- ========== 飞行模式菜单指示器 ========== -->
<context>
    <name>FlightModeMenuIndicator</name>
    <message>
        <source>Land Descent Rate:</source>
        <translation>停泊下降速率:</translation>
    </message>
</context>

</TS>

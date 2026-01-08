# QGroundControl USV (无人船) 定制构建

## 概述

这是一个针对无人船 (Unmanned Surface Vehicle, USV) 的 QGroundControl 定制构建。

### 主要特性

- 🚤 **载具类型锁定**：仅支持 Rover/Boat 类型载具
- 🔧 **双固件支持**：同时兼容 ArduPilot (ArduRover) 和 PX4
- ✂️ **功能精简**：隐藏不适用于无人船的功能（起飞、降落、高度控制等）
- 📋 **专用检查清单**：无人船预航检查清单
- 🎨 **可选品牌定制**：支持自定义 Logo 和主题颜色

## 支持的固件

| 固件 | 版本 | 状态 |
|------|------|------|
| ArduPilot (ArduRover) | 4.x+ | ✅ 完全支持 |
| PX4 | 1.14+ | ✅ 完全支持 |

用户可以在设置中选择使用 ArduPilot 或 PX4 固件进行离线任务规划。

## 构建方法

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
│   └── CustomOverrides.cmake       # CMake 配置覆盖
├── res/
│   ├── img/
│   │   ├── usv-logo-white.svg      # 白色 Logo (深色背景)
│   │   └── usv-logo-black.svg      # 黑色 Logo (浅色背景)
│   ├── USVChecklist.qml            # 无人船预航检查清单
│   └── USVFlyViewCustomLayer.qml   # 飞行视图自定义层
├── src/
│   ├── USVPlugin.h/cc              # 主插件 (核心)
│   ├── USVOptions.h/cc             # 选项配置
│   ├── FirmwarePlugin/
│   │   ├── USVFirmwarePlugin.h/cc  # 双固件插件 (ArduPilot + PX4)
│   │   └── USVFirmwarePluginFactory.h/cc
│   └── AutoPilotPlugin/
│       └── USVAutoPilotPlugin.h/cc # 双固件自动驾驶插件
├── CMakeLists.txt
├── custom.qrc
└── README.md
```

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
- 船体检查
- 螺旋桨检查
- 水域检查
- 天气检查
- 通信检查

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

# QGroundControl USV (无人船) 定制构建

## 概述

这是一个针对无人船 (Unmanned Surface Vehicle, USV) 的 QGroundControl 定制构建。

主要特性：
- 🚤 **载具类型锁定**：仅支持 Rover/Boat 类型载具
- ✂️ **功能精简**：隐藏不适用于无人船的功能（起飞、降落、高度控制等）
- 📋 **专用检查清单**：无人船预航检查清单
- 🎨 **可选品牌定制**：支持自定义 Logo 和主题颜色

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
│   └── CustomOverrides.cmake    # CMake 配置覆盖
├── src/
│   ├── USVPlugin.h/cc           # 主插件
│   ├── USVOptions.h/cc          # 选项配置
│   ├── FirmwarePlugin/          # 固件插件
│   │   ├── USVFirmwarePlugin.h/cc
│   │   └── USVFirmwarePluginFactory.h/cc
│   └── AutoPilotPlugin/         # 自动驾驶插件
│       └── USVAutoPilotPlugin.h/cc
├── res/
│   ├── USVChecklist.qml         # 预航检查清单
│   └── USVFlyViewCustomLayer.qml # 飞行视图自定义层
├── CMakeLists.txt
├── custom.qrc
└── README.md
```

## 定制内容

### 1. 载具类型限制
- 离线编辑默认使用 Rover/Boat 类型
- 固件类型默认为 ArduPilot (ArduRover)
- 用户无法在设置中更改载具类型

### 2. 隐藏的功能
- 空速计校准
- 悬停/上升/下降速度设置
- 任务绝对高度显示
- Orbit 模式
- ROI 功能
- 固定翼/VTOL 降落模式

### 3. 保留的功能
- 航点导航
- Survey 测量任务
- 走廊扫描
- 返航 (RTL)
- 紧急停止
- 罗盘/加速度计/陀螺仪校准

### 4. 无人船专用检查清单
- 船体检查
- 螺旋桨检查
- 水域检查
- 天气检查

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
2. 放置到 `res/img/` 目录
3. 更新 `custom.qrc` 文件
4. 修改 `USVPlugin.cc` 中的 `brandImageIndoor()` 和 `brandImageOutdoor()` 方法

## 许可证

遵循 QGroundControl 原始许可证。

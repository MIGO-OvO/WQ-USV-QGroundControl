# USV Custom Build 故障排查指南

## 自定义仪表盘未显示问题

### 问题描述
自定义的 `USVFlyViewCustomLayer.qml` 和 `USVInstrumentPanel.qml` 没有在飞行视图中显示。

### 诊断步骤

#### 1. 检查编译日志

重新编译项目，查看是否有资源文件相关的错误：

```bash
cmake --build build 2>&1 | grep -i "custom\|usv\|qrc"
```

#### 2. 检查运行时日志

启动 QGC 后，查看控制台输出中的 USV 插件日志：

**Windows (PowerShell):**
```powershell
$env:QT_LOGGING_RULES="USV.*=true"
.\build\Desktop_Qt_6_10_1_MSVC2022_64bit-Debug\Debug\QGroundControl.exe
```

**Linux/Mac:**
```bash
QT_LOGGING_RULES="USV.*=true" ./build/QGroundControl
```

**期望看到的日志：**
```
USV.Plugin: USVPlugin created
USV.Plugin: USV Custom Plugin initialized - 无人船专用模式
USV.Plugin: USVQmlOverrideInterceptor created
USV.Plugin: Override resource check: :/USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml exists: true
USV.Plugin: Override resource check: :/USV/qml/QGroundControl/FlightMap/Widgets/IntegratedCompassAttitude.qml exists: true
USV.Plugin: Resource override: /qml/QGroundControl/FlyView/FlyViewCustomLayer.qml -> /USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml
```

**如果看到 `exists: false`**，说明资源文件没有被正确编译进程序。

#### 3. 验证资源文件是否被编译

使用 Qt 的 `rcc` 工具检查资源：

```bash
# 查找编译后的 .qrc 文件
find build -name "*.qrc" | grep -i custom

# 或者检查生成的资源 C++ 文件
find build -name "*custom*.cpp" | grep -i qrc
```

#### 4. 检查 QML 文件语法

确保 QML 文件没有语法错误：

```bash
# 如果安装了 qmllint
qmllint custom/res/USVFlyViewCustomLayer.qml
qmllint custom/res/USVInstrumentPanel.qml
```

### 常见问题和解决方案

#### 问题 1: 资源文件路径不匹配

**症状：** 日志显示 `exists: false`

**解决方案：**
1. 检查 `custom/custom.qrc` 中的路径是否正确
2. 确保文件实际存在于 `custom/res/` 目录
3. 重新运行 CMake 配置：
   ```bash
   cmake -B build -S .
   cmake --build build
   ```

#### 问题 2: QML 模块导入失败

**症状：** 运行时出现 "module not found" 错误

**解决方案：**
检查 QML 文件中的 import 语句是否正确：
```qml
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
```

#### 问题 3: 拦截器未生效

**症状：** 日志中没有 "Resource override" 消息

**可能原因：**
1. 拦截器安装时机太晚（QML 已经被加载）
2. URL 格式不匹配

**解决方案：**
检查 `USVPlugin::createQmlApplicationEngine()` 是否被正确调用。

#### 问题 4: QML 运行时错误

**症状：** 仪表盘显示空白或部分显示

**解决方案：**
1. 检查 QML 文件中使用的属性是否存在：
   - `vehicle.roll.rawValue`
   - `vehicle.pitch.rawValue`
   - `vehicle.groundSpeed.rawValue`

2. 添加空值检查：
   ```qml
   property real roll: vehicle ? vehicle.roll.rawValue : 0
   ```

3. 检查依赖的 QML 组件是否存在：
   - `QGCCompassWidget`
   - `HorizontalFactValueGrid`

### 验证自定义是否生效

#### 方法 1: 视觉检查

启动 QGC 后，进入 Fly View：
1. 左下角应该显示 USV 模式指示器（🚤 图标）
2. 右侧仪表盘应该显示：
   - 罗盘 + 姿态指示条
   - 航行状态（航速、航向、油门、距Home）
   - 姿态监测（横滚、俯仰）
   - 遥测数据条

#### 方法 2: 检查 QML 元素

使用 Qt Creator 的 QML Profiler 或 Gammaray 工具检查 QML 对象树，确认：
- `FlyViewCustomLayer` 类型是否为 USV 版本
- `IntegratedCompassAttitude` 是否被替换为 `USVInstrumentPanel`

#### 方法 3: 修改测试

临时修改 `USVFlyViewCustomLayer.qml`，添加明显的视觉标记：

```qml
Rectangle {
    anchors.centerIn: parent
    width: 200
    height: 100
    color: "red"
    opacity: 0.8
    z: 9999

    QGCLabel {
        anchors.centerIn: parent
        text: "USV CUSTOM LAYER LOADED"
        color: "white"
        font.bold: true
        font.pointSize: 20
    }
}
```

重新编译后，如果看到红色矩形，说明自定义层已加载。

### 调试技巧

#### 启用详细日志

编辑 `custom/src/USVPlugin.cc`，将所有 `qCDebug` 改为 `qCInfo`，以便在默认日志级别下也能看到调试信息。

#### 使用 QML 调试器

在 CMake 配置中启用 QML 调试：
```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug -DQT_QML_DEBUG=ON
```

#### 检查资源别名

使用 Qt 的资源浏览器检查编译后的资源：
```bash
# 提取资源文件列表
strings build/Debug/QGroundControl.exe | grep "USV.*\.qml"
```

### 已知限制

1. **QML 模块类型系统**：通过 `qt_add_qml_module` 注册的 QML 类型可能无法被 URL 拦截器拦截
2. **拦截器时机**：拦截器在 `createQmlApplicationEngine` 中安装，某些早期加载的 QML 可能无法被拦截
3. **缓存问题**：Qt QML 引擎可能缓存已加载的 QML 文件，需要清理缓存：
   ```bash
   rm -rf ~/.cache/QGroundControl
   rm -rf build/.qt
   ```

### 如果问题仍未解决

1. 对比 `custom-example` 的实现，确保配置一致
2. 尝试使用 `custom-example` 的方式组织资源文件
3. 检查 QGC 主项目的 CMakeLists.txt 中 Custom 相关的配置
4. 在 QGC 社区论坛或 GitHub Issues 寻求帮助

### 参考资料

- QGC Custom Build 文档: https://docs.qgroundcontrol.com/master/en/qgc-dev-guide/custom_build.html
- Qt QML URL Interceptor: https://doc.qt.io/qt-6/qqmlabstracturlinterceptor.html
- Qt Resource System: https://doc.qt.io/qt-6/resources.html

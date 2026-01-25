# 测试 USV 自定义层是否加载

## 快速测试步骤

### 1. 临时替换为测试版本

将 `custom.qrc` 中的 `FlyViewCustomLayer.qml` 指向测试文件：

```xml
<qresource prefix="/USV/qml/QGroundControl/FlyView">
    <file alias="FlyViewCustomLayer.qml">res/USVFlyViewCustomLayer_TEST.qml</file>
</qresource>
```

### 2. 重新编译

```bash
cmake --build build --clean-first
```

### 3. 启用日志并运行

```powershell
$env:QT_LOGGING_RULES="USV.*=true"
.\build\Desktop_Qt_6_10_1_MSVC2022_64bit-Debug\Debug\QGroundControl.exe
```

### 4. 检查结果

**成功标志：**
- 控制台日志显示：
  ```
  USV.Plugin: Override resource check: :/USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml exists: true
  USV.Plugin: Resource override: /qml/QGroundControl/FlyView/FlyViewCustomLayer.qml -> /USV/qml/QGroundControl/FlyView/FlyViewCustomLayer.qml
  ```
- 进入 Fly View 后，屏幕中央显示**红色矩形**，内容为 "🚤 USV CUSTOM LAYER"

**如果看到红色矩形**：
✅ QML 覆盖机制正常工作！
→ 问题出在 `USVFlyViewCustomLayer.qml` 或 `USVInstrumentPanel.qml` 的实现上

**如果没有看到红色矩形**：
❌ QML 覆盖机制未生效
→ 需要检查资源文件编译和拦截器配置

### 5. 恢复正常版本

测试完成后，将 `custom.qrc` 改回：

```xml
<qresource prefix="/USV/qml/QGroundControl/FlyView">
    <file alias="FlyViewCustomLayer.qml">res/USVFlyViewCustomLayer.qml</file>
</qresource>
```

## 如果测试失败

### 检查清单

- [ ] `custom/custom.qrc` 文件格式正确（XML 格式）
- [ ] `custom/res/USVFlyViewCustomLayer_TEST.qml` 文件存在
- [ ] CMake 配置中包含了 `CUSTOM_RESOURCES`
- [ ] 编译过程没有错误
- [ ] 运行时启用了 USV 日志

### 调试命令

**检查资源是否被编译：**
```powershell
# 查找 custom 相关的资源文件
Get-ChildItem -Path build -Recurse -Filter "*custom*.qrc"
Get-ChildItem -Path build -Recurse -Filter "*custom*qrc*.cpp"
```

**检查 QML 文件是否在可执行文件中：**
```powershell
# 使用 strings 命令（需要安装 Git Bash 或 WSL）
strings .\build\Desktop_Qt_6_10_1_MSVC2022_64bit-Debug\Debug\QGroundControl.exe | Select-String "USVFlyViewCustomLayer"
```

### 备选方案：直接修改原生文件（不推荐）

如果 QML 覆盖机制始终无法工作，可以临时直接修改原生文件进行测试：

1. 备份原文件：
   ```bash
   copy src\FlyView\FlyViewCustomLayer.qml src\FlyView\FlyViewCustomLayer.qml.bak
   ```

2. 替换为测试文件：
   ```bash
   copy custom\res\USVFlyViewCustomLayer_TEST.qml src\FlyView\FlyViewCustomLayer.qml
   ```

3. 重新编译并测试

4. 恢复原文件：
   ```bash
   copy src\FlyView\FlyViewCustomLayer.qml.bak src\FlyView\FlyViewCustomLayer.qml
   ```

**注意：** 这种方法仅用于测试，不应用于生产环境。

## 下一步

如果测试版本能正常显示红色矩形，说明覆盖机制工作正常，问题出在你的自定义 QML 实现上。

需要检查：
1. `USVFlyViewCustomLayer.qml` 中的 QML 语法
2. `USVInstrumentPanel.qml` 中使用的组件是否都存在
3. 属性绑定是否正确（如 `vehicle.roll.rawValue`）
4. 是否有运行时错误（查看控制台）

如果测试版本也无法显示，说明覆盖机制本身有问题，需要：
1. 检查 CMake 配置
2. 检查资源文件编译
3. 检查拦截器实现
4. 参考 custom-example 的配置

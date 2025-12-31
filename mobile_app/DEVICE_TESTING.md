# 手机USB连接测试指南

## Android 手机测试

### 1. 启用开发者选项和USB调试

#### 步骤：
1. **打开设置** → **关于手机**
2. 连续点击 **版本号** 7次，直到看到"您已成为开发者"
3. 返回设置 → **系统** → **开发者选项**
4. 开启 **USB调试**
5. 开启 **USB安装**（可选，用于直接安装APK）

### 2. 连接手机到电脑

1. 使用USB线连接手机和电脑
2. 手机上会弹出"允许USB调试吗？"提示 → 选择 **允许**
3. 勾选 **始终允许来自这台计算机**（可选）

### 3. 验证连接

打开终端/命令提示符，运行：

```bash
# 检查Flutter环境
flutter doctor

# 查看连接的设备
flutter devices
```

你应该看到类似这样的输出：
```
2 connected devices:

sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64  • Android 13 (API 33)
SM-G991B (mobile)           • R58M12345678  • android-arm64  • Android 13 (API 33)
```

### 4. 运行应用

```bash
cd mobile_app

# 安装依赖（如果还没安装）
flutter pub get

# 运行到连接的手机
flutter run

# 或者指定设备ID运行
flutter run -d R58M12345678
```

### 5. 热重载和调试

应用运行后，在终端中：
- 按 `r` - 热重载（快速刷新）
- 按 `R` - 热重启（完全重启）
- 按 `q` - 退出应用
- 按 `p` - 显示性能监控
- 按 `o` - 切换Android/iOS风格

## iOS 手机测试（Mac only）

### 1. 信任开发者证书

1. 连接iPhone到Mac
2. 手机上：**设置** → **通用** → **VPN与设备管理**
3. 信任你的开发者证书

### 2. 配置Xcode

1. 打开Xcode
2. **Preferences** → **Accounts** → 添加Apple ID
3. 选择你的设备 → **Use for Development**

### 3. 运行应用

```bash
cd mobile_app
flutter run
```

## 常见问题排查

### 问题1：设备未识别

**Android:**
```bash
# 检查ADB连接
adb devices

# 如果显示"unauthorized"，在手机上允许USB调试
# 如果显示"offline"，尝试：
adb kill-server
adb start-server
adb devices
```

**iOS:**
- 确保使用Mac电脑
- 确保Xcode已安装
- 确保设备已信任

### 问题2：应用无法安装

**Android:**
- 检查手机存储空间
- 在开发者选项中开启"USB安装"
- 尝试：`flutter clean && flutter pub get && flutter run`

**iOS:**
- 检查开发者证书是否有效
- 在Xcode中手动配置签名

### 问题3：应用崩溃

查看日志：
```bash
# 实时查看日志
flutter logs

# 或使用adb（Android）
adb logcat | grep flutter
```

### 问题4：网络连接问题

**如果应用无法连接后端：**

1. **确保手机和电脑在同一WiFi网络**
2. **使用电脑的IP地址而非localhost**
   - Windows: `ipconfig` 查看IPv4地址
   - Mac/Linux: `ifconfig` 或 `ip addr`
   - 例如：`http://192.168.1.100:3000`

3. **在应用设置中配置后端URL**
   - 打开应用 → 设置
   - 输入：`http://你的电脑IP:3000`
   - 例如：`http://192.168.1.100:3000`

### 问题5：权限问题

**Android权限：**
应用需要以下权限（已在AndroidManifest.xml中配置）：
- 网络访问
- 蓝牙
- 麦克风
- 存储（用于保存图片）

如果权限未授予，在手机设置中手动授予。

## 调试技巧

### 1. 查看详细日志

```bash
flutter run --verbose
```

### 2. 使用VS Code调试

1. 安装Flutter扩展
2. 按F5开始调试
3. 设置断点进行调试

### 3. 使用Chrome DevTools

```bash
# 运行应用后，在另一个终端
flutter pub global activate devtools
flutter pub global run devtools
```

### 4. 性能分析

```bash
flutter run --profile
```

## 测试 checklist

- [ ] 设备已连接并识别
- [ ] 应用成功安装到手机
- [ ] 应用可以启动
- [ ] 设备发现功能正常
- [ ] 可以触发拍摄
- [ ] 图像可以显示
- [ ] 语音识别工作
- [ ] AI回复正常
- [ ] 网络请求成功
- [ ] 会话历史可以查看

## 快速测试命令

```bash
# 一键测试流程
cd mobile_app
flutter clean
flutter pub get
flutter devices  # 确认设备连接
flutter run      # 运行应用
```

## 获取设备信息

```bash
# Android设备信息
adb shell getprop ro.product.model      # 设备型号
adb shell getprop ro.build.version.sdk  # Android版本

# 查看应用日志
adb logcat -s flutter
```


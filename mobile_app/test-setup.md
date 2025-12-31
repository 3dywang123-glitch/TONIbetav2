# 移动应用测试环境设置

## 前置要求

1. Flutter SDK (>=3.0.0)
2. Android Studio / Xcode（用于设备模拟器）
3. 物理设备或模拟器

## 安装步骤

### 1. 安装依赖
```bash
cd mobile_app
flutter pub get
```

### 2. 检查设备连接
```bash
flutter devices
```

### 3. 运行应用
```bash
flutter run
```

## 配置说明

### 后端 URL 配置
1. 打开应用
2. 进入设置页面
3. 输入后端 API 地址（例如：`http://192.168.1.100:3000`）
4. 点击保存

### 秘书风格选择
在设置页面可以选择：
- `cute`: 元气满满 (Mavis)
- `cold`: 理性冰冷 (System)
- `funny`: 机智幽默 (Friday)
- `tsundere`: 傲娇属性 (Yuki)

## 功能测试清单

### 设备发现
- [ ] UDP 广播发现设备
- [ ] 显示设备状态（ARMED/REST/SCANNING）
- [ ] 设备 IP 和 SSID 显示

### 蓝牙配网
- [ ] BLE 扫描 TONI_PROV 设备
- [ ] 连接设备并发送 WiFi 凭证
- [ ] 配网成功提示

### 图像捕获
- [ ] 触发拍摄按钮
- [ ] 接收 VGA_READY 事件
- [ ] 接收 HD_READY 事件
- [ ] 图像显示在聊天界面

### 语音识别
- [ ] 离线 ASR 实时识别（如果可用）
- [ ] 在线语音识别回退
- [ ] 语音文本显示

### AI 交互
- [ ] 秘书 AI 回复
- [ ] 专家 AI 回复
- [ ] TTS 语音播放
- [ ] 消息历史显示

### 会话历史
- [ ] 查看历史会话列表
- [ ] 查看会话详情
- [ ] 图像预览功能

## 调试技巧

### 查看日志
```bash
flutter run --verbose
```

### 热重载
在运行的应用中按 `r` 进行热重载，按 `R` 进行热重启。

### 清除缓存
```bash
flutter clean
flutter pub get
```

## 常见问题

### 应用无法启动
- 检查 Flutter 版本：`flutter --version`
- 运行 `flutter doctor` 检查环境

### 无法发现设备
- 确认设备和手机在同一 WiFi 网络
- 检查 UDP 端口 8888 是否被占用
- 查看设备日志

### 后端连接失败
- 确认后端服务正在运行
- 检查网络连接
- 使用实际 IP 地址而非 localhost


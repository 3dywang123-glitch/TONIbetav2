# 测试指南

## 快速开始

### 1. 启动后端服务
```bash
cd backend
npm install
npm start
```

### 2. 启动移动应用
```bash
cd mobile_app
flutter pub get
flutter run
```

## 测试流程

### 端到端测试流程

1. **设备发现**
   - 打开应用
   - 等待 UDP 广播发现设备
   - 确认设备状态显示为 "ARMED"

2. **触发拍摄**
   - 点击拍摄按钮
   - 观察状态变化：triggered → waitingVga → vgaReady → waitingHd → hdReady
   - 确认图像显示在聊天界面

3. **语音交互**
   - 说话触发语音识别
   - 确认文本显示
   - 等待秘书 AI 回复
   - 等待专家 AI 回复

4. **查看历史**
   - 点击历史按钮
   - 查看会话列表
   - 点击会话查看详情

## API 测试

### 使用 Postman 或 curl

#### 测试秘书 AI
```bash
POST http://localhost:3000/api/secretary
Content-Type: application/json

{
  "text": "帮我看下这个",
  "image": "base64_image_data",
  "secretary_style": "cute"
}
```

#### 测试专家 AI
```bash
POST http://localhost:3000/api/expert
Content-Type: application/json

{
  "user_context": "这是什么设备",
  "secretary_context": "秘书刚才的回复",
  "image": "base64_image_data",
  "pic_require": "normal",
  "expert": "general_engineer"
}
```

## 数据库验证

### 检查数据是否保存
```sql
-- 查看最近会话
SELECT * FROM sessions ORDER BY created_at DESC LIMIT 5;

-- 查看消息
SELECT * FROM messages ORDER BY created_at DESC LIMIT 10;

-- 查看设备
SELECT * FROM devices;
```

## 性能测试

### 响应时间
- 秘书 AI 响应：< 5秒
- 专家 AI 响应：< 10秒
- 图像获取：< 2秒

### 并发测试
使用 Apache Bench 或类似工具：
```bash
ab -n 100 -c 10 http://localhost:3000/health
```

## 错误场景测试

1. **网络断开**
   - 断开 WiFi
   - 确认错误提示显示
   - 重连后自动恢复

2. **后端不可用**
   - 停止后端服务
   - 确认应用显示友好错误
   - 重启后端后恢复

3. **数据库连接失败**
   - 修改错误的 DATABASE_URL
   - 确认后端仍可运行（仅警告）
   - 修复后自动恢复

## 测试检查清单

- [ ] 设备发现功能正常
- [ ] 图像捕获和显示正常
- [ ] 语音识别工作正常
- [ ] AI 回复正确
- [ ] 会话历史保存和显示
- [ ] 图像预览功能
- [ ] 设置保存和加载
- [ ] 错误处理友好
- [ ] 离线服务回退正常


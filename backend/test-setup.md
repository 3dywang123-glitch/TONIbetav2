# 测试环境设置指南

## 后端测试环境

### 1. 安装依赖
```bash
cd backend
npm install
```

### 2. 配置环境变量
复制 `.env` 文件并更新以下配置：
- `OPENAI_API_KEY`: 你的 OpenAI API Key
- `DATABASE_URL`: PostgreSQL 连接字符串（已配置 Zeabur）
- `PORT`: 服务器端口（默认 3000）

### 3. 启动后端服务
```bash
npm start
# 或开发模式
npm run dev
```

### 4. 验证服务
访问 `http://localhost:3000/health` 应该返回：
```json
{
  "status": "ok",
  "timestamp": "..."
}
```

## 移动应用测试环境

### 1. 安装 Flutter 依赖
```bash
cd mobile_app
flutter pub get
```

### 2. 配置后端 URL
在设置页面中配置后端 API 地址，或修改 `mobile_app/lib/services/ai/ai_service.dart` 中的默认值。

### 3. 运行应用
```bash
flutter run
```

## 数据库测试

### 1. 连接数据库
使用提供的 PostgreSQL 连接信息：
```bash
psql "postgresql://root:Y3hfVlg9avGid6jrWEc18FCu25N70wM4@sha1.clusters.zeabur.com:32744/zeabur"
```

### 2. 检查表结构
```sql
\dt  -- 列出所有表
SELECT * FROM sessions LIMIT 5;
SELECT * FROM messages LIMIT 5;
SELECT * FROM devices LIMIT 5;
```

## API 测试

### 测试秘书 AI
```bash
curl -X POST http://localhost:3000/api/secretary \
  -H "Content-Type: application/json" \
  -d '{
    "text": "帮我看下这个",
    "image": "base64_encoded_image",
    "secretary_style": "cute"
  }'
```

### 测试专家 AI
```bash
curl -X POST http://localhost:3000/api/expert \
  -H "Content-Type: application/json" \
  -d '{
    "user_context": "这是什么",
    "secretary_context": "秘书回复",
    "image": "base64_encoded_image",
    "pic_require": "normal",
    "expert": "general_engineer"
  }'
```

### 测试会话历史
```bash
curl http://localhost:3000/api/sessions
```

## 常见问题

### 数据库连接失败
- 检查 `DATABASE_URL` 是否正确
- 确认 Zeabur 服务是否运行
- 查看后端日志中的错误信息

### 移动应用无法连接后端
- 确认后端服务正在运行
- 检查防火墙设置
- 确认后端 URL 配置正确（使用实际 IP 而非 localhost）

### 离线语音服务未就绪
- 检查模型文件是否存在于 `assets/model/` 目录
- 查看控制台日志中的错误信息
- 应用会自动回退到在线服务


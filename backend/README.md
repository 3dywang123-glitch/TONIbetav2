# Toni Backend Service

Node.js Express backend for Toni smart camera AI processing.

## Features

- Secretary AI endpoint for initial image analysis
- Expert AI endpoint for detailed analysis
- Configurable AI endpoint (OpenAI-compatible)
- Image processing support

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file:
```
BACKEND_AI_ENDPOINT=https://api.openai.com/v1/chat/completions
OPENAI_API_KEY=your_api_key_here
PORT=3000
```

3. Run the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## API Endpoints

### POST /api/secretary
Analyzes VGA image and provides initial response.

Request:
```json
{
  "text": "帮我看下这个",
  "image": "base64_encoded_image",
  "secretary_style": "cute"
}
```

Response:
```json
{
  "reply": "收到，这看起来像是个断路器，我找老王来。",
  "expert": "general_engineer",
  "expert_id": 6,
  "camera_action": "normal"
}
```

### POST /api/expert
Provides detailed expert analysis.

Request:
```json
{
  "user_context": "完整用户问题",
  "secretary_context": "秘书刚才的回复",
  "image": "base64_encoded_image",
  "pic_require": "normal",
  "expert": "general_engineer"
}
```

Response:
```json
{
  "reply": "详细专家回复"
}
```

## Configuration

- `BACKEND_AI_ENDPOINT`: AI service endpoint URL (OpenAI-compatible)
- `OPENAI_API_KEY`: API key for authentication
- `PORT`: Server port (default: 3000)
- `SECRETARY_MODEL`: Model for secretary AI (default: gpt-4o-mini)
- `EXPERT_MODEL`: Model for expert AI (default: gpt-4o)
- `DATABASE_URL`: PostgreSQL connection string (optional, but recommended)

## Secretary Styles

The secretary supports multiple personality styles:
- `cute`: 元气满满，温暖亲切 (default)
- `cold`: 理性冰冷，极简高效
- `funny`: 机智幽默，轻松调侃
- `tsundere`: 傲娇属性，表面冷淡

## Expert Types

The system supports 20+ expert types including:
- `psychology`: 心理咨询
- `mckinsey`: 商业策略
- `medical`: 医疗咨询
- `general_engineer`: 硬件维修
- `code_engineer`: 代码工程
- And many more...

See `src/core/intents.js` for the complete list.

## Database

The backend uses PostgreSQL to store:
- **Sessions**: User interaction sessions
- **Messages**: All messages (user, secretary, expert)
- **Devices**: Registered Toni devices
- **AI Requests**: Logs of AI API calls for analytics

### Database Endpoints

- `GET /api/sessions` - Get recent sessions
- `GET /api/sessions/:sessionId` - Get session with messages
- `POST /api/devices` - Register or update device
- `GET /api/devices` - Get all devices
- `GET /api/devices/:deviceIp` - Get device by IP

### Database Schema

The database automatically creates the following tables on startup:
- `sessions` - Session information
- `messages` - Message history
- `devices` - Device registry
- `ai_requests` - AI request logs


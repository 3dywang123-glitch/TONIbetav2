# Environment Variables Setup

Create a `.env` file in the `backend/` directory with the following variables:

```env
# AI Configuration
BACKEND_AI_ENDPOINT=https://api.openai.com/v1/chat/completions
OPENAI_API_KEY=your_api_key_here

# Server Configuration
PORT=3000

# Model Configuration (optional)
SECRETARY_MODEL=gpt-4o-mini
EXPERT_MODEL=gpt-4o

# AI Hub Configuration (optional, for Zeabur AI Hub)
MODEL_API_URL=https://hnd1.aihub.zeabur.ai/
MODEL_CODE=claude-sonnet-4-5
# Available models: claude-sonnet-4-5, gemini-3-pro-preview, gemini-3-flash-preview, 
# gpt-5, grok-4-fast-non-reasoning, deepseek-v3.2, qwen-3-32, kimi-k2-thinking
AIHUB_API_KEY=your_aihub_api_key_here

# Database Configuration (Zeabur PostgreSQL)
DATABASE_URL=postgresql://root:Y3hfVlg9avGid6jrWEc18FCu25N70wM4@sha1.clusters.zeabur.com:32744/zeabur
```

## Database Connection Details

- **Host**: sha1.clusters.zeabur.com
- **Port**: 32744
- **Database**: zeabur
- **Username**: root
- **Password**: Y3hfVlg9avGid6jrWEc18FCu25N70wM4

## Database Tables

The following tables will be automatically created on server startup:

1. **sessions** - Stores user interaction sessions
2. **messages** - Stores all messages (user, secretary, expert)
3. **devices** - Stores registered Toni devices
4. **ai_requests** - Logs AI API calls for analytics

## Testing Database Connection

You can test the connection using psql:

```bash
psql "postgresql://root:Y3hfVlg9avGid6jrWEc18FCu25N70wM4@sha1.clusters.zeabur.com:32744/zeabur"
```


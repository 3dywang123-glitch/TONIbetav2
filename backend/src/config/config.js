require('dotenv').config();

module.exports = {
  aiEndpoint: process.env.BACKEND_AI_ENDPOINT || '',
  modelApiUrl: process.env.MODEL_API_URL || 'https://hnd1.aihub.zeabur.ai/',
  modelCode: process.env.MODEL_CODE || null, // 可选，如: claude-sonnet-4-5, gemini-3-pro-preview 等
  port: process.env.PORT || 3000,
  maxImageSize: 50 * 1024 * 1024, // 50MB
  databaseUrl: process.env.DATABASE_URL || '',
};


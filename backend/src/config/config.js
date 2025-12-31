require('dotenv').config();

module.exports = {
  aiEndpoint: process.env.BACKEND_AI_ENDPOINT || '',
  port: process.env.PORT || 3000,
  maxImageSize: 50 * 1024 * 1024, // 50MB
  databaseUrl: process.env.DATABASE_URL || '',
};


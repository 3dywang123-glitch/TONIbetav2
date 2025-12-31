const { Pool } = require('pg');
const config = require('../config/config');

// Create PostgreSQL connection pool
const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl: false, // Zeabur PostgreSQL may not support SSL, set to false for compatibility
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test connection
pool.on('connect', () => {
  console.log('✅ PostgreSQL connected');
});

pool.on('error', (err) => {
  console.error('❌ PostgreSQL connection error:', err);
});

// Initialize database tables
async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS sessions (
        id SERIAL PRIMARY KEY,
        session_id VARCHAR(255) UNIQUE NOT NULL,
        device_ip VARCHAR(45),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id SERIAL PRIMARY KEY,
        session_id VARCHAR(255) NOT NULL,
        message_type VARCHAR(50) NOT NULL, -- 'user', 'secretary', 'expert'
        content TEXT NOT NULL,
        expert_type VARCHAR(100),
        camera_action VARCHAR(20),
        image_size INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS devices (
        id SERIAL PRIMARY KEY,
        device_ip VARCHAR(45) UNIQUE NOT NULL,
        device_ssid VARCHAR(255),
        last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS ai_requests (
        id SERIAL PRIMARY KEY,
        session_id VARCHAR(255),
        request_type VARCHAR(50) NOT NULL, -- 'secretary', 'expert'
        user_text TEXT,
        image_size INTEGER,
        expert_type VARCHAR(100),
        response_time_ms INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE SET NULL
      )
    `);

    // Create indexes for better query performance
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
      CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
      CREATE INDEX IF NOT EXISTS idx_ai_requests_session_id ON ai_requests(session_id);
      CREATE INDEX IF NOT EXISTS idx_ai_requests_created_at ON ai_requests(created_at);
    `);

    console.log('✅ Database tables initialized');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
    throw error;
  }
}

module.exports = {
  pool,
  initializeDatabase,
};


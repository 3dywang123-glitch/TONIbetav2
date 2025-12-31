const { pool } = require('../../database/db');

class SessionService {
  /**
   * Create a new session
   */
  async createSession(sessionId, deviceIp = null) {
    try {
      const result = await pool.query(
        'INSERT INTO sessions (session_id, device_ip) VALUES ($1, $2) ON CONFLICT (session_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP RETURNING *',
        [sessionId, deviceIp]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error creating session:', error);
      throw error;
    }
  }

  /**
   * Get session by ID
   */
  async getSession(sessionId) {
    try {
      const result = await pool.query(
        'SELECT * FROM sessions WHERE session_id = $1',
        [sessionId]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error getting session:', error);
      throw error;
    }
  }

  /**
   * Save a message to the database
   */
  async saveMessage(sessionId, messageType, content, expertType = null, cameraAction = null, imageSize = null) {
    try {
      const result = await pool.query(
        `INSERT INTO messages (session_id, message_type, content, expert_type, camera_action, image_size)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [sessionId, messageType, content, expertType, cameraAction, imageSize]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error saving message:', error);
      throw error;
    }
  }

  /**
   * Get all messages for a session
   */
  async getSessionMessages(sessionId) {
    try {
      const result = await pool.query(
        'SELECT * FROM messages WHERE session_id = $1 ORDER BY created_at ASC',
        [sessionId]
      );
      return result.rows;
    } catch (error) {
      console.error('Error getting session messages:', error);
      throw error;
    }
  }

  /**
   * Save AI request log
   */
  async saveAIRequest(sessionId, requestType, userText, imageSize, expertType = null, responseTimeMs = null) {
    try {
      const result = await pool.query(
        `INSERT INTO ai_requests (session_id, request_type, user_text, image_size, expert_type, response_time_ms)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [sessionId, requestType, userText, imageSize, expertType, responseTimeMs]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error saving AI request:', error);
      throw error;
    }
  }
}

module.exports = new SessionService();


const express = require('express');
const router = express.Router();
const sessionService = require('../services/database/sessionService');

// Get session with all messages
router.get('/:sessionId', async (req, res) => {
  try {
    const { sessionId } = req.params;
    
    const session = await sessionService.getSession(sessionId);
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    const messages = await sessionService.getSessionMessages(sessionId);

    res.json({
      session,
      messages,
    });
  } catch (error) {
    console.error('Get session error:', error);
    res.status(500).json({
      error: 'Failed to get session',
      message: error.message,
    });
  }
});

// Get recent sessions
router.get('/', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const { pool } = require('../database/db');
    
    const result = await pool.query(
      `SELECT s.*, COUNT(m.id) as message_count 
       FROM sessions s 
       LEFT JOIN messages m ON s.session_id = m.session_id 
       GROUP BY s.id 
       ORDER BY s.updated_at DESC 
       LIMIT $1`,
      [limit]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get sessions error:', error);
    res.status(500).json({
      error: 'Failed to get sessions',
      message: error.message,
    });
  }
});

module.exports = router;


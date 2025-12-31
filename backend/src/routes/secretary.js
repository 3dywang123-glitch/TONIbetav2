const express = require('express');
const router = express.Router();
const { callSecretaryAI } = require('../services/ai/secretaryAI');
const sessionService = require('../services/database/sessionService');

router.post('/', async (req, res) => {
  const startTime = Date.now();
  let sessionId = req.body.session_id || `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  
  try {
    const { text, image, secretary_style, device_ip, model_api_url, model_code } = req.body;

    if (!text) {
      return res.status(400).json({
        error: 'Missing required field: text',
      });
    }

    // Create or update session in database
    if (process.env.DATABASE_URL) {
      try {
        await sessionService.createSession(sessionId, device_ip);
      } catch (dbError) {
        console.error('Database error (non-fatal):', dbError);
      }
    }

    // Image is optional for secretary (can work with text only)
    let base64Data = null;
    let imageSize = null;
    if (image) {
      // Validate image is base64
      if (typeof image !== 'string' || (!image.startsWith('data:image') && !/^[A-Za-z0-9+/=]+$/.test(image))) {
        return res.status(400).json({
          error: 'Invalid image format. Expected base64 string.',
        });
      }

      // Extract base64 data if it includes data URL prefix
      base64Data = image.includes(',') ? image.split(',')[1] : image;
      imageSize = Buffer.from(base64Data, 'base64').length;
    }

    // Get secretary style (default: cute)
    const secretaryStyle = secretary_style || 'cute';

    const result = await callSecretaryAI(text, base64Data, secretaryStyle, model_api_url, model_code);
    const responseTime = Date.now() - startTime;

    // Save to database
    if (process.env.DATABASE_URL) {
      try {
        // Save user message
        await sessionService.saveMessage(sessionId, 'user', text, null, null, imageSize);
        
        // Save secretary response
        await sessionService.saveMessage(
          sessionId,
          'secretary',
          result.reply,
          result.expert,
          result.camera_action,
          null
        );

        // Save AI request log
        await sessionService.saveAIRequest(
          sessionId,
          'secretary',
          text,
          imageSize,
          result.expert,
          responseTime
        );
      } catch (dbError) {
        console.error('Database error (non-fatal):', dbError);
      }
    }

    res.json({
      ...result,
      session_id: sessionId,
    });
  } catch (error) {
    console.error('Secretary route error:', error);
    res.status(500).json({
      error: 'Failed to process secretary AI request',
      message: error.message,
    });
  }
});

module.exports = router;


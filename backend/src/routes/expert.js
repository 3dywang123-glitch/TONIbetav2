const express = require('express');
const router = express.Router();
const { callExpertAI } = require('../services/ai/expertAI');
const sessionService = require('../services/database/sessionService');

router.post('/', async (req, res) => {
  const startTime = Date.now();
  const { session_id } = req.body;
  
  try {
    const { user_context, secretary_context, image, pic_require, expert, burst_images, model_api_url, model_code } = req.body;

    if (!user_context || !image) {
      return res.status(400).json({
        error: 'Missing required fields: user_context and image',
      });
    }

    // Validate image is base64
    if (typeof image !== 'string' || (!image.startsWith('data:image') && !/^[A-Za-z0-9+/=]+$/.test(image))) {
      return res.status(400).json({
        error: 'Invalid image format. Expected base64 string.',
      });
    }

    // Extract base64 data if it includes data URL prefix
    const base64Data = image.includes(',') ? image.split(',')[1] : image;
    const imageSize = Buffer.from(base64Data, 'base64').length;

    // Process burst images if provided
    let burstImagesBase64 = null;
    if (burst_images && Array.isArray(burst_images) && burst_images.length > 0) {
      burstImagesBase64 = burst_images.map(img => {
        if (typeof img === 'string') {
          return img.includes(',') ? img.split(',')[1] : img;
        }
        return null;
      }).filter(Boolean);
    }

    // Get expert name (default: general_engineer)
    const expertName = expert || 'general_engineer';

    const result = await callExpertAI(
      user_context,
      secretary_context || '',
      base64Data,
      expertName,
      burstImagesBase64, // 传递连拍图像
      model_api_url,
      model_code
    );
    const responseTime = Date.now() - startTime;

    // Save to database
    if (process.env.DATABASE_URL && session_id) {
      try {
        // Save expert response
        await sessionService.saveMessage(
          session_id,
          'expert',
          result.reply,
          expertName,
          null,
          imageSize
        );

        // Save AI request log
        await sessionService.saveAIRequest(
          session_id,
          'expert',
          user_context,
          imageSize,
          expertName,
          responseTime
        );
      } catch (dbError) {
        console.error('Database error (non-fatal):', dbError);
      }
    }

    res.json(result);
  } catch (error) {
    console.error('Expert route error:', error);
    res.status(500).json({
      error: 'Failed to process expert AI request',
      message: error.message,
    });
  }
});

module.exports = router;


const axios = require('axios');
const config = require('../../config/config');
const { getExpertPrompt } = require('../../core/prompts/experts');

async function callExpertAI(userContext, secretaryContext, imageBase64, expertName = 'general_engineer', burstImagesBase64 = null) {
  if (!config.aiEndpoint) {
    throw new Error('AI endpoint not configured');
  }

  try {
    // Get expert-specific system prompt
    const systemPrompt = getExpertPrompt(expertName);
    
    // Construct user prompt with context
    let userPrompt = `你的秘书刚才对用户说："${secretaryContext}"。请承接这句话，基于这张高清图片`;
    
    if (burstImagesBase64 && burstImagesBase64.length > 0) {
      userPrompt += `（共${burstImagesBase64.length + 1}张连拍图像）`;
    }
    
    userPrompt += `，回答用户的完整问题："${userContext}"。`;

    // Build image content array
    const imageContent = [
      {
        type: 'image_url',
        image_url: {
          url: `data:image/jpeg;base64,${imageBase64}`,
        },
      },
    ];

    // Add burst images if provided
    if (burstImagesBase64 && burstImagesBase64.length > 0) {
      for (const burstImg of burstImagesBase64) {
        imageContent.push({
          type: 'image_url',
          image_url: {
            url: `data:image/jpeg;base64,${burstImg}`,
          },
        });
      }
    }

    // Prepare request for OpenAI-compatible API
    const requestBody = {
      model: process.env.EXPERT_MODEL || 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: systemPrompt,
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: userPrompt,
            },
            ...imageContent,
          ],
        },
      ],
      max_tokens: 1500,
    };

    const response = await axios.post(config.aiEndpoint, requestBody, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.OPENAI_API_KEY || ''}`,
      },
      timeout: 30000,
    });

    const content = response.data.choices[0].message.content;

    return {
      reply: content,
    };
  } catch (error) {
    console.error('Expert AI error:', error.message);
    throw error;
  }
}

module.exports = { callExpertAI };


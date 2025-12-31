const axios = require('axios');
const config = require('../../config/config');
const { getSecretaryPrompt } = require('../../core/prompts/secretary');
const { getExpertIdByName } = require('../../core/intents');

async function callSecretaryAI(text, imageBase64, secretaryStyle = 'cute', modelApiUrl = null, modelCode = null) {
  // 使用传入的模型API URL，或从环境变量获取，或使用默认值
  const apiUrl = modelApiUrl || config.modelApiUrl || config.aiEndpoint;
  if (!apiUrl) {
    throw new Error('AI endpoint not configured');
  }

  // 使用传入的模型代码，或从环境变量获取
  const model = modelCode || process.env.MODEL_CODE || process.env.SECRETARY_MODEL || 'gpt-4o-mini';

  try {
    const systemPrompt = getSecretaryPrompt(secretaryStyle);
    const userPrompt = `用户输入: ${text}`;

    // 构建请求URL（如果提供了模型代码，可能需要添加到URL中）
    let requestUrl = apiUrl;
    if (modelCode && apiUrl.includes('aihub.zeabur.ai')) {
      // 对于Zeabur AI Hub，模型代码可能需要作为路径参数
      requestUrl = `${apiUrl.replace(/\/$/, '')}/v1/chat/completions`;
    } else if (!apiUrl.includes('/v1/chat/completions') && !apiUrl.includes('/chat/completions')) {
      // 如果URL不包含完整路径，添加标准路径
      requestUrl = `${apiUrl.replace(/\/$/, '')}/v1/chat/completions`;
    }

    // Prepare request for OpenAI-compatible API
    const requestBody = {
      model: model,
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
            ...(imageBase64 ? [{
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`,
              },
            }] : []),
          ],
        },
      ],
      response_format: { type: 'json_object' },
      max_tokens: 500,
    };

    const response = await axios.post(requestUrl, requestBody, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.OPENAI_API_KEY || process.env.AIHUB_API_KEY || ''}`,
      },
      timeout: 30000,
    });

    // Parse response
    const content = response.data.choices[0].message.content;
    
    // Parse JSON response
    let result;
    try {
      result = JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse secretary JSON:', e);
      // Fallback: assume general_engineer
      result = {
        intent: 'general_engineer',
        reply: '收到您的请求，我正在处理中。',
      };
    }

    // Validate intent
    const expertId = getExpertIdByName(result.intent);
    const expertName = result.intent || 'general_engineer';

    // Determine camera action: prioritize AI's judgment, then fallback to expert type
    let cameraAction = 'normal';
    
    // First, check if AI explicitly set camera_action in response
    if (result.camera_action === 'wide' || result.camera_action === 'normal') {
      cameraAction = result.camera_action;
    } else {
      // Fallback: determine based on expert type
      const wideAngleExperts = ['travel', 'fengshui', 'detective'];
      cameraAction = wideAngleExperts.includes(expertName) ? 'wide' : 'normal';
    }

    // Parse burst_count (0-9, default 0)
    let burstCount = 0;
    if (result.burst_count !== undefined) {
      burstCount = Math.max(0, Math.min(9, parseInt(result.burst_count) || 0));
    }

    return {
      reply: result.reply || '收到您的请求，我正在处理中。',
      expert: expertName,
      expert_id: expertId,
      camera_action: cameraAction,
      burst_count: burstCount,
    };
  } catch (error) {
    console.error('Secretary AI error:', error.message);
    throw error;
  }
}

module.exports = { callSecretaryAI };


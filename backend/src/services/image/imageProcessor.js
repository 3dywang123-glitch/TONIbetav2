// Image processing utilities
// Currently using base64 encoding/decoding handled by the routes
// This file can be extended for additional image processing needs

function validateImageBase64(base64String) {
  if (!base64String || typeof base64String !== 'string') {
    return false;
  }

  // Check if it's a valid base64 string
  const base64Regex = /^[A-Za-z0-9+/=]+$/;
  return base64Regex.test(base64String) || base64String.includes('data:image');
}

function extractBase64Data(dataUrl) {
  if (dataUrl.includes(',')) {
    return dataUrl.split(',')[1];
  }
  return dataUrl;
}

module.exports = {
  validateImageBase64,
  extractBase64Data,
};


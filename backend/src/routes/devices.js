const express = require('express');
const router = express.Router();
const deviceService = require('../services/database/deviceService');

// Register or update device
router.post('/', async (req, res) => {
  try {
    const { device_ip, device_ssid } = req.body;

    if (!device_ip) {
      return res.status(400).json({
        error: 'Missing required field: device_ip',
      });
    }

    const device = await deviceService.registerDevice(device_ip, device_ssid);
    res.json(device);
  } catch (error) {
    console.error('Register device error:', error);
    res.status(500).json({
      error: 'Failed to register device',
      message: error.message,
    });
  }
});

// Get all devices
router.get('/', async (req, res) => {
  try {
    const devices = await deviceService.getAllDevices();
    res.json(devices);
  } catch (error) {
    console.error('Get devices error:', error);
    res.status(500).json({
      error: 'Failed to get devices',
      message: error.message,
    });
  }
});

// Get device by IP
router.get('/:deviceIp', async (req, res) => {
  try {
    const { deviceIp } = req.params;
    const device = await deviceService.getDevice(deviceIp);
    
    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json(device);
  } catch (error) {
    console.error('Get device error:', error);
    res.status(500).json({
      error: 'Failed to get device',
      message: error.message,
    });
  }
});

module.exports = router;


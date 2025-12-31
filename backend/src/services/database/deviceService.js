const { pool } = require('../../database/db');

class DeviceService {
  /**
   * Register or update a device
   */
  async registerDevice(deviceIp, deviceSsid = null) {
    try {
      const result = await pool.query(
        `INSERT INTO devices (device_ip, device_ssid) 
         VALUES ($1, $2) 
         ON CONFLICT (device_ip) 
         DO UPDATE SET device_ssid = $2, last_seen = CURRENT_TIMESTAMP 
         RETURNING *`,
        [deviceIp, deviceSsid]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error registering device:', error);
      throw error;
    }
  }

  /**
   * Get device by IP
   */
  async getDevice(deviceIp) {
    try {
      const result = await pool.query(
        'SELECT * FROM devices WHERE device_ip = $1',
        [deviceIp]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error getting device:', error);
      throw error;
    }
  }

  /**
   * Get all devices
   */
  async getAllDevices() {
    try {
      const result = await pool.query(
        'SELECT * FROM devices ORDER BY last_seen DESC'
      );
      return result.rows;
    } catch (error) {
      console.error('Error getting all devices:', error);
      throw error;
    }
  }

  /**
   * Update device last seen timestamp
   */
  async updateLastSeen(deviceIp) {
    try {
      const result = await pool.query(
        'UPDATE devices SET last_seen = CURRENT_TIMESTAMP WHERE device_ip = $1 RETURNING *',
        [deviceIp]
      );
      return result.rows[0];
    } catch (error) {
      console.error('Error updating last seen:', error);
      throw error;
    }
  }
}

module.exports = new DeviceService();


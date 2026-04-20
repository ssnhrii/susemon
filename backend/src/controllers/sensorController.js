const db = require('../config/database');
const moment = require('moment');

// Get all sensor nodes
exports.getNodes = async (req, res) => {
  try {
    const [nodes] = await db.query(`
      SELECT 
        sn.*,
        (SELECT temperature FROM sensor_data WHERE node_id = sn.node_id ORDER BY timestamp DESC LIMIT 1) as current_temp,
        (SELECT humidity FROM sensor_data WHERE node_id = sn.node_id ORDER BY timestamp DESC LIMIT 1) as current_humidity,
        (SELECT status FROM sensor_data WHERE node_id = sn.node_id ORDER BY timestamp DESC LIMIT 1) as current_status
      FROM sensor_nodes sn
      WHERE is_active = TRUE
    `);

    res.json({
      success: true,
      data: nodes
    });
  } catch (error) {
    console.error('Get nodes error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get sensor data by node
exports.getSensorData = async (req, res) => {
  try {
    const { node_id } = req.params;
    const { limit = 20, period = '24h' } = req.query;

    let timeFilter = '';
    if (period === '24h') {
      timeFilter = 'AND timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)';
    } else if (period === '7d') {
      timeFilter = 'AND timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)';
    } else if (period === '30d') {
      timeFilter = 'AND timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)';
    }

    const [data] = await db.query(`
      SELECT * FROM sensor_data
      WHERE node_id = ? ${timeFilter}
      ORDER BY timestamp DESC
      LIMIT ?
    `, [node_id, parseInt(limit)]);

    res.json({
      success: true,
      data: data.reverse() // Oldest first
    });
  } catch (error) {
    console.error('Get sensor data error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get latest data for all nodes
exports.getLatestData = async (req, res) => {
  try {
    const [data] = await db.query(`
      SELECT sd.*, sn.node_name, sn.location
      FROM sensor_data sd
      INNER JOIN sensor_nodes sn ON sd.node_id = sn.node_id
      WHERE sd.timestamp = (
        SELECT MAX(timestamp) FROM sensor_data WHERE node_id = sd.node_id
      )
      ORDER BY sd.node_id
    `);

    res.json({
      success: true,
      data
    });
  } catch (error) {
    console.error('Get latest data error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Add sensor data (from LoRa gateway)
exports.addSensorData = async (req, res) => {
  try {
    const { node_id, temperature, humidity } = req.body;

    if (!node_id || temperature === undefined || humidity === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Data tidak lengkap'
      });
    }

    // Determine status
    let status = 'AMAN';
    if (temperature > 40 || humidity > 80) {
      status = 'BERBAHAYA';
    } else if (temperature > 35 || humidity > 70) {
      status = 'WASPADA';
    }

    // Insert data
    await db.query(`
      INSERT INTO sensor_data (node_id, temperature, humidity, status)
      VALUES (?, ?, ?, ?)
    `, [node_id, temperature, humidity, status]);

    // Create notification if critical
    if (status === 'BERBAHAYA') {
      await db.query(`
        INSERT INTO notifications (node_id, title, message, type)
        VALUES (?, ?, ?, ?)
      `, [
        node_id,
        `Peringatan ${status} - ${node_id}`,
        `Suhu ${temperature}°C, Kelembapan ${humidity}% terdeteksi pada node ${node_id}`,
        'critical'
      ]);
    }

    res.json({
      success: true,
      message: 'Data berhasil disimpan',
      data: { node_id, temperature, humidity, status }
    });

  } catch (error) {
    console.error('Add sensor data error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get statistics
exports.getStatistics = async (req, res) => {
  try {
    const { period = '24h' } = req.query;

    let timeFilter = 'DATE_SUB(NOW(), INTERVAL 24 HOUR)';
    if (period === '7d') timeFilter = 'DATE_SUB(NOW(), INTERVAL 7 DAY)';
    if (period === '30d') timeFilter = 'DATE_SUB(NOW(), INTERVAL 30 DAY)';

    const [stats] = await db.query(`
      SELECT 
        AVG(temperature) as avg_temp,
        MAX(temperature) as max_temp,
        MIN(temperature) as min_temp,
        AVG(humidity) as avg_humidity,
        COUNT(CASE WHEN status = 'BERBAHAYA' THEN 1 END) as danger_count,
        COUNT(CASE WHEN status = 'WASPADA' THEN 1 END) as warning_count,
        COUNT(CASE WHEN status = 'AMAN' THEN 1 END) as safe_count
      FROM sensor_data
      WHERE timestamp >= ${timeFilter}
    `);

    res.json({
      success: true,
      data: stats[0]
    });
  } catch (error) {
    console.error('Get statistics error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const db = require('../config/database');
const { analyzeNode } = require('../ai/anomalyDetector');

// Ambil threshold dari env
const THRESHOLDS = {
  tempWarning: parseFloat(process.env.AI_THRESHOLD_TEMP_WARNING || 35),
  tempDanger:  parseFloat(process.env.AI_THRESHOLD_TEMP        || 40),
  humWarning:  parseFloat(process.env.AI_THRESHOLD_HUM_WARNING || 70),
  humDanger:   parseFloat(process.env.AI_THRESHOLD_HUMIDITY    || 80),
};

// ── GET /ai/prediction/:node_id ───────────────────────────────────────────────

exports.getPrediction = async (req, res) => {
  try {
    const { node_id } = req.params;
    const limit = parseInt(req.query.limit) || 30;

    const [rows] = await db.query(`
      SELECT temperature, humidity, timestamp
      FROM sensor_data
      WHERE node_id = ?
      ORDER BY timestamp DESC
      LIMIT ?
    `, [node_id, limit]);

    if (rows.length < 3) {
      return res.json({
        success: true,
        data: {
          node_id,
          status: 'INSUFFICIENT_DATA',
          message: `Butuh minimal 3 data, saat ini hanya ${rows.length}`,
          confidence: 0,
        },
      });
    }

    // Balik urutan: oldest first untuk analisis tren
    const readings = rows.reverse();
    const result   = analyzeNode(readings, THRESHOLDS);

    // Simpan prediksi ke DB
    await db.query(`
      INSERT INTO ai_predictions
        (node_id, prediction_type, confidence, predicted_value, prediction_time)
      VALUES (?, 'temperature', ?, ?, DATE_ADD(NOW(), INTERVAL 30 MINUTE))
    `, [node_id, result.confidence, result.predicted_temp]);

    // Buat notifikasi otomatis jika anomali baru terdeteksi
    if (result.anomaly_detected) {
      await _createAnomalyNotification(node_id, result);
    }

    res.json({
      success: true,
      data: {
        node_id,
        ...result,
      },
    });
  } catch (err) {
    console.error('getPrediction error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── GET /ai/analysis ──────────────────────────────────────────────────────────

exports.getAnalysis = async (req, res) => {
  try {
    const [nodes] = await db.query(
      'SELECT node_id, node_name, location FROM sensor_nodes WHERE is_active = TRUE'
    );

    const analysis = [];

    for (const node of nodes) {
      const [rows] = await db.query(`
        SELECT temperature, humidity, timestamp
        FROM sensor_data
        WHERE node_id = ?
        ORDER BY timestamp DESC
        LIMIT 50
      `, [node.node_id]);

      if (rows.length < 3) {
        analysis.push({
          node_id:          node.node_id,
          node_name:        node.node_name,
          location:         node.location,
          status:           'INSUFFICIENT_DATA',
          anomaly_detected: false,
          overheating_risk: false,
          confidence:       0,
        });
        continue;
      }

      const readings = rows.reverse();
      const result   = analyzeNode(readings, THRESHOLDS);

      analysis.push({
        node_id:   node.node_id,
        node_name: node.node_name,
        location:  node.location,
        ...result,
      });
    }

    // Urutkan: anomali dulu
    analysis.sort((a, b) => {
      if (a.anomaly_detected && !b.anomaly_detected) return -1;
      if (!a.anomaly_detected && b.anomaly_detected) return 1;
      return (b.current_temp || 0) - (a.current_temp || 0);
    });

    res.json({ success: true, data: analysis });
  } catch (err) {
    console.error('getAnalysis error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── GET /ai/summary ───────────────────────────────────────────────────────────

exports.getSummary = async (req, res) => {
  try {
    const [nodes] = await db.query(
      'SELECT node_id FROM sensor_nodes WHERE is_active = TRUE'
    );

    let totalAnomaly = 0;
    let totalOverheat = 0;
    let maxTemp = 0;
    let maxTempNode = null;

    for (const node of nodes) {
      const [rows] = await db.query(`
        SELECT temperature, humidity
        FROM sensor_data WHERE node_id = ?
        ORDER BY timestamp DESC LIMIT 20
      `, [node.node_id]);

      if (rows.length < 3) continue;
      const result = analyzeNode(rows.reverse(), THRESHOLDS);
      if (result.anomaly_detected) totalAnomaly++;
      if (result.overheating_risk) totalOverheat++;
      if (result.current_temp > maxTemp) {
        maxTemp = result.current_temp;
        maxTempNode = node.node_id;
      }
    }

    // Global status
    let globalStatus = 'AMAN';
    if (totalOverheat > 0) globalStatus = 'BERBAHAYA';
    else if (totalAnomaly > 0) globalStatus = 'WASPADA';

    // Statistik 24 jam
    const [stats] = await db.query(`
      SELECT
        ROUND(AVG(temperature), 2) as avg_temp,
        ROUND(MAX(temperature), 2) as max_temp,
        ROUND(MIN(temperature), 2) as min_temp,
        COUNT(CASE WHEN status = 'BERBAHAYA' THEN 1 END) as danger_count,
        COUNT(CASE WHEN status = 'WASPADA'   THEN 1 END) as warning_count
      FROM sensor_data
      WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    `);

    res.json({
      success: true,
      data: {
        global_status:   globalStatus,
        anomaly_count:   totalAnomaly,
        overheat_count:  totalOverheat,
        hottest_node:    maxTempNode,
        hottest_temp:    maxTemp,
        active_nodes:    nodes.length,
        stats_24h:       stats[0],
      },
    });
  } catch (err) {
    console.error('getSummary error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── GET /ai/history/:node_id ──────────────────────────────────────────────────

exports.getPredictionHistory = async (req, res) => {
  try {
    const { node_id } = req.params;
    const limit = parseInt(req.query.limit) || 20;

    const [rows] = await db.query(`
      SELECT * FROM ai_predictions
      WHERE node_id = ?
      ORDER BY created_at DESC
      LIMIT ?
    `, [node_id, limit]);

    res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getPredictionHistory error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── POST /ai/analyze (manual trigger) ────────────────────────────────────────

exports.runAnalysis = async (req, res) => {
  try {
    const { node_id } = req.body;

    const nodeFilter = node_id ? 'WHERE node_id = ?' : 'WHERE is_active = TRUE';
    const params     = node_id ? [node_id] : [];
    const [nodes]    = await db.query(
      `SELECT node_id FROM sensor_nodes ${nodeFilter}`, params
    );

    const results = [];
    for (const node of nodes) {
      const [rows] = await db.query(`
        SELECT temperature, humidity, timestamp
        FROM sensor_data WHERE node_id = ?
        ORDER BY timestamp DESC LIMIT 50
      `, [node.node_id]);

      if (rows.length < 3) continue;
      const result = analyzeNode(rows.reverse(), THRESHOLDS);

      if (result.anomaly_detected) {
        await _createAnomalyNotification(node.node_id, result);
      }

      results.push({ node_id: node.node_id, ...result });
    }

    res.json({
      success: true,
      message: `Analisis selesai untuk ${results.length} node`,
      data: results,
    });
  } catch (err) {
    console.error('runAnalysis error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── Helper: buat notifikasi anomali ──────────────────────────────────────────

async function _createAnomalyNotification(nodeId, result) {
  try {
    // Cek apakah notifikasi serupa sudah ada dalam 10 menit terakhir
    const [existing] = await db.query(`
      SELECT id FROM notifications
      WHERE node_id = ? AND type IN ('critical','warning')
        AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
      LIMIT 1
    `, [nodeId]);

    if (existing.length > 0) return; // Hindari spam notifikasi

    const type    = result.risk_level === 'HIGH' ? 'critical' : 'warning';
    const title   = result.overheating_risk
      ? `Overheating Terdeteksi - Node ${nodeId}`
      : `Anomali Suhu - Node ${nodeId}`;
    const insight = result.insights.length > 0 ? result.insights[0] : '';
    const message = `${insight} | Confidence: ${result.confidence}% | Prediksi 30 mnt: ${result.predicted_temp}°C`;

    await db.query(`
      INSERT INTO notifications (node_id, title, message, type)
      VALUES (?, ?, ?, ?)
    `, [nodeId, title, message, type]);

    console.log(`🤖 AI Notifikasi: [${type.toUpperCase()}] ${title}`);
  } catch (err) {
    console.error('_createAnomalyNotification error:', err);
  }
}

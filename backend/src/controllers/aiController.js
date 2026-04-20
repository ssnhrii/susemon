const db = require('../config/database');

// Simple AI prediction using Moving Average and Z-score
exports.getPrediction = async (req, res) => {
  try {
    const { node_id } = req.params;

    // Get last 10 data points
    const [data] = await db.query(`
      SELECT temperature, humidity, timestamp
      FROM sensor_data
      WHERE node_id = ?
      ORDER BY timestamp DESC
      LIMIT 10
    `, [node_id]);

    if (data.length < 5) {
      return res.json({
        success: true,
        data: {
          prediction: 'Insufficient data',
          confidence: 0
        }
      });
    }

    // Calculate moving average
    const temps = data.map(d => parseFloat(d.temperature));
    const avgTemp = temps.reduce((a, b) => a + b, 0) / temps.length;

    // Calculate standard deviation
    const variance = temps.reduce((sum, temp) => sum + Math.pow(temp - avgTemp, 2), 0) / temps.length;
    const stdDev = Math.sqrt(variance);

    // Calculate Z-score for latest temp
    const latestTemp = temps[0];
    const zScore = (latestTemp - avgTemp) / stdDev;

    // Predict next temperature (simple linear trend)
    const trend = (temps[0] - temps[temps.length - 1]) / temps.length;
    const predictedTemp = latestTemp + (trend * 6); // Predict 30 minutes ahead (6 * 5min intervals)

    // Determine risk level
    let riskLevel = 'LOW';
    let confidence = 70;

    if (Math.abs(zScore) > 2.5) {
      riskLevel = 'HIGH';
      confidence = 94;
    } else if (Math.abs(zScore) > 1.5) {
      riskLevel = 'MEDIUM';
      confidence = 87;
    } else {
      riskLevel = 'LOW';
      confidence = 91;
    }

    // Save prediction
    await db.query(`
      INSERT INTO ai_predictions (node_id, prediction_type, confidence, predicted_value, prediction_time)
      VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 30 MINUTE))
    `, [node_id, 'temperature', confidence, predictedTemp.toFixed(2)]);

    res.json({
      success: true,
      data: {
        node_id,
        current_temp: latestTemp,
        predicted_temp: predictedTemp.toFixed(2),
        moving_average: avgTemp.toFixed(2),
        z_score: zScore.toFixed(2),
        risk_level: riskLevel,
        confidence,
        trend: trend > 0 ? 'increasing' : 'decreasing'
      }
    });

  } catch (error) {
    console.error('Get prediction error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get AI analysis summary
exports.getAnalysis = async (req, res) => {
  try {
    const [nodes] = await db.query('SELECT node_id FROM sensor_nodes WHERE is_active = TRUE');

    const analysis = [];

    for (const node of nodes) {
      // Get last 10 data points
      const [data] = await db.query(`
        SELECT temperature FROM sensor_data
        WHERE node_id = ?
        ORDER BY timestamp DESC
        LIMIT 10
      `, [node.node_id]);

      if (data.length >= 5) {
        const temps = data.map(d => parseFloat(d.temperature));
        const avgTemp = temps.reduce((a, b) => a + b, 0) / temps.length;
        const variance = temps.reduce((sum, temp) => sum + Math.pow(temp - avgTemp, 2), 0) / temps.length;
        const stdDev = Math.sqrt(variance);
        const zScore = (temps[0] - avgTemp) / stdDev;

        let anomalyDetected = false;
        let overheatingRisk = false;

        if (Math.abs(zScore) > 2.5) anomalyDetected = true;
        if (temps[0] > 38) overheatingRisk = true;

        analysis.push({
          node_id: node.node_id,
          anomaly_detected: anomalyDetected,
          overheating_risk: overheatingRisk,
          confidence: anomalyDetected ? 87 : 91,
          current_temp: temps[0],
          avg_temp: avgTemp.toFixed(2)
        });
      }
    }

    res.json({
      success: true,
      data: analysis
    });

  } catch (error) {
    console.error('Get analysis error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

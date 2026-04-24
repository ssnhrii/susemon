const express = require('express');
const cors = require('cors');
const WebSocket = require('ws');
require('dotenv').config();

const routes = require('./routes');
const db = require('./config/database');
const { analyzeNode } = require('./ai/anomalyDetector');

const app = express();
const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 3001;

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || '*',
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Routes
app.use('/api', routes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Start HTTP server
app.listen(PORT, () => {
  console.log('');
  console.log('🚀 ========================================');
  console.log('   SUSEMON Backend API Server');
  console.log('   PBL-TRPL412 - Politeknik Negeri Bali');
  console.log('========================================');
  console.log(`📡 HTTP Server: http://localhost:${PORT}`);
  console.log(`🔌 WebSocket: ws://localhost:${WS_PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV}`);
  console.log('========================================');
  console.log('');
  console.log('📋 Available Endpoints:');
  console.log(`   GET  /api/health`);
  console.log(`   POST /api/auth/login`);
  console.log(`   GET  /api/sensors/nodes`);
  console.log(`   GET  /api/sensors/latest`);
  console.log(`   GET  /api/sensors/data/:node_id`);
  console.log(`   POST /api/sensors/data`);
  console.log(`   GET  /api/ai/prediction/:node_id`);
  console.log(`   GET  /api/ai/analysis`);
  console.log(`   GET  /api/notifications`);
  console.log('========================================');
  console.log('');
});

// WebSocket Server for real-time updates
const wss = new WebSocket.Server({ port: WS_PORT });

wss.on('connection', (ws) => {
  console.log('✅ New WebSocket client connected');

  ws.on('message', (message) => {
    console.log('📨 Received:', message.toString());
  });

  ws.on('close', () => {
    console.log('❌ WebSocket client disconnected');
  });

  // Send initial message
  ws.send(JSON.stringify({
    type: 'connection',
    message: 'Connected to SUSEMON WebSocket server',
    timestamp: new Date().toISOString()
  }));
});

// Broadcast sensor data to all connected clients
const broadcastSensorData = async () => {
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

    const message = JSON.stringify({
      type: 'sensor_update',
      data,
      timestamp: new Date().toISOString()
    });

    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  } catch (error) {
    console.error('Broadcast error:', error);
  }
};

// Broadcast every 3 seconds
setInterval(broadcastSensorData, 3000);

// ── Auto AI Analysis setiap 5 menit ──────────────────────────────────────────
const THRESHOLDS = {
  tempWarning: parseFloat(process.env.AI_THRESHOLD_TEMP_WARNING || 35),
  tempDanger:  parseFloat(process.env.AI_THRESHOLD_TEMP        || 40),
  humWarning:  parseFloat(process.env.AI_THRESHOLD_HUM_WARNING || 70),
  humDanger:   parseFloat(process.env.AI_THRESHOLD_HUMIDITY    || 80),
};

const runAutoAI = async () => {
  try {
    const [nodes] = await db.query('SELECT node_id FROM sensor_nodes WHERE is_active = TRUE');
    let anomalyCount = 0;

    for (const node of nodes) {
      const [rows] = await db.query(`
        SELECT temperature, humidity, timestamp
        FROM sensor_data WHERE node_id = ?
        ORDER BY timestamp DESC LIMIT 50
      `, [node.node_id]);

      if (rows.length < 3) continue;
      const result = analyzeNode(rows.reverse(), THRESHOLDS);

      if (result.anomaly_detected) {
        anomalyCount++;
        // Cek duplikat notifikasi (10 menit)
        const [existing] = await db.query(`
          SELECT id FROM notifications
          WHERE node_id = ? AND type IN ('critical','warning')
            AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
          LIMIT 1
        `, [node.node_id]);

        if (!existing.length) {
          const type  = result.risk_level === 'HIGH' ? 'critical' : 'warning';
          const title = result.overheating_risk
            ? `Overheating - Node ${node.node_id}`
            : `Anomali - Node ${node.node_id}`;
          const msg   = result.insights.length
            ? result.insights[0]
            : `Confidence: ${result.confidence}%`;

          await db.query(`
            INSERT INTO notifications (node_id, title, message, type)
            VALUES (?, ?, ?, ?)
          `, [node.node_id, title, msg, type]);
        }

        // Broadcast AI alert via WebSocket
        const alert = JSON.stringify({
          type: 'ai_alert',
          node_id: node.node_id,
          risk_level: result.risk_level,
          confidence: result.confidence,
          insights: result.insights,
          timestamp: new Date().toISOString(),
        });
        wss.clients.forEach(c => {
          if (c.readyState === WebSocket.OPEN) c.send(alert);
        });
      }
    }

    if (anomalyCount > 0) {
      console.log(`🤖 AI Auto-scan: ${anomalyCount} anomali terdeteksi`);
    }
  } catch (err) {
    console.error('Auto AI error:', err);
  }
};

// Jalankan AI pertama kali setelah 10 detik, lalu setiap 5 menit
setTimeout(() => {
  runAutoAI();
  setInterval(runAutoAI, 5 * 60 * 1000);
}, 10000);

console.log(`🔌 WebSocket server started on port ${WS_PORT}`);

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing servers...');
  wss.close();
  process.exit(0);
});

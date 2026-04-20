const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const sensorRoutes = require('./sensorRoutes');
const aiRoutes = require('./aiRoutes');
const notificationRoutes = require('./notificationRoutes');

// API Routes
router.use('/auth', authRoutes);
router.use('/sensors', sensorRoutes);
router.use('/ai', aiRoutes);
router.use('/notifications', notificationRoutes);

// Health check
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'SUSEMON API is running',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;

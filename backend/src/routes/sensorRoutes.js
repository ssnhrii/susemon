const express = require('express');
const router = express.Router();
const sensorController = require('../controllers/sensorController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/nodes', authMiddleware, sensorController.getNodes);
router.get('/data/:node_id', authMiddleware, sensorController.getSensorData);
router.get('/latest', authMiddleware, sensorController.getLatestData);
router.get('/statistics', authMiddleware, sensorController.getStatistics);
router.post('/data', sensorController.addSensorData); // No auth for LoRa gateway

module.exports = router;

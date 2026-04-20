const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/prediction/:node_id', authMiddleware, aiController.getPrediction);
router.get('/analysis', authMiddleware, aiController.getAnalysis);

module.exports = router;

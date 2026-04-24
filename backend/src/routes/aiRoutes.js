const express = require('express');
const router  = express.Router();
const ai      = require('../controllers/aiController');
const auth    = require('../middleware/authMiddleware');

router.get('/prediction/:node_id',  auth, ai.getPrediction);
router.get('/analysis',             auth, ai.getAnalysis);
router.get('/summary',              auth, ai.getSummary);
router.get('/history/:node_id',     auth, ai.getPredictionHistory);
router.post('/analyze',             auth, ai.runAnalysis);

module.exports = router;

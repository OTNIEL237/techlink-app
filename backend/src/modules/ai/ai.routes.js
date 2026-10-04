const express = require('express');
const router = express.Router();
const aiController = require('./ai.controller');
const requireAuth = require('../../middlewares/auth.middleware');

router.use(requireAuth);

router.post('/analyze', aiController.analyzeProblem);

module.exports = router;
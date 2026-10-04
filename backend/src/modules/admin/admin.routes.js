const express = require('express');
const router = express.Router();
const adminController = require('./admin.controller');
const requireAuth = require('../../middlewares/auth.middleware');
const requireAdmin = require('../../middlewares/admin.middleware');

router.use(requireAuth);
router.use(requireAdmin);

// Résolution de litige
router.post('/disputes/:id/resolve', adminController.resolveDispute);

module.exports = router;

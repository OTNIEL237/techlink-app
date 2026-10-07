// =============================================================================
// FICHIER : backend/src/modules/admin/admin.routes.js
// RÔLE : Définition des routes de gestion administrative de l'API TechLink
// MODULE : Backend / Module Administrateur (Routes)
// DÉPENDANCES : express, ./admin.controller, requireAuth, requireAdmin
// SÉCURITÉ / RLS : Toutes les routes nécessitent une authentification valide et le rôle 'admin'
// =============================================================================

const express = require('express');
const router = express.Router();
const adminController = require('./admin.controller');
const requireAuth = require('../../middlewares/auth.middleware');
const requireAdmin = require('../../middlewares/admin.middleware');

// Application des gardes d'authentification et de rôle administrateur à l'ensemble du routeur
router.use(requireAuth);
router.use(requireAdmin);

/**
 * @route POST /api/admin/disputes/:id/resolve
 * @desc Résout un litige ouvert sur une mission avec arbitrage financier
 * @access Privé (Admin uniquement)
 */
router.post('/disputes/:id/resolve', adminController.resolveDispute);

module.exports = router;


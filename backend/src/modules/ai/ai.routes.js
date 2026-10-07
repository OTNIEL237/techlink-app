// =============================================================================
// FICHIER : backend/src/modules/ai/ai.routes.js
// RÔLE : Définition des points d'accès HTTP pour les diagnostics IA
// MODULE : Backend / Module IA (Routes)
// DÉPENDANCES : express, ./ai.controller, requireAuth
// SÉCURITÉ / RLS : Authentification JWT requise via requireAuth
// =============================================================================

const express = require('express');
const router = express.Router();
const aiController = require('./ai.controller');
const requireAuth = require('../../middlewares/auth.middleware');

router.use(requireAuth);

/**
 * @route POST /api/ai/analyze
 * @desc Analyse un problème technique et retourne un diagnostic avec estimation tarifaire
 * @access Privé (Utilisateur authentifié)
 */
router.post('/analyze', aiController.analyzeProblem);

module.exports = router;
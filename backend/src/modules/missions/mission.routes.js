// =============================================================================
// FICHIER : backend/src/modules/missions/mission.routes.js
// RÔLE : Définition des routes de l'API pour les missions (création, consultation, statut)
// MODULE : Backend / Module Missions (Routes)
// DÉPENDANCES : express, ./mission.controller, requireAuth, mission.validator
// SÉCURITÉ / RLS : Authentification obligatoire via requireAuth et validation des payloads d'entrée
// =============================================================================

const express = require('express');
const router = express.Router();
const missionController = require('./mission.controller');
const requireAuth = require('../../middlewares/auth.middleware');
const { createMissionValidator, validateMissionId } = require('../../middlewares/validators/mission.validator');

router.use(requireAuth);

/**
 * @route POST /api/missions/create
 * @desc Crée une nouvelle demande de mission
 * @access Privé
 */
router.post('/create', createMissionValidator, missionController.createMission);

/**
 * @route GET /api/missions/client/:clientId
 * @desc Liste toutes les missions d'un client spécifique
 * @access Privé
 */
router.get('/client/:clientId', missionController.getClientMissions);

/**
 * @route GET /api/missions/:missionId
 * @desc Récupère le détail d'une mission
 * @access Privé
 */
router.get('/:missionId', validateMissionId, missionController.getMissionById);

/**
 * @route PATCH /api/missions/:missionId/status
 * @desc Met à jour le statut opérationnel d'une mission
 * @access Privé
 */
router.patch('/:missionId/status', validateMissionId, missionController.updateMissionStatus);

module.exports = router;
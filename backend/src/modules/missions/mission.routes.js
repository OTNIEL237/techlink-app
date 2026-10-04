const express = require('express');
const router = express.Router();
const missionController = require('./mission.controller');
const requireAuth = require('../../middlewares/auth.middleware');
const { createMissionValidator, validateMissionId } = require('../../middlewares/validators/mission.validator');

router.use(requireAuth);

router.post('/create', createMissionValidator, missionController.createMission);
router.get('/client/:clientId', missionController.getClientMissions);
router.get('/:missionId', validateMissionId, missionController.getMissionById);
router.patch('/:missionId/status', validateMissionId, missionController.updateMissionStatus);

module.exports = router;
// =============================================================================
// FICHIER : backend/src/modules/missions/mission.controller.js
// RÔLE : Contrôleur HTTP pour le cycle de vie des interventions (création, consultation, statut)
// MODULE : Backend / Module Missions
// DÉPENDANCES : ./mission.service
// SÉCURITÉ / RLS : Contrôlé par les validateurs et l'authentification JWT
// =============================================================================

const missionService = require('./mission.service');

/**
 * Crée une nouvelle mission / demande d'intervention technique.
 *
 * @param {import('express').Request} req - Requête contenant les paramètres de la mission (client, description, coordonnées)
 * @param {import('express').Response} res - Réponse renvoyant l'enregistrement de la mission créée
 */
const createMission = async (req, res) => {
  try {
    const mission = await missionService.createMission(req.body);
    res.json({ success: true, data: mission });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};

/**
 * Récupère la liste des missions associées à un client donné.
 *
 * @param {import('express').Request} req - Requête contenant `clientId` dans les paramètres d'URL
 * @param {import('express').Response} res - Réponse renvoyant la liste des missions du client
 */
const getClientMissions = async (req, res) => {
  try {
    const missions = await missionService.getClientMissions(req.params.clientId);
    res.json({ success: true, data: missions });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};

/**
 * Récupère le détail complet d'une mission par son identifiant unique.
 *
 * @param {import('express').Request} req - Requête contenant `missionId` dans les paramètres d'URL
 * @param {import('express').Response} res - Réponse renvoyant l'objet mission complet
 */
const getMissionById = async (req, res) => {
  try {
    const mission = await missionService.getMissionById(req.params.missionId);
    res.json({ success: true, data: mission });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};

/**
 * Met à jour le statut d'avancement d'une mission (ex: 'assigned', 'in_progress', 'completed').
 *
 * @param {import('express').Request} req - Requête contenant `missionId` et le nouveau `status`
 * @param {import('express').Response} res - Réponse renvoyant la mission mise à jour
 */
const updateMissionStatus = async (req, res) => {
  try {
    const mission = await missionService.updateMissionStatus(
      req.params.missionId, req.body.status);
    res.json({ success: true, data: mission });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};

module.exports = { createMission, getClientMissions, getMissionById, updateMissionStatus };
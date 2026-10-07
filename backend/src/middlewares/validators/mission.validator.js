// =============================================================================
// FICHIER : backend/src/middlewares/validators/mission.validator.js
// RÔLE : Schémas de validation des données d'entrée pour les requêtes sur les missions
// MODULE : Backend / Validateurs Express
// DÉPENDANCES : express-validator
// SÉCURITÉ / RLS : Assainissement et validation des types (UUID, chaînes, coordonnées)
// =============================================================================

const { body, param, validationResult } = require('express-validator');

/**
 * Middleware vérifiant les erreurs de validation accumulées par express-validator.
 * Renvoie un code 400 Bad Request avec le détail des champs non conformes.
 *
 * @param {import('express').Request} req - Requête HTTP Express
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Poursuit vers le contrôleur si aucune erreur
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: 'Données invalides', details: errors.array() });
  }
  next();
};

/**
 * Règles de validation pour la création d'une nouvelle demande d'intervention / mission.
 */
const createMissionValidator = [
  body('client_id').isUUID().withMessage('client_id doit être un UUID valide'),
  body('problem_description').isString().notEmpty().withMessage('problem_description est requise'),
  body('urgency_level').optional().isIn(['low', 'normal', 'high', 'urgent']).withMessage('Niveau d\'urgence invalide'),
  body('client_address').optional().isString(),
  body('client_lat').optional().isNumeric(),
  body('client_lng').optional().isNumeric(),
  validate
];

/**
 * Règles de validation pour l'assignation d'une mission à un technicien spécifique.
 */
const assignMissionValidator = [
  param('id').isUUID().withMessage('L\'ID de la mission doit être un UUID'),
  body('technicianId').isUUID().withMessage('L\'ID du technicien doit être un UUID'),
  validate
];

/**
 * Règle de validation vérifiant la présence et la conformité d'un UUID de mission en paramètre d'URL.
 */
const validateMissionId = [
  param('id').isUUID().withMessage('L\'ID de la mission doit être un UUID'),
  validate
];

module.exports = {
  createMissionValidator,
  assignMissionValidator,
  validateMissionId
};


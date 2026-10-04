const { body, param, validationResult } = require('express-validator');

// Middleware d'évaluation des erreurs de validation
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: 'Données invalides', details: errors.array() });
  }
  next();
};

const createMissionValidator = [
  body('client_id').isUUID().withMessage('client_id doit être un UUID valide'),
  body('problem_description').isString().notEmpty().withMessage('problem_description est requise'),
  body('urgency_level').optional().isIn(['low', 'normal', 'high', 'urgent']).withMessage('Niveau d\'urgence invalide'),
  body('client_address').optional().isString(),
  body('client_lat').optional().isNumeric(),
  body('client_lng').optional().isNumeric(),
  validate
];

const assignMissionValidator = [
  param('id').isUUID().withMessage('L\'ID de la mission doit être un UUID'),
  body('technicianId').isUUID().withMessage('L\'ID du technicien doit être un UUID'),
  validate
];

const validateMissionId = [
  param('id').isUUID().withMessage('L\'ID de la mission doit être un UUID'),
  validate
];

module.exports = {
  createMissionValidator,
  assignMissionValidator,
  validateMissionId
};

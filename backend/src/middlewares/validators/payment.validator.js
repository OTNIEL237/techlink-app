const { body, param, validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: 'Données de paiement invalides', details: errors.array() });
  }
  next();
};

const initiatePaymentValidator = [
  body('missionId').isUUID().withMessage('L\'ID de la mission doit être un UUID valide'),
  body('clientId').isUUID().withMessage('L\'ID du client doit être un UUID valide'),
  body('amount').isNumeric().withMessage('Le montant doit être un nombre valide'),
  validate
];

const verifyPaymentValidator = [
  param('reference').isString().trim().notEmpty().withMessage('La référence de paiement est requise'),
  validate
];

module.exports = {
  initiatePaymentValidator,
  verifyPaymentValidator
};

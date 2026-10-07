// =============================================================================
// FICHIER : backend/src/middlewares/validators/payment.validator.js
// RÔLE : Schémas de validation des requêtes d'initiation et de vérification de paiement
// MODULE : Backend / Validateurs Express
// DÉPENDANCES : express-validator
// SÉCURITÉ / RLS : Contrôle strict des montants numériques et des UUIDs de transaction
// =============================================================================

const { body, param, validationResult } = require('express-validator');

/**
 * Middleware d'évaluation des erreurs de validation sur les flux de paiement.
 *
 * @param {import('express').Request} req - Requête HTTP Express
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Poursuit vers le contrôleur si conforme
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: 'Données de paiement invalides', details: errors.array() });
  }
  next();
};

/**
 * Règles de validation pour l'initiation d'une transaction de paiement (mission ou acompte).
 */
const initiatePaymentValidator = [
  body('missionId').isUUID().withMessage('L\'ID de la mission doit être un UUID valide'),
  body('clientId').isUUID().withMessage('L\'ID du client doit être un UUID valide'),
  body('amount').isNumeric().withMessage('Le montant doit être un nombre valide'),
  validate
];

/**
 * Règles de validation pour la vérification du statut d'une transaction par sa référence.
 */
const verifyPaymentValidator = [
  param('reference').isString().trim().notEmpty().withMessage('La référence de paiement est requise'),
  validate
];

module.exports = {
  initiatePaymentValidator,
  verifyPaymentValidator
};


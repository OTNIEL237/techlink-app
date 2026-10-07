// =============================================================================
// FICHIER : backend/src/middlewares/rateLimit.middleware.js
// RÔLE : Protection contre les abus d'API et attaques DoS par limitation du débit (Rate Limiting)
// MODULE : Backend / Middlewares de sécurité
// DÉPENDANCES : express-rate-limit
// SÉCURITÉ / RLS : Bloque les IP dépassant 100 req / 15 min (global) ou 20 req / 15 min (strict)
// =============================================================================

const rateLimit = require('express-rate-limit');

/**
 * Limiteur global appliqué à l'ensemble des routes de l'API Express.
 * Plafonne à 100 requêtes par adresse IP sur une fenêtre glissante de 15 minutes.
 */
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requêtes par IP par fenêtre
  message: { error: 'Trop de requêtes, veuillez réessayer plus tard.' },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * Limiteur strict réservé aux endpoints sensibles et coûteux (génération IA, authentification).
 * Plafonne à 20 requêtes par adresse IP sur une fenêtre de 15 minutes.
 */
const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // 20 requêtes max
  message: { error: 'Trop de requêtes sensibles, veuillez réessayer plus tard.' },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  globalLimiter,
  strictLimiter
};


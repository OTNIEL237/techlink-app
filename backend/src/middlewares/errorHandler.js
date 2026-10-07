// =============================================================================
// FICHIER : backend/src/middlewares/errorHandler.js
// RÔLE : Alias d'exportation vers errorHandler.middleware.js
// MODULE : Backend / Middlewares d'erreurs
// DÉPENDANCES : ./errorHandler.middleware
// SÉCURITÉ / RLS : Sans objet
// =============================================================================

const errorHandler = require('./errorHandler.middleware');

module.exports = errorHandler;

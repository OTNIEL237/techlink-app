// =============================================================================
// FICHIER : backend/src/middlewares/errorHandler.middleware.js
// RÔLE : Gestionnaire d'erreurs global Express (formatage JSON, masquage en production)
// MODULE : Backend / Middlewares d'erreurs
// DÉPENDANCES : process.env.NODE_ENV
// SÉCURITÉ / RLS : Masque les détails techniques sensibles (stack trace) en environnement de production
// =============================================================================

/**
 * Middleware global de capture et formatage des erreurs Express.
 * Doit impérativement être déclaré après l'ensemble des routes dans app.js.
 *
 * @param {Error & {statusCode?: number}} err - Objet d'erreur capturé
 * @param {import('express').Request} req - Requête HTTP Express
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Fonction next (requise par la signature à 4 arguments)
 */
const errorHandler = (err, req, res, next) => {
  console.error(`[Error] ${err.message}`);
  
  // Afficher la stack trace uniquement en développement
  if (process.env.NODE_ENV !== 'production') {
    console.error(err.stack);
  }

  // Si l'erreur a déjà un status défini, on l'utilise
  const statusCode = err.statusCode || 500;
  
  // Masquer les messages d'erreur système en production
  const message = (statusCode === 500 && process.env.NODE_ENV === 'production')
    ? 'Erreur interne du serveur'
    : (err.message || 'Erreur interne du serveur');

  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
};

module.exports = errorHandler;


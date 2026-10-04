/**
 * Middleware global de gestion d'erreurs
 * À placer en TOUT DERNIER dans app.js
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

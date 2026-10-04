/**
 * Middleware d'autorisation administrateur
 * Doit être utilisé APRÈS auth.middleware.js (requireAuth)
 */
const requireAdmin = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Non authentifié' });
  }

  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Accès refusé: droits administrateur requis' });
  }

  next();
};

module.exports = requireAdmin;

// =============================================================================
// FICHIER : backend/src/middlewares/admin.middleware.js
// RÔLE : Contrôle d'accès et vérification du rôle administrateur sur les routes protégées
// MODULE : Backend / Middlewares d'autorisation
// DÉPENDANCES : Nécessite que req.user soit alimenté par auth.middleware.js
// SÉCURITÉ / RLS : Renvoie 401 si non authentifié, 403 si le rôle n'est pas 'admin'
// =============================================================================

/**
 * Middleware d'autorisation pour sécuriser les routes réservées aux administrateurs.
 * Doit impérativement être appliqué après `requireAuth`.
 *
 * @param {import('express').Request} req - Requête HTTP Express contenant l'utilisateur authentifié
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Fonction de rappel pour poursuivre le pipeline Express
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


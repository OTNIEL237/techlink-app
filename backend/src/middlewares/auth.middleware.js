// =============================================================================
// FICHIER : backend/src/middlewares/auth.middleware.js
// RÔLE : Vérification du jeton JWT Supabase et injection de l'utilisateur authentifié
// MODULE : Backend / Middlewares d'authentification
// DÉPENDANCES : ../config/supabase
// SÉCURITÉ / RLS : Valide le token Bearer via supabase.auth.getUser(token) et résout le rôle
// =============================================================================

const supabase = require('../config/supabase');

/**
 * Middleware d'authentification vérifiant le jeton JWT transmis dans l'en-tête `Authorization: Bearer <token>`.
 * Récupère le compte utilisateur Supabase, vérifie son statut et synchronise son rôle applicatif.
 *
 * @param {import('express').Request} req - Requête HTTP Express enrichie avec `req.user` en cas de succès
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Poursuit l'exécution vers le contrôleur ou middleware suivant
 */
const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Token d\'authentification manquant' });
    }

    const token = authHeader.split(' ')[1];

    // Vérifier le token avec Supabase
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      console.error('Erreur authentification:', error?.message);
      return res.status(401).json({ error: 'Token invalide ou expiré' });
    }

    // Injecter l'utilisateur dans la requête pour les middlewares suivants
    req.user = user;
    req.user.role = user.user_metadata?.role || 'client';
    
    // Récupérer le rôle de l'utilisateur dans la table users avec repli sûr
    try {
      const { data: userData } = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
        
      if (userData?.role) {
        req.user.role = userData.role;
      }
    } catch (e) {
      console.warn('Notice: user role db query fallback:', e.message);
    }

    next();
  } catch (error) {
    console.error('Erreur serveur auth middleware:', error);
    res.status(500).json({ error: 'Erreur interne lors de la vérification du token' });
  }
};

module.exports = requireAuth;


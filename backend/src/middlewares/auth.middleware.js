const supabase = require('../config/supabase');

/**
 * Middleware d'authentification
 * Vérifie le JWT envoyé dans le header Authorization: Bearer <token>
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
    
    // Récupérer le rôle de l'utilisateur dans la table users (optionnel, pour vérifications)
    const { data: userData } = await supabase
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single();
      
    if (userData) {
      req.user.role = userData.role;
    }

    next();
  } catch (error) {
    console.error('Erreur serveur auth middleware:', error);
    res.status(500).json({ error: 'Erreur interne lors de la vérification du token' });
  }
};

module.exports = requireAuth;

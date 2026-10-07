// =============================================================================
// FICHIER : backend/api/index.js
// RÔLE : Point d'entrée serverless (Vercel) exportant l'application Express
// MODULE : Backend / Déploiement Serverless
// DÉPENDANCES : ../src/app
// SÉCURITÉ / RLS : Déléguée aux middlewares Express et politiques Supabase
// =============================================================================

/**
 * Point d'entrée principal pour l'exécution en environnement Serverless (ex: Vercel).
 * Exporte l'instance de l'application Express configurée.
 */
const app = require('../src/app');

module.exports = app;


// =============================================================================
// FICHIER : backend/src/config/supabase.js
// RÔLE : Initialisation du client Supabase Admin avec la clé Service Role
// MODULE : Backend / Configuration Base de données
// DÉPENDANCES : @supabase/supabase-js, dotenv
// SÉCURITÉ / RLS : Clé secrète de service (SUPABASE_SERVICE_KEY) contournant le RLS pour opérations système
// =============================================================================

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

/**
 * Instance du client Supabase avec privilèges administrateur (Service Role).
 * Utilisé pour exécuter des requêtes privilégiées et contourner les règles RLS côté serveur.
 */
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

module.exports = supabase;
// =============================================================================
// FICHIER : backend/src/utils/technician.helper.js
// RÔLE : Fonctions d'assistance pour la résolution et recherche des profils techniciens
// MODULE : Backend / Utilitaires Techniciens
// DÉPENDANCES : ../config/supabase
// SÉCURITÉ / RLS : Requêtes directes via le client Supabase serveur
// =============================================================================

const supabase = require('../config/supabase');

/**
 * Recherche un technicien en base de données par son `user_id` (identifiant de compte utilisateur)
 * ou par son `id` (clé primaire de la table `technicians`).
 * Permet une résolution transparente quel que soit le type d'ID transmis par les clients ou webhooks.
 *
 * @param {string} technicianId - Identifiant utilisateur ou identifiant technicien
 * @returns {Promise<Object|null>} Données partielles du technicien (wallet, numéros de paiement) ou null
 */
async function findTechnician(technicianId) {
  const byUserId = await supabase
    .from('technicians')
    .select('id, user_id, wallet_balance, total_earnings, total_missions, mtn_number, orange_number')
    .eq('user_id', technicianId)
    .maybeSingle();

  if (byUserId.data) {
    return byUserId.data;
  }

  const byTechnicianId = await supabase
    .from('technicians')
    .select('id, user_id, wallet_balance, total_earnings, total_missions, mtn_number, orange_number')
    .eq('id', technicianId)
    .maybeSingle();

  return byTechnicianId.data;
}

module.exports = {
  findTechnician
};


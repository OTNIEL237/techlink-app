// =============================================================================
// FICHIER : backend/src/utils/geoUtils.js
// RÔLE : Fonctions de calcul géospatial et de distance (formule de Haversine)
// MODULE : Backend / Utilitaires Géographiques
// DÉPENDANCES : Math natif
// SÉCURITÉ / RLS : Sans objet
// =============================================================================

/**
 * Calcule la distance orthodromique en kilomètres entre deux coordonnées géographiques (formule de Haversine).
 *
 * @param {number} lat1 - Latitude du premier point
 * @param {number} lon1 - Longitude du premier point
 * @param {number} lat2 - Latitude du deuxième point
 * @param {number} lon2 - Longitude du deuxième point
 * @returns {number} Distance en kilomètres
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Rayon de la Terre en km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

module.exports = {
  calculateDistance,
};

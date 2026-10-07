// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : location_utils.dart
// Rôle          : Fonctions utilitaires géographiques (calcul de distance GPS,
//                 formule de Haversine, estimation de temps de trajet).
// Module        : Core / Utilitaires & Géolocalisation
// Dépendances   : dart:math
// Sécurité/RLS  : Public / Utilitaire
// =============================================================================

import 'dart:math' as math;

/// [LocationUtils]
///
/// Outils de calculs spatiaux pour évaluer les distances entre clients et techniciens.
class LocationUtils {
  /// Rayon moyen de la Terre en kilomètres.
  static const double _earthRadiusKm = 6371.0;

  /// Calcule la distance orthodromique entre deux coordonnées GPS via la formule de Haversine.
  ///
  /// - [lat1] : Latitude du point de départ.
  /// - [lon1] : Longitude du point de départ.
  /// - [lat2] : Latitude du point d'arrivée.
  /// - [lon2] : Longitude du point d'arrivée.
  /// - Retourne : Distance en kilomètres.
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Formate une distance pour l'affichage utilisateur (ex: `850 m` ou `3.2 km`).
  ///
  /// - [distanceInKm] : Distance en kilomètres.
  /// - Retourne : Chaîne lisible avec l'unité adaptée.
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1.0) {
      final meters = (distanceInKm * 1000).round();
      return '$meters m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  /// Convertit des degrés en radians.
  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}

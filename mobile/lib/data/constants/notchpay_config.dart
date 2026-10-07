// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : notchpay_config.dart
// Rôle          : Paramètres de configuration et clés d'API de la passerelle NotchPay.
// Module        : Data / Constants
// Dépendances   : Aucune
// Sécurité/RLS  : Contient les clés de test NotchPay et l'URL du serveur backend sécurisé.
// =============================================================================

/// Configuration statique pour l'intégration de la passerelle de paiement NotchPay.
///
/// Définit les clés d'authentification publique et secrète, l'URL de l'API backend
/// servant de relais sécurisé (évitant l'exposition des clés en production),
/// ainsi que le taux de commission prélevé sur les prestations.
class NotchPayConfig {
  /// Clé publique d'API NotchPay utilisée pour initialiser les requêtes côté client.
  static const String publicKey = 'pk_test.MOG7qQphiny4YNvckkb7YliGyPfOuL32AdYLQKOBR66Mn6iBPSF5FZhkEaTQd3uRaZ8twIszq2xXVwDy9Dg9VfQzE29un11lv49DfWOMUpXCGfOy5tVn8rBESMggr'; 

  /// Clé secrète d'API NotchPay (utilisée pour les environnements de test).
  static const String secretKey = 'sk_test.pk3JP5rpjTaHlZm1mVQeCCTDC0b4xa8JGT3QbBPK6vj6T11SOzMyfz4HUfgiMP1VKkRVebqG3v6R1frtMFgib73VMhJNzROxs8LhZhLfqzCTGRL4EJ5gW8FU87mxc';
  
  /// URL de base du serveur backend déployé sur Vercel pour les webhooks et validations de paiement.
  static const String backendUrl = 'https://techlink-backend-nu.vercel.app';
  
  /// Taux de commission de la plateforme TechLink (5% soit 0.05).
  static const double commissionRate = 0.05;
}
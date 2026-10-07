// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : notchpay_service.dart
// Rôle          : Intégration directe avec l'API REST de NotchPay (passerelle de paiement).
// Module        : Data / Services
// Dépendances   : dio, notchpay_config.dart, api_service.dart
// Sécurité/RLS  : Utilise la clé publique NotchPay et configure les URLs de redirection de callback.
// =============================================================================

import 'package:dio/dio.dart';
import '../constants/notchpay_config.dart';
import 'api_service.dart';

/// Service facilitant les appels directs à l'API de paiement NotchPay.
///
/// Gère la création de sessions de paiement en ligne avec redirection web,
/// ainsi que la vérification synchrone du statut de la transaction.
class NotchPayService {
  /// URL de base de l'API REST NotchPay.
  static const String _baseUrl = 'https://api.notchpay.co';

  /// Instance interne du service API pour l'exécution des requêtes HTTP.
  static final ApiService _apiService = ApiService();

  /// Initialise une transaction auprès de NotchPay et génère l'URL de paiement.
  ///
  /// [amount] Montant à facturer.
  /// [currency] Devise de transaction (ex: 'XAF').
  /// [email] Adresse e-mail du payeur.
  /// [phone] Numéro de téléphone du payeur.
  /// [missionId] Identifiant de la mission liée.
  /// [description] Motif de facturation.
  /// [callbackUrl] URL de retour optionnelle après paiement.
  /// Retourne un dictionnaire contenant les détails de la transaction et la clé `_payment_url`.
  static Future<Map<String, dynamic>> initializePayment({
    required double amount,
    required String currency,
    required String email,
    required String phone,
    required String missionId,
    required String description,
    String? callbackUrl,
  }) async {
    try {
      final body = {
        'amount': amount.toStringAsFixed(0),
        'currency': currency,
        'email': email,
        'phone': phone,
        'reference': 'mission_${missionId}_${DateTime.now().millisecondsSinceEpoch}',
        'description': description,
        'callback': callbackUrl ??
            '${NotchPayConfig.backendUrl}/notchpay/callback',
        'metadata': {
          'mission_id': missionId,
        },
      };

      final response = await _apiService.post(
        '$_baseUrl/payments/initialize',
        body,
        options: Options(
          headers: {
            'Authorization': NotchPayConfig.publicKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final data = response;

      // ✅ Chercher l'URL dans toutes les structures possibles
      final url = data['authorization']?['url'] as String? ??
          data['data']?['authorization']?['url'] as String? ??
          data['transaction']?['authorization_url'] as String? ??
          data['authorization_url'] as String? ??
          data['payment_url'] as String? ??
          data['url'] as String?;

      if (url == null) {
        throw Exception('URL de paiement non reçue. Réponse: $data');
      }

      // Retourner avec l'URL normalisée
      return {...data, '_payment_url': url};
    } catch (e) {
      throw Exception('Erreur initialisation paiement: $e');
    }
  }

  /// Interroge l'API NotchPay pour vérifier le statut effectif d'un paiement.
  ///
  /// [reference] Référence unique de la transaction générée lors de l'initialisation.
  /// Retourne les informations complètes sur le statut de la transaction.
  static Future<Map<String, dynamic>> verifyPayment(
      String reference) async {
    try {
      final response = await _apiService.get(
        '$_baseUrl/payments/$reference',
        options: Options(
          headers: {
            'Authorization': NotchPayConfig.publicKey,
            'Accept': 'application/json',
          },
        ),
      );

      return response;
    } catch (e) {
      throw Exception('Erreur vérification: $e');
    }
  }
}
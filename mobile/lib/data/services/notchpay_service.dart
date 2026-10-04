import 'package:dio/dio.dart';
import '../constants/notchpay_config.dart';
import 'api_service.dart';

class NotchPayService {
  static const String _baseUrl = 'https://api.notchpay.co';
  static final ApiService _apiService = ApiService();

  // Initialiser un paiement
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

  // Vérifier le statut d'un paiement
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
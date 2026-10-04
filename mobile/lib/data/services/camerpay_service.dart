import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import '../../core/utils/app_error_handler.dart';

class CamerPayService {
  static const String paymentTypeMission = 'mission';
  static const String paymentTypeSubscription = 'subscription';

  static const double monthlyPrice = 2000.0; // Prix par mois
  static const double yearlyPrice = 20000.0; // Prix par an
  static const int trialDays = 30;           // Période d'essai gratuite en jours

  final SupabaseClient supabase;
  final ApiService _apiService;

  CamerPayService({
    SupabaseClient? supabaseClient,
    ApiService? apiService,
  })  : supabase = supabaseClient ?? Supabase.instance.client,
        _apiService = apiService ?? ApiService();

  // =========================================================================
  // 1. PAIEMENT DES MISSIONS (Client -> Technicien)
  // =========================================================================
  
  Future<Map<String, dynamic>> initializeMissionPayment({
    required String missionId,
    required double amount,
    required String clientId,
    required String clientPhone,
    required String clientEmail,
    required String description,
  }) async {
    try {
      // Si le montant est supérieur à 20 FCFA, prélever 20 FCFA
      final chargeAmount = amount > 20 ? 20 : amount.toInt();

      final response = await _apiService.post('/payments/initialize', {
        'missionId': missionId,
        'amount': chargeAmount,
        'clientId': clientId,
        'clientPhone': clientPhone,
        'clientEmail': clientEmail,
        'description': description,
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      } else {
        return {
          'success': false,
          'error': AppErrorHandler.parse(response['error'] ?? 'Échec de l\'initialisation du paiement'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': AppErrorHandler.parse(e),
      };
    }
  }

  // =========================================================================
  // 2. ABONNEMENTS DES TECHNICIENS
  // =========================================================================

  Future<Map<String, dynamic>> initializeSubscriptionPayment({
    required String technicianId,
    required String subscriptionType,
    required String technicianName,
    required String technicianPhone,
    required String technicianEmail,
  }) async {
    try {
      final response = await _apiService.post('/subscriptions/initialize', {
        'technicianId': technicianId,
        'subscriptionType': subscriptionType,
        'technicianData': {
          'name': technicianName,
          'phone': technicianPhone,
          'email': technicianEmail,
        },
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to initialize subscription',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // =========================================================================
  // 3. VÉRIFICATION DES TRANSACTIONS
  // =========================================================================

  Future<Map<String, dynamic>> verifyTransaction({
    required String reference,
    required String type, // 'mission' ou 'subscription'
  }) async {
    try {
      final endpoint = type == 'mission'
          ? '/payments/verify/$reference'
          : '/subscriptions/verify/$reference';

      final response = await _apiService.post(endpoint, {});

      if (response['success'] == true) {
        return {
          'success': true,
          'status': response['data']['status'],
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Payment verification failed',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus({
    required String technicianId,
  }) async {
    try {
      final response = await _apiService.get('/subscriptions/status/$technicianId');

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to get subscription status',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> startFreeTrial({
    required String technicianId,
  }) async {
    try {
      final response = await _apiService.post('/subscriptions/start-trial', {
        'technicianId': technicianId
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to start trial',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> renewSubscription({
    required String technicianId,
    required String technicianName,
    required String technicianPhone,
    required String technicianEmail,
  }) async {
    try {
      final response = await _apiService.post('/subscriptions/renew/$technicianId', {
        'technicianData': {
          'name': technicianName,
          'phone': technicianPhone,
          'email': technicianEmail,
        },
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to renew subscription',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> cancelSubscription({
    required String technicianId,
  }) async {
    try {
      final response = await _apiService.post('/subscriptions/cancel/$technicianId', {});

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to cancel subscription',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // =========================================================================
  // 4. PAIEMENTS MANUELS (De Main à Main ou P2P)
  // =========================================================================

  Future<Map<String, dynamic>> initializeManualPayment({
    required String missionId,
    required double amount,
    required String clientId,
    required String method,
    required String senderPhone,
  }) async {
    try {
      final response = await _apiService.post('/payments/manual/initialize', {
        'missionId': missionId,
        'amount': amount.toInt(),
        'clientId': clientId,
        'method': method,
        'senderPhone': senderPhone,
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to initialize manual payment',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> confirmManualPayment({
    required String missionId,
  }) async {
    try {
      final response = await _apiService.post('/payments/manual/confirm', {
        'missionId': missionId,
      });

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to confirm manual payment',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

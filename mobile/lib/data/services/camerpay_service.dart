// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : camerpay_service.dart
// Rôle          : Service de gestion des paiements Mobile Money (Orange Money, MTN MoMo) et abonnements.
// Module        : Data / Services
// Dépendances   : supabase_flutter, api_service.dart, app_error_handler.dart
// Sécurité/RLS  : Opérations financières acheminées via l'API sécurisée du backend.
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import '../../core/utils/app_error_handler.dart';

/// Service gérant l'orchestration des flux financiers dans l'application.
///
/// Prend en charge deux grands types de transactions :
/// 1. Le règlement des missions d'intervention technique par les clients.
/// 2. La souscription, le renouvellement et l'essai gratuit des abonnements pour les techniciens.
/// Inclut également la gestion des paiements manuels directs (espèces ou transfert direct).
class CamerPayService {
  /// Identifiant du type de paiement pour les interventions/missions.
  static const String paymentTypeMission = 'mission';

  /// Identifiant du type de paiement pour les abonnements techniciens.
  static const String paymentTypeSubscription = 'subscription';

  /// Tarif de l'abonnement mensuel pour technicien en Francs CFA (2 000 XAF).
  static const double monthlyPrice = 2000.0;

  /// Tarif de l'abonnement annuel pour technicien en Francs CFA (20 000 XAF).
  static const double yearlyPrice = 20000.0;

  /// Durée de la période d'essai gratuit accordée aux nouveaux techniciens (30 jours).
  static const int trialDays = 30;

  /// Client Supabase pour les opérations directes si nécessaire.
  final SupabaseClient supabase;

  /// Client API HTTP utilisé pour interagir avec le backend TechLink.
  final ApiService _apiService;

  /// Constructeur injectant les instances de client Supabase et d'API HTTP.
  CamerPayService({
    SupabaseClient? supabaseClient,
    ApiService? apiService,
  })  : supabase = supabaseClient ?? Supabase.instance.client,
        _apiService = apiService ?? ApiService();

  // =========================================================================
  // 1. PAIEMENT DES MISSIONS (Client -> Technicien)
  // =========================================================================
  
  /// Initialise une transaction de paiement pour une mission spécifique.
  ///
  /// [missionId] Identifiant unique de la mission.
  /// [amount] Montant total de la prestation.
  /// [clientId] Identifiant unique du client payeur.
  /// [clientPhone] Numéro de téléphone Mobile Money du client.
  /// [clientEmail] Adresse e-mail du client pour le reçu.
  /// [description] Description du motif de paiement.
  /// Retourne un dictionnaire avec le statut de l'opération et l'URL de paiement ou la référence.
  Future<Map<String, dynamic>> initializeMissionPayment({
    required String missionId,
    required double amount,
    required String clientId,
    required String clientPhone,
    required String clientEmail,
    required String description,
  }) async {
    try {
      // Si le montant est supérieur à 20 FCFA, prélever 20 FCFA (seuil de test)
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

  /// Initialise le règlement d'un forfait d'abonnement pour un technicien.
  ///
  /// [technicianId] Identifiant unique du technicien.
  /// [subscriptionType] Type de forfait ('monthly' ou 'yearly').
  /// [technicianName] Nom complet du technicien.
  /// [technicianPhone] Numéro Mobile Money utilisé pour le prélèvement.
  /// [technicianEmail] Adresse e-mail de facturation.
  /// Retourne les données d'initialisation de paiement transmises par le backend.
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

  /// Vérifie le statut d'une transaction auprès de la passerelle de paiement.
  ///
  /// [reference] Numéro de référence unique de la transaction.
  /// [type] Nature du paiement ('mission' ou 'subscription').
  /// Retourne l'état courant de la transaction ('pending', 'successful', 'failed').
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

  /// Récupère l'état d'abonnement actif d'un technicien.
  ///
  /// [technicianId] Identifiant unique du technicien.
  /// Retourne le statut, la date d'expiration et la validité du forfait.
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

  /// Active la période d'essai gratuit de 30 jours pour un nouveau technicien validé.
  ///
  /// [technicianId] Identifiant unique du technicien.
  /// Retourne le résultat d'activation avec la nouvelle date limite d'essai.
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

  /// Initie le renouvellement d'un abonnement expiré pour un technicien.
  ///
  /// [technicianId] Identifiant du technicien.
  /// [technicianName] Nom complet.
  /// [technicianPhone] Numéro de téléphone.
  /// [technicianEmail] Adresse e-mail.
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

  /// Résilie ou annule l'abonnement automatique en cours d'un technicien.
  ///
  /// [technicianId] Identifiant unique du technicien.
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

  /// Déclare l'initialisation d'un paiement manuel direct (espèces ou transfert P2P).
  ///
  /// [missionId] Identifiant de la mission concernée.
  /// [amount] Montant en Francs CFA versé.
  /// [clientId] Identifiant du client.
  /// [method] Méthode utilisée (ex: 'cash', 'direct_transfer').
  /// [senderPhone] Numéro de l'émetteur pour vérification.
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

  /// Valide et confirme la bonne réception d'un paiement manuel par le technicien.
  ///
  /// [missionId] Identifiant unique de la mission réglée.
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

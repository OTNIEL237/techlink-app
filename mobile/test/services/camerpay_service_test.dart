// =============================================================================
// FICHIER : camerpay_service_test.dart
// RÔLE : Tests unitaires pour le service de paiement CamerPayService
//         (initialisation des paiements de mission, règle de test à 20 FCFA,
//         démarrage d'essai gratuit technicien, vérification des transactions d'abonnement).
// MODULE : Tests / Services Paiements (Mobile Flutter)
// DÉPENDANCES : package:flutter_test/flutter_test.dart, package:mocktail/mocktail.dart, package:techlink/data/services/camerpay_service.dart
// SÉCURITÉ / RLS : N/A (Tests unitaires avec isolation ApiService mocké)
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:techlink/data/services/api_service.dart';
import 'package:techlink/data/services/camerpay_service.dart';

/// Mock du service client HTTP ApiService.
class MockApiService extends Mock implements ApiService {}

/// Mock du client SupabaseClient.
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Point d'entrée de la suite de tests unitaires pour CamerPayService.
void main() {
  late CamerPayService camerPayService;
  late MockApiService mockApiService;
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockApiService = MockApiService();
    mockSupabaseClient = MockSupabaseClient();
    
    camerPayService = CamerPayService(
      apiService: mockApiService,
      supabaseClient: mockSupabaseClient,
    );
  });

  group('CamerPayService - Mission Payments', () {
    test('devrait initialiser un paiement de mission avec succès', () async {
      final mockResponse = {
        'success': true,
        'data': {
          'paymentUrl': 'https://pay.camerpay.com/123',
          'transactionId': 'txn_123'
        }
      };

      when(() => mockApiService.post('/payments/initialize', any()))
          .thenAnswer((_) async => mockResponse);

      final result = await camerPayService.initializeMissionPayment(
        missionId: 'm1',
        amount: 5000,
        clientId: 'c1',
        clientPhone: '600000000',
        clientEmail: 'client@test.com',
        description: 'Test Mission'
      );

      expect(result['success'], isTrue);
      expect(result['data']['paymentUrl'], 'https://pay.camerpay.com/123');
      
      verify(() => mockApiService.post('/payments/initialize', {
        'missionId': 'm1',
        'amount': 20,
        'clientId': 'c1',
        'clientPhone': '600000000',
        'clientEmail': 'client@test.com',
        'description': 'Test Mission'
      })).called(1);
    });

    test('devrait retourner une erreur si initialisation échoue', () async {
      when(() => mockApiService.post('/payments/initialize', any()))
          .thenAnswer((_) async => {'success': false, 'error': 'Solde insuffisant'});

      final result = await camerPayService.initializeMissionPayment(
        missionId: 'm1',
        amount: 5000,
        clientId: 'c1',
        clientPhone: '600000000',
        clientEmail: 'client@test.com',
        description: 'Test Mission'
      );

      expect(result['success'], isFalse);
      expect(result['error'], 'Solde insuffisant');
    });
  });

  group('CamerPayService - Subscriptions', () {
    test('devrait démarrer une période d\'essai avec succès', () async {
      when(() => mockApiService.post('/subscriptions/start-trial', any()))
          .thenAnswer((_) async => {
                'success': true,
                'data': {'trial_days_remaining': 30}
              });

      final result = await camerPayService.startFreeTrial(technicianId: 't1');

      expect(result['success'], isTrue);
      expect(result['data']['trial_days_remaining'], 30);
    });

    test('devrait vérifier une transaction', () async {
      when(() => mockApiService.post('/subscriptions/verify/ref123', any()))
          .thenAnswer((_) async => {
                'success': true,
                'data': {'status': 'active'}
              });

      final result = await camerPayService.verifyTransaction(reference: 'ref123', type: 'subscription');

      expect(result['success'], isTrue);
      expect(result['status'], 'active');
    });
  });
}

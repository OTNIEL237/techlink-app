// =============================================================================
// FICHIER : admin_mission_detail_screen_test.dart
// RÔLE : Tests de widgets Flutter pour l'écran AdminMissionDetailScreen
//         (rendu des détails de mission, informations client/technicien,
//         catégorie et description de la panne).
// MODULE : Tests / Widgets Administrateur (Mobile Flutter)
// DÉPENDANCES : package:flutter_test/flutter_test.dart, package:techlink/presentation/admin/admin_mission_detail_screen.dart
// SÉCURITÉ / RLS : N/A (Test de rendu de widget isolé)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/presentation/admin/admin_mission_detail_screen.dart';
import 'package:techlink/core/theme/theme_provider.dart';
import 'package:techlink/core/constants/app_colors.dart';

/// Point d'entrée des tests de widget pour l'écran de détail de mission administrateur.
void main() {
  testWidgets('AdminMissionDetailScreen affiche les détails de la mission', (WidgetTester tester) async {
    final mockMission = {
      'id': 'm123',
      'status': 'pending',
      'clients': {'name': 'Jean Dupont'},
      'technicians': {'name': 'Paul Bricoleur'},
      'categories': {'name': 'Plomberie'},
      'problem_description': 'Fuite d\'eau sous l\'évier',
      'client_address': '123 Rue de Paris',
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            TechLinkColors.light,
          ],
        ),
        home: AdminMissionDetailScreen(mission: mockMission),
      ),
    );

    // Vérifier l'affichage de l'app bar
    expect(find.text('Détails de la mission'), findsOneWidget);

    // Vérifier l'affichage des informations client et technicien
    expect(find.text('Jean Dupont'), findsWidgets);
    expect(find.text('Paul Bricoleur'), findsOneWidget);
    expect(find.text('Plomberie'), findsOneWidget);

    // Vérifier l'affichage de la description du problème
    expect(find.text('Fuite d\'eau sous l\'évier'), findsOneWidget);
  });
}

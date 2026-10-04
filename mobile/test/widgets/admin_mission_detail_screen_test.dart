import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/presentation/admin/admin_mission_detail_screen.dart';
import 'package:techlink/core/theme/theme_provider.dart';
import 'package:techlink/core/constants/app_colors.dart';

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

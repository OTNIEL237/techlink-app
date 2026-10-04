import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/presentation/client/widgets/home_search_bar.dart';
import 'package:techlink/core/theme/theme_provider.dart';
import 'package:techlink/core/constants/app_colors.dart';

void main() {
  testWidgets('ClientHomeSearchBar devrait s\'afficher correctement', (WidgetTester tester) async {
    // Fournir le thème requis par le widget
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            TechLinkColors.light,
          ],
        ),
        home: const Scaffold(
          body: ClientHomeSearchBar(),
        ),
      ),
    );

    // Vérifie que le champ de texte est présent
    expect(find.byType(TextField), findsOneWidget);

    // Vérifie que l'icône de recherche est présente
    expect(find.byIcon(Icons.search), findsOneWidget);

    // Vérifie que l'icône de filtre (tune) est présente
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });
}

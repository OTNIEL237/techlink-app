import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/presentation/auth/login_screen.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('devrait afficher les champs email et mot de passe', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify that the email and password text fields are present
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsWidgets);
    });

    testWidgets('devrait afficher le bouton de connexion', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify that the login button is present
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('devrait masquer le mot de passe par défaut et l\'afficher au clic', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Find the password field (the second text field)
      final passwordFieldFinder = find.byType(TextField).last;
      
      // Initially, obscureText should be true
      TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isTrue);

      // Tap the visibility icon
      final visibilityIconFinder = find.byIcon(Icons.visibility);
      if (visibilityIconFinder.evaluate().isNotEmpty) {
        await tester.tap(visibilityIconFinder);
        await tester.pumpAndSettle();

        // After tap, obscureText should be false
        passwordField = tester.widget<TextField>(passwordFieldFinder);
        expect(passwordField.obscureText, isFalse);
      }
    });
  });
}

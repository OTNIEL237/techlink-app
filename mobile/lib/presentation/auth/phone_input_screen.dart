// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : phone_input_screen.dart
// Rôle          : Point d'entrée de la route /phone redirigeant vers l'écran d'authentification unifié.
// Module        : Presentation / Auth
// Dépendances   : flutter, login_screen.dart
// Sécurité/RLS  : Accès public (redirection vers LoginScreen).
// =============================================================================

import 'package:flutter/material.dart';
import 'login_screen.dart';

/// Écran proxy redirigeant vers l'interface de connexion unifiée [LoginScreen].
///
/// Conserve la rétrocompatibilité avec la route historique `/phone` tout en fournissant
/// l'expérience de connexion moderne (Email/Mot de passe et OTP SMS).
class PhoneInputScreen extends StatelessWidget {
  /// Constructeur constant pour [PhoneInputScreen].
  const PhoneInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
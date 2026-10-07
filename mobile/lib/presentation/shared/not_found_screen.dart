// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : not_found_screen.dart
// Rôle          : Écran d'erreur 404 (Route inconnue ou ressource introuvable).
// Module        : Presentation / Shared
// Dépendances   : flutter, go_router, app_colors.dart, theme_provider.dart
// Sécurité/RLS  : Écran public d'interception d'URL invalide avec retour sécurisé vers l'accueil.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';

/// Écran d'erreur 404 affiché lorsqu'une route demandée n'existe pas ou a été déplacée.
///
/// Présente une interface bienveillante invitant l'utilisateur à retourner
/// à la racine de l'application via [context.go('/')] pour réévaluer son orientation.
class NotFoundScreen extends StatelessWidget {
  /// Constructeur constant pour [NotFoundScreen].
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icone d'erreur avec style premium
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  size: 80,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 32),
              
              // Texte 404
              Text(
                '404',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: tc.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Oups ! Cette page est introuvable.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "La page que vous recherchez n'existe pas ou a été déplacée.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: tc.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              
              // Bouton retour
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/'); // Retour au splash pour redirection intelligente
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Retour à l\'accueil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

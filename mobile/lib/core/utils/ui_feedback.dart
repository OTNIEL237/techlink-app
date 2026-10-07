// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : ui_feedback.dart
// Rôle          : Système unifié de retours visuels (SnackBars modernes,
//                 messages de succès, alertes d'avertissement et toasts).
// Module        : Core / Utilitaires & Expérience Utilisateur
// Dépendances   : Flutter Material, AppColors, AppErrorHandler
// Sécurité/RLS  : Public / UI
// =============================================================================

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_error_handler.dart';

/// [UiFeedback]
///
/// Système unifié d'affichage des messages et erreurs (Snackbars flottantes compactes).
/// Garantit des messages en français, précis, élégants, et qui ne recouvrent JAMAIS l'application.
class UiFeedback {
  /// Affiche une notification d'erreur compacte et précise en français.
  static void showError(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = customMessage ?? AppErrorHandler.parse(error);
    _showSnackBar(
      context,
      message: message,
      title: 'Erreur',
      accentColor: AppColors.error,
      icon: Icons.error_outline_rounded,
      duration: duration,
    );
  }

  /// Affiche une notification de succès compacte.
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title = 'Succès',
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      accentColor: AppColors.success,
      icon: Icons.check_circle_outline_rounded,
      duration: duration,
    );
  }

  /// Affiche une notification d'avertissement compacte.
  static void showWarning(
    BuildContext context,
    String message, {
    String? title = 'Attention',
    Duration duration = const Duration(seconds: 4),
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      accentColor: AppColors.warning,
      icon: Icons.warning_amber_rounded,
      duration: duration,
    );
  }

  /// Affiche une notification d'information compacte.
  static void showInfo(
    BuildContext context,
    String message, {
    String? title = 'Information',
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      title: title,
      accentColor: AppColors.primary,
      icon: Icons.info_outline_rounded,
      duration: duration,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    String? title,
    required Color accentColor,
    required IconData icon,
    required Duration duration,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Nettoie les anciens messages pour éviter les empilements
    messenger.clearSnackBars();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final snackBar = SnackBar(
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent, // Fond géré par le Container
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge icône circulaire
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Contenu texte (limité à 2 lignes pour ne jamais envahir l'écran)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Bouton de fermeture rapide
            GestureDetector(
              onTap: () => messenger.hideCurrentSnackBar(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    messenger.showSnackBar(snackBar);
  }
}

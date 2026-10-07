// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : techlink_card.dart
// Rôle          : Conteneur carte élégant et moderne avec coins arrondis et ombre douce.
// Module        : Presentation / Shared / Widgets
// Dépendances   : flutter
// Sécurité/RLS  : Composant UI stateless générique.
// =============================================================================

import 'package:flutter/material.dart';

/// Carte visuelle unifiée utilisée pour regrouper les informations dans l'application.
///
/// Intègre :
/// - Une bordure discrète et des ombres douces adaptées au thème clair/sombre.
/// - Des coins arrondis prononcés (rayon de 24).
/// - Un effet d'ondulation tactile ([InkWell]) si une action [onTap] est fournie.
class TechLinkCard extends StatelessWidget {
  /// Widget enfant enveloppé à l'intérieur de la carte.
  final Widget child;

  /// Marges internes de la carte (20 par défaut si non spécifié).
  final EdgeInsetsGeometry? padding;

  /// Fonction de rappel facultative activant l'interactivité au toucher.
  final VoidCallback? onTap;

  /// Couleur de fond personnalisée (utilise la couleur du thème par défaut).
  final Color? color;

  /// Constructeur de [TechLinkCard].
  const TechLinkCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget cardContent = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.04 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: cardContent,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: cardContent,
    );
  }
}

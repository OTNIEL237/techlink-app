// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : responsive_web_wrapper.dart
// Rôle          : Conteneur adaptatif centrant et limitant la largeur d'affichage sur écrans larges (Web/Desktop).
// Module        : Presentation / Shared
// Dépendances   : flutter
// Sécurité/RLS  : Composant UI stateless générique.
// =============================================================================

import 'package:flutter/material.dart';

/// Conteneur adaptatif préservant un ratio visuel équilibré sur navigateurs Web et ordinateurs.
///
/// Lorsque la largeur d'écran dépasse [maxWidth] (800px par défaut), le contenu
/// est automatiquement centré avec des ombres subtiles et une bordure périphérique,
/// évitant l'étirement excessif des formulaires mobiles sur les grands moniteurs.
class ResponsiveWebWrapper extends StatelessWidget {
  /// Widget enfant à afficher à l'intérieur du conteneur.
  final Widget child;

  /// Largeur maximale allouée au contenu (par défaut 800 pixels).
  final double maxWidth;

  /// Constructeur de [ResponsiveWebWrapper].
  const ResponsiveWebWrapper({
    super.key,
    required this.child,
    this.maxWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: MediaQuery.of(context).size.width > maxWidth
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
          border: MediaQuery.of(context).size.width > maxWidth
              ? Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}

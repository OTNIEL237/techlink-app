// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : techlink_button.dart
// Rôle          : Bouton standard réutilisable (supporte styles plein, contour, icône et indicateur de chargement).
// Module        : Presentation / Shared / Widgets
// Dépendances   : flutter
// Sécurité/RLS  : Composant UI stateless générique.
// =============================================================================

import 'package:flutter/material.dart';

/// Composant bouton principal de l'application TechLink.
///
/// Encapsule le design system pour les actions interactives :
/// - Supporte les variantes pleines ([ElevatedButton]) et contour ([OutlinedButton]).
/// - Affiche un indicateur circulaire de chargement lorsque [isLoading] est vrai.
/// - Permet l'ajout d'une icône indicative à gauche du texte.
class TechLinkButton extends StatelessWidget {
  /// Libellé affiché sur le bouton.
  final String text;

  /// Fonction de rappel déclenchée au clic (désactivée si nul ou si [isLoading] est vrai).
  final VoidCallback? onPressed;

  /// Indique si une opération asynchrone est en cours d'exécution.
  final bool isLoading;

  /// Si vrai, applique un style avec bordure et fond transparent.
  final bool isOutlined;

  /// Icône optionnelle positionnée avant le libellé textuel.
  final IconData? icon;

  /// Couleur d'accentuation personnalisée pour le fond ou la bordure.
  final Color? color;

  /// Constructeur de [TechLinkButton].
  const TechLinkButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? Theme.of(context).primaryColor,
          side: BorderSide(
            color: color ?? Theme.of(context).primaryColor,
            width: 1.5,
          ),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _buildChild(isOutlined: true, context: context),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: color != null
          ? ElevatedButton.styleFrom(backgroundColor: color)
          : null,
      child: _buildChild(isOutlined: false, context: context),
    );
  }

  /// Construit le contenu interne du bouton (indicateur de chargement, icône + texte, ou texte seul).
  Widget _buildChild({required bool isOutlined, required BuildContext context}) {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: isOutlined ? (color ?? Theme.of(context).primaryColor) : Colors.white,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}

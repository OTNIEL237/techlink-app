// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : techlink_input.dart
// Rôle          : Champ de saisie de formulaire standardisé avec libellé, icônes et validation.
// Module        : Presentation / Shared / Widgets
// Dépendances   : flutter
// Sécurité/RLS  : Composant UI stateless générique.
// =============================================================================

import 'package:flutter/material.dart';

/// Champ de saisie stylisé pour l'ensemble des formulaires de l'application.
///
/// Intègre de manière cohérente :
/// - Un libellé typographié au-dessus du champ.
/// - Un support pour les mots de passe masqués ([isPassword]).
/// - La personnalisation des icônes préfixe et suffixe.
/// - La validation standard [validator] de Flutter.
class TechLinkInput extends StatelessWidget {
  /// Titre ou libellé textuel affiché au-dessus du champ.
  final String label;

  /// Texte d'indication (placeholder) affiché lorsque le champ est vide.
  final String? hint;

  /// Contrôleur gérant la valeur textuelle du champ.
  final TextEditingController? controller;

  /// Type de clavier virtuel (texte, email, téléphone, etc.).
  final TextInputType keyboardType;

  /// Si vrai, masque la saisie des caractères pour les mots de passe.
  final bool isPassword;

  /// Icône préfixe optionnelle affichée à gauche dans le champ.
  final IconData? prefixIcon;

  /// Widget suffixe optionnel (ex: bouton œil pour démasquer le mot de passe).
  final Widget? suffixIcon;

  /// Fonction de validation renvoyant un message d'erreur ou `null`.
  final String? Function(String?)? validator;

  /// Fonction de rappel invoquée à chaque modification du texte.
  final void Function(String)? onChanged;

  /// Fonction de rappel invoquée au toucher du champ.
  final void Function()? onTap;

  /// Nombre maximal de lignes visibles (par défaut 1).
  final int maxLines;

  /// Empêche la saisie directe au clavier tout en conservant l'interactivité au toucher.
  final bool readOnly;

  /// Constructeur de [TechLinkInput].
  const TechLinkInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            obscureText: isPassword,
            maxLines: isPassword ? 1 : maxLines,
            validator: validator,
            onChanged: onChanged,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 22) : null,
              suffixIcon: suffixIcon,
            ),
          ),
        ],
      ),
    );
  }
}

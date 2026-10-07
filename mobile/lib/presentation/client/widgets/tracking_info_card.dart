// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : tracking_info_card.dart
// Rôle          : Carte générique réutilisable pour regrouper des informations
//                 de suivi de mission avec icône, titre et contenu personnalisé.
// Module        : Présentation Client (Widgets Suivi de Mission)
// Dépendances   : flutter/material.dart, app_colors.dart
// Sécurité/RLS  : Composant d'affichage sans restriction d'accès.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Carte conteneur d'informations pour les écrans de suivi de mission.
class TrackingInfoCard extends StatelessWidget {
  /// Titre de la section informative
  final String title;

  /// Icône illustrative affichée à côté du titre
  final IconData icon;

  /// Widget enfant contenant le corps de l'information
  final Widget child;

  /// Constructeur constant de la carte d'information de suivi
  const TrackingInfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: tc.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: tc.border),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

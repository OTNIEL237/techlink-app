// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : tracking_status_card.dart
// Rôle          : Carte affichant le statut actuel de la mission avec icône d'état
//                 et frise chronologique (timeline) dynamique à 5 étapes.
// Module        : Présentation Client (Widgets Suivi de Mission)
// Dépendances   : flutter/material.dart, app_localizations.dart, app_colors.dart
// Sécurité/RLS  : Widget de présentation client sans restriction d'accès.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:techlink/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';

/// Carte présentant l'état d'avancement actuel de la mission et sa chronologie étape par étape.
class TrackingStatusCard extends StatelessWidget {
  /// Code textuel du statut de la mission (ex: 'accepted', 'in_progress', 'completed')
  final String status;

  /// Constructeur constant de la carte de statut de suivi
  const TrackingStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // Définition des 5 étapes séquentielles de la mission
    final steps = [
      ('Acceptée', 'accepted', Icons.check_circle_outline),
      ('En route', 'technician_enroute', Icons.directions_car_outlined),
      ('En cours', 'in_progress', Icons.build_outlined),
      ('Devis', 'quote_sent', Icons.receipt_outlined),
      ('Terminée', 'completed', Icons.verified_outlined),
    ];

    // Dictionnaire des libellés, couleurs et icônes pour chaque statut possible
    final statusLabels = {
      'searching': ('Recherche technicien...', AppColors.warning, Icons.search),
      'accepted': ('Technicien assigné !', AppColors.primary, Icons.check_circle),
      'technician_enroute': ('Technicien en route 🚗', AppColors.warning, Icons.directions_car),
      'in_progress': ('Intervention en cours 🔧', AppColors.technicianColor, Icons.build),
      'quote_sent': ('Devis reçu — Action requise !', AppColors.warning, Icons.receipt_long),
      'quote_accepted': ('Devis accepté ✓', AppColors.success, Icons.thumb_up),
      'paid': ('Paiement reçu', AppColors.success, Icons.payment),
      'completed': ('Mission terminée ✅', AppColors.success, Icons.verified),
      'cancelled': ('Mission annulée', AppColors.error, Icons.cancel),
      'in_dispute': ('MISSION GELÉE (LITIGE) 🛑', AppColors.error, Icons.gavel),
      'cancelled_refunded': ('Mission annulée et remboursée', Colors.grey, Icons.money_off),
    };

    final info = statusLabels[status] ??
        ('Statut inconnu', tc.textSecondary, Icons.info_outline);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: info.$2.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(info.$3, color: info.$2, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n?.missionStatus ?? 'Statut de la mission',
                      style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(info.$1,
                      style: TextStyle(
                        color: info.$2,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),

          // ================== CHRONOLOGIE (TIMELINE) ==================
          if (status != 'searching' && status != 'cancelled') ...[
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;

                final stepMapping = {
                  'accepted': 0,
                  'technician_enroute': 1,
                  'in_progress': 2,
                  'quote_sent': 3,
                  'quote_accepted': 3,
                  'paid': 4,
                  'completed': 5,
                };
                final stepIndex = stepMapping[status] ?? 0;
                final isDone = i < stepIndex;
                final isCurrent = i == stepIndex;

                return Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Semantics(
                          label: 'Étape de la mission : ${step.$1}. ${isDone ? "Terminée" : isCurrent ? "En cours" : "À venir"}',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? AppColors.success
                                      : isCurrent
                                          ? AppColors.primary
                                          : tc.border.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  border: isCurrent
                                      ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 3)
                                      : null,
                                ),
                                child: Center(
                                  child: isDone
                                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                                      : isCurrent
                                          ? Icon(step.$3, color: Colors.white, size: 13)
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  step.$1,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isCurrent
                                        ? AppColors.primary
                                        : isDone
                                            ? tc.textPrimary
                                            : tc.textSecondary,
                                    fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            height: 2,
                            color: isDone ? AppColors.success : tc.border.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// FICHIER : pending_validation_screen.dart
// RÔLE : Écran de mise en attente et suivi de validation du compte technicien (KYC)
// MODULE : Presentation / Technician
// DÉPENDANCES : flutter/material.dart, go_router, supabase_flutter, app_colors.dart, app_router.dart, responsive_web_wrapper.dart
// SÉCURITÉ / RLS : Rôle technicien en cours de revue ('pending' ou 'rejected'). Polling sécurisé de 'technicians.validation_status'.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../shared/responsive_web_wrapper.dart';

/// Écran d'attente informant le technicien de l'état d'instruction de son dossier.
///
/// Affiche la progression administrative (vérification KYC, examen des diplômes),
/// vérifie périodiquement si l'administrateur a validé le compte et redirige automatiquement
/// vers l'accueil technicien dès approbation (`validation_status == 'approved'`).
class PendingValidationScreen extends StatefulWidget {
  /// Constructeur constant du widget [PendingValidationScreen].
  const PendingValidationScreen({super.key});

  @override
  State<PendingValidationScreen> createState() =>
      _PendingValidationScreenState();
}

/// État associé à l'écran d'attente de validation technicien.
///
/// Gère la boucle de vérification périodique (polling toutes les 30s)
/// et met à jour l'interface en cas d'approbation ou de rejet du dossier.
class _PendingValidationScreenState extends State<PendingValidationScreen> {
  /// Statut de validation courant de l'artisan ('pending', 'approved', 'rejected').
  String _validationStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Vérifier toutes les 30 secondes tant que le statut reste en attente
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      await _checkStatus();
      return _validationStatus == 'pending';
    });
  }

  /// Interroge Supabase pour récupérer le statut d'approbation actuel de l'utilisateur.
  ///
  /// Met en cache le rôle validé via [AppRouter.setCachedRole] et redirige vers `/technician/home`
  /// dès que le profil est marqué comme `approved`.
  Future<void> _checkStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('technicians')
          .select('validation_status')
          .eq('user_id', userId)
          .single();

      final status = data['validation_status'] as String;
      if (mounted) setState(() => _validationStatus = status);

      if (status == 'approved' && mounted) {
        AppRouter.setCachedRole(userId, 'technician', validationStatus: 'approved');
        context.go('/technician/home');
      }
    } catch (_) {}
  }

  /// Construit la vue avec indicateur d'état, étapes de validation et options de déconnexion.
  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: ResponsiveWebWrapper(
          child: Padding(
            padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône animée
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _validationStatus == 'rejected'
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _validationStatus == 'rejected'
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  size: 72,
                  color: _validationStatus == 'rejected'
                      ? AppColors.error
                      : AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                _validationStatus == 'rejected'
                    ? 'Demande rejetée'
                    : 'Validation en cours...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _validationStatus == 'rejected'
                    ? 'Votre demande a été rejetée. Veuillez mettre à jour vos documents et soumettre à nouveau.'
                    : 'Votre profil est en cours de vérification par notre équipe. Vous serez notifié une fois la validation effectuée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tc.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              if (_validationStatus == 'pending') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 10),
                          const Text('Compte créé',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.pending,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 10),
                          const Text('Vérification des documents',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: tc.textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Text('Activation du compte',
                            style: TextStyle(
                                color: tc.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _checkStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Vérifier le statut'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
                ),
              ],

              if (_validationStatus == 'rejected') ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/technician/onboarding'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Mettre à jour mon profil'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
                ),
              ],

              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  AppRouter.clearRoleCache();
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: Text('Se déconnecter',
                  style: TextStyle(color: tc.textSecondary)),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
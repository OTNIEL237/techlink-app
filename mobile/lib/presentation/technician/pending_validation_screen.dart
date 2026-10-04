import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../shared/responsive_web_wrapper.dart';

// =========================================================================
// ÉCRAN D'ATTENTE DE VALIDATION
// =========================================================================
// Affiche le statut de validation du profil technicien après l'inscription,
// et vérifie périodiquement si le profil a été approuvé ou rejeté.

class PendingValidationScreen extends StatefulWidget {
  const PendingValidationScreen({super.key});

  @override
  State<PendingValidationScreen> createState() =>
      _PendingValidationScreenState();
}

class _PendingValidationScreenState extends State<PendingValidationScreen> {
  String _validationStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Vérifier toutes les 30 secondes
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      await _checkStatus();
      return _validationStatus == 'pending';
    });
  }

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
        context.go('/technician/home');
      }
    } catch (_) {}
  }

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
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/phone');
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
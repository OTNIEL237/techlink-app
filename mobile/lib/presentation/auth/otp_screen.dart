// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : otp_screen.dart
// Rôle          : Écran de saisie et vérification du code SMS (OTP) à 6 chiffres.
// Module        : Presentation / Auth
// Dépendances   : flutter, go_router, supabase_flutter, app_router.dart, responsive_web_wrapper.dart
// Sécurité/RLS  : Valide le jeton OTP via Supabase Auth et redirige selon le rôle ('client', 'technician', 'admin').
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../shared/responsive_web_wrapper.dart';

/// Écran de confirmation par code OTP (One-Time Password) reçu par SMS.
///
/// Permet à un utilisateur (client ou technicien) de finaliser son identification
/// téléphonique. Une fois le code validé, crée le compte s'il n'existe pas encore
/// et route l'utilisateur vers son tableau de bord approprié.
class OtpScreen extends StatefulWidget {
  /// Numéro de téléphone au format international (ex: +2376XXXXXXXX).
  final String phone;

  /// Rôle pré-sélectionné lors de l'inscription ('client' ou 'technician').
  final String role;

  /// Constructeur de l'écran [OtpScreen].
  const OtpScreen({super.key, required this.phone, required this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

/// État associé à l'écran [OtpScreen] gérant la validation et l'affichage.
class _OtpScreenState extends State<OtpScreen> {
  /// Contrôleur du champ de saisie du code à 6 chiffres.
  final _otpController = TextEditingController();

  /// Indicateur d'état de chargement lors de la requête de vérification.
  bool _isLoading = false;

  /// Vérifie le code OTP saisi auprès de l'API Supabase Auth.
  ///
  /// En cas de succès :
  /// 1. Synchronise la table publique `users` avec le numéro et le rôle.
  /// 2. Met à jour le cache de rôle d'[AppRouter].
  /// 3. Redirige vers `/client/home`, `/admin/home` ou le flux technicien (`/technician/onboarding`,
  ///    `/technician/pending`, `/technician/home`).
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez le code à 6 chiffres')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        // Vérifie si l'utilisateur existe déjà dans notre table users
        final existing = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        final userId = response.user!.id;
        if (existing == null) {
          // Nouvel utilisateur — créer le profil
          await Supabase.instance.client.from('users').upsert({
            'id': userId,
            'phone': widget.phone,
            'role': widget.role,
          });
        }

        final role = (existing?['role'] as String?) ?? widget.role;
        AppRouter.setCachedRole(userId, role);

        if (mounted) {
          if (role == 'client') {
            context.go('/client/home');
          } else if (role == 'admin') {
            context.go('/admin/home');
          } else if (role == 'technician') {
            try {
              final tech = await Supabase.instance.client
                  .from('technicians')
                  .select('validation_status')
                  .eq('user_id', userId)
                  .maybeSingle();
              if (!mounted) return;
              if (tech == null) {
                context.go('/technician/onboarding');
              } else {
                final status = (tech['validation_status'] as String?) ?? 'pending';
                AppRouter.setCachedRole(userId, 'technician', validationStatus: status);
                if (status == 'approved') {
                  context.go('/technician/home');
                } else {
                  context.go('/technician/pending');
                }
              }
            } catch (_) {
              if (mounted) context.go('/technician/pending');
            }
          } else {
            context.go('/client/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code incorrect: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification')),
      body: ResponsiveWebWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text('Code de vérification',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Code envoyé au ${widget.phone}',
                style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 12,
                    fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '------',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirmer'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Changer de numéro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../shared/responsive_web_wrapper.dart';

// =========================================================================
// ÉCRAN DE VÉRIFICATION OTP (SMS)
// =========================================================================
// Gère la vérification du numéro de téléphone via un code à 6 chiffres.
// (Généralement utilisé si l'authentification par téléphone Supabase est activée).

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;

  const OtpScreen({super.key, required this.phone, required this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

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

        if (existing == null) {
          // Nouvel utilisateur — créer le profil
          await Supabase.instance.client.from('users').insert({
            'id': response.user!.id,
            'phone': widget.phone,
            'role': widget.role,
          });
        }

        if (mounted) {
          final role = existing?['role'] ?? widget.role;
          if (role == 'client') {
            Navigator.pushNamedAndRemoveUntil(context, '/client/home', (r) => false);
          } else if (role == 'admin') {
            Navigator.pushNamedAndRemoveUntil(context, '/admin/home', (r) => false);
          } else {
            // Vérifier si le technicien a un profil complet
            Navigator.pushNamedAndRemoveUntil(context, '/technician/onboarding', (r) => false);
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
// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : security_screen.dart
// Rôle          : Écran de configuration de la sécurité du compte utilisateur.
//                 Permet la mise à jour du mot de passe avec validation et Supabase Auth.
// Module        : Présentation Client (Profil / Sécurité)
// Dépendances   : flutter/material.dart, go_router, supabase_flutter, app_colors.dart
// Sécurité/RLS  : Mise à jour sécurisée du mot de passe via Supabase Auth `updateUser`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';

/// Écran permettant à l'utilisateur de gérer les paramètres de sécurité de son compte.
class SecurityScreen extends StatefulWidget {
  /// Constructeur constant de l'écran de sécurité
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  /// Contrôleur de saisie pour le nouveau mot de passe
  final _passwordController = TextEditingController();

  /// Contrôleur de confirmation du nouveau mot de passe
  final _confirmPasswordController = TextEditingController();

  /// Indicateur de traitement en cours lors de la mise à jour
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Met à jour le mot de passe de l'utilisateur dans Supabase Auth après validations
  Future<void> _changePassword() async {
    if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères.')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
        ),
      );

      if (mounted) {
        context.pop(); // Ferme la boîte de dialogue
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Une erreur est survenue.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Affiche la boîte de dialogue modale pour la saisie du nouveau mot de passe
  void _showPasswordDialog(TechLinkColors tc, bool isDark) {
    _passwordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: tc.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Changer de mot de passe', style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: tc.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      labelStyle: TextStyle(color: tc.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tc.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style: TextStyle(color: tc.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirmer',
                      labelStyle: TextStyle(color: tc.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tc.border),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text('Annuler', style: TextStyle(color: tc.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setDialogState(() => _isLoading = true);
                          await _changePassword();
                          setDialogState(() => _isLoading = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Valider', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Sécurité', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
        centerTitle: true,
        backgroundColor: tc.background,
        elevation: 0,
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion du compte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tc.textSecondary),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showPasswordDialog(tc, isDark),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? tc.card : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tc.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Changer le mot de passe',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tc.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mettez à jour votre mot de passe pour sécuriser votre compte',
                            style: TextStyle(fontSize: 13, color: tc.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: tc.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

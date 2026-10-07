// =============================================================================
// FICHIER : admin_settings_screen.dart
// RÔLE : Configuration administrative des paramètres globaux de la plateforme
// MODULE : Présentation Administrateur (Admin Settings)
// DÉPENDANCES : flutter/material.dart, supabase_flutter, app_colors.dart, theme_provider.dart, techlink_button.dart, techlink_card.dart, techlink_input.dart
// SÉCURITÉ / RLS : Réservé aux administrateurs (rôle admin requis)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../shared/widgets/techlink_button.dart';
import '../shared/widgets/techlink_card.dart';
import '../shared/widgets/techlink_input.dart';

/// Écran de gestion des variables de configuration globale de la plateforme TechLink.
///
/// Permet aux administrateurs de consulter et modifier les paramètres financiers
/// tels que le pourcentage de commission prélevé et le tarif de l'abonnement mensuel.
class AdminSettingsScreen extends StatefulWidget {
  /// Constructeur par défaut de [AdminSettingsScreen].
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

/// État associé à l'écran [AdminSettingsScreen].
class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  /// Contrôleur de champ texte pour le pourcentage de commission plateforme.
  final _feeController = TextEditingController();

  /// Contrôleur de champ texte pour le prix de l'abonnement mensuel technicien.
  final _subPriceController = TextEditingController();

  /// Indicateur de chargement initial des réglages depuis Supabase.
  bool _isLoading = true;

  /// Indicateur d'enregistrement en cours des modifications.
  bool _isSaving = false;

  /// Identifiant unique de la ligne de configuration dans la table `platform_settings`.
  int? _settingsId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Charge les paramètres actuels depuis la table `platform_settings` de Supabase.
  Future<void> _loadSettings() async {
    try {
      final data = await Supabase.instance.client
          .from('platform_settings')
          .select()
          .maybeSingle();

      if (data != null && mounted) {
        _settingsId = data['id'];
        _feeController.text = data['platform_fee_percentage']?.toString() ?? '15.0';
        _subPriceController.text = data['subscription_price']?.toString() ?? '10000.0';
      }
    } catch (e) {
      print('Erreur chargement paramètres: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Enregistre les modifications de configuration financière dans `platform_settings`
  /// (mise à jour de l'enregistrement existant ou insertion s'il n'existe pas encore).
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final fee = double.tryParse(_feeController.text) ?? 15.0;
      final price = double.tryParse(_subPriceController.text) ?? 10000.0;

      if (_settingsId != null) {
        await Supabase.instance.client
            .from('platform_settings')
            .update({
              'platform_fee_percentage': fee,
              'subscription_price': price,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _settingsId!);
      } else {
        final res = await Supabase.instance.client
            .from('platform_settings')
            .insert({
              'platform_fee_percentage': fee,
              'subscription_price': price,
            })
            .select()
            .single();
        _settingsId = res['id'];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
        backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: TechLinkCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paramètres Financiers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
                    const SizedBox(height: 24),
                    
                    // Commission
                    TechLinkInput(
                      label: 'Commission Plateforme (%)',
                      hint: 'Ex: 15.0',
                      controller: _feeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 24),

                    // Prix Abonnement
                    TechLinkInput(
                      label: 'Prix Abonnement Mensuel (F CFA)',
                      hint: 'Ex: 10000',
                      controller: _subPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: TechLinkButton(
                        text: 'Sauvegarder',
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: Icons.save,
                        isLoading: _isSaving,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}


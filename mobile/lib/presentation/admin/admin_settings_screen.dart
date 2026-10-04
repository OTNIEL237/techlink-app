import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../shared/widgets/techlink_button.dart';
import '../shared/widgets/techlink_card.dart';
import '../shared/widgets/techlink_input.dart';

// =========================================================================
// ÉCRAN DES PARAMÈTRES (ADMIN)
// =========================================================================
// Permet de configurer les variables globales de la plateforme (commission,
// prix des abonnements, etc.).

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _feeController = TextEditingController();
  final _subPriceController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  int? _settingsId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

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

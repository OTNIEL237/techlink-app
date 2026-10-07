// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : availability_toggle_screen.dart
// Rôle          : Écran de gestion du statut de disponibilité en temps réel
//                 (En ligne / Hors ligne) et des horaires de travail hebdomadaires.
// Module        : Présentation Technicien (Disponibilité & Statut)
// Dépendances   : flutter/material.dart, go_router, supabase_flutter, app_colors.dart
// Sécurité/RLS  : Mise à jour sécurisée de la table `technicians` restreinte
//                 au compte technicien connecté (`user_id`).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Écran permettant au technicien d'ajuster son statut en ligne et ses plages de travail.
class AvailabilityToggleScreen extends StatefulWidget {
  /// Constructeur constant de l'écran de bascule de disponibilité
  const AvailabilityToggleScreen({super.key});

  @override
  State<AvailabilityToggleScreen> createState() => _AvailabilityToggleScreenState();
}

class _AvailabilityToggleScreenState extends State<AvailabilityToggleScreen> {
  /// Indicateur de chargement initial des données
  bool _isLoading = true;

  /// Indicateur de sauvegarde en cours des modifications
  bool _isSaving = false;

  /// État actuel de disponibilité immédiate pour recevoir des missions
  bool _isAvailable = true;

  /// Données brutes de la fiche technicien extraites de Supabase
  Map<String, dynamic>? _technicianData;

  /// Grille des horaires de travail habituels par jour de la semaine
  final Map<String, String> _weeklySchedule = {
    'Lundi': '08:00 - 18:00',
    'Mardi': '08:00 - 18:00',
    'Mercredi': '08:00 - 18:00',
    'Jeudi': '08:00 - 18:00',
    'Vendredi': '08:00 - 18:00',
    'Samedi': '09:00 - 14:00',
    'Dimanche': 'Fermé',
  };

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  /// Charge depuis Supabase le statut actuel et le dictionnaire d'horaires hebdomadaires
  Future<void> _loadAvailability() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final tech = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (tech != null) {
        final statusStr = tech['status'] as String? ?? 'available';
        final availMap = tech['availability'] is Map
            ? Map<String, dynamic>.from(tech['availability'] as Map)
            : <String, dynamic>{};

        final isAvail = statusStr != 'offline' && (availMap['is_available'] != false);

        // Charger les jours
        for (var day in _weeklySchedule.keys.toList()) {
          if (availMap.containsKey(day) && availMap[day] != null) {
            _weeklySchedule[day] = availMap[day].toString();
          }
        }

        if (mounted) {
          setState(() {
            _technicianData = tech;
            _isAvailable = isAvail;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Erreur chargement disponibilité: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Bascule instantanément le statut en direct (visible / masqué) avec retour haptique
  Future<void> _toggleLiveAvailability(bool newValue) async {
    HapticFeedback.heavyImpact();
    setState(() => _isAvailable = newValue);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final currentAvail = Map<String, dynamic>.from(_technicianData?['availability'] as Map? ?? {});
      currentAvail['is_available'] = newValue;
      final statusStr = newValue ? 'available' : 'offline';

      await Supabase.instance.client
          .from('technicians')
          .update({
            'status': statusStr,
            'availability': currentAvail,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      if (_technicianData != null) {
        _technicianData!['status'] = statusStr;
        _technicianData!['availability'] = currentAvail;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? '🟢 Vous êtes visible par les clients'
                  : '⚪ Vous êtes en pause (invisible pour les clients)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: newValue ? const Color(0xFF059669) : const Color(0xFF475569),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAvailable = !newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Enregistre l'ensemble des réglages (statut et calendrier hebdomadaire) dans Supabase
  Future<void> _saveAllSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final updatedAvail = Map<String, dynamic>.from(_technicianData?['availability'] as Map? ?? {});
      updatedAvail['is_available'] = _isAvailable;

      _weeklySchedule.forEach((key, value) {
        updatedAvail[key] = value;
      });

      final statusStr = _isAvailable ? 'available' : 'offline';

      await Supabase.instance.client
          .from('technicians')
          .update({
            'status': statusStr,
            'availability': updatedAvail,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vos horaires et disponibilités ont été enregistrés avec succès.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Ouvre une feuille modale pour éditer la plage horaire d'un jour particulier
  void _editDayHours(String day) {
    final current = _weeklySchedule[day] ?? '08:00 - 18:00';
    final controller = TextEditingController(text: current);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Horaires du $day', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('08:00 - 18:00'),
                    onPressed: () => controller.text = '08:00 - 18:00',
                  ),
                  ActionChip(
                    label: const Text('08:00 - 12:00'),
                    onPressed: () => controller.text = '08:00 - 12:00',
                  ),
                  ActionChip(
                    label: const Text('Fermé'),
                    onPressed: () => controller.text = 'Fermé',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Plage horaire',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _weeklySchedule[day] = controller.text.trim());
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Valider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>() ?? TechLinkColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: tc.background,
        appBar: AppBar(title: const Text('Disponibilité & Statut'), backgroundColor: tc.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Disponibilité & Statut', style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: tc.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: tc.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. COMMUTATEUR EN TEMPS RÉEL
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isAvailable ? const Color(0xFF059669).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isAvailable
                      ? const Color(0xFF059669).withOpacity(isDark ? 0.2 : 0.08)
                      : const Color(0xFFEF4444).withOpacity(isDark ? 0.18 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isAvailable
                                  ? const Color(0xFF059669).withOpacity(0.15)
                                  : const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _isAvailable ? Icons.sensors_rounded : Icons.power_settings_new_rounded,
                              color: _isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statut d\'intervention',
                                  style: TextStyle(color: tc.textSecondary, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isAvailable ? 'DISPONIBLE' : 'HORS LIGNE',
                                  style: TextStyle(
                                    color: _isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _isAvailable,
                      activeColor: const Color(0xFF059669),
                      activeTrackColor: const Color(0xFF059669).withOpacity(0.35),
                      inactiveThumbColor: const Color(0xFFEF4444),
                      inactiveTrackColor: const Color(0xFFEF4444).withOpacity(0.25),
                      onChanged: (val) => _toggleLiveAvailability(val),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isAvailable
                      ? '✓ Votre profil est actuellement visible sur la carte pour les clients. Vous pouvez recevoir des demandes d\'intervention immédiates.'
                      : '✕ Votre profil est masqué des recherches clients. Vous ne recevrez aucune nouvelle proposition d\'intervention.',
                  style: TextStyle(
                    color: tc.textPrimary.withOpacity(0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. HORAIRES HEBDOMADAIRES
          Text(
            'Horaires de travail réguliers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tc.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Indiquez à vos clients vos plages de disponibilité habituelles.',
            style: TextStyle(fontSize: 12.5, color: tc.textSecondary),
          ),
          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tc.border, width: 0.8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _weeklySchedule.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: tc.border),
              itemBuilder: (context, idx) {
                final day = _weeklySchedule.keys.elementAt(idx);
                final hours = _weeklySchedule[day]!;
                final isClosed = hours.toLowerCase().contains('fermé');

                return ListTile(
                  title: Text(day, style: TextStyle(fontWeight: FontWeight.w700, color: tc.textPrimary, fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isClosed ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF059669).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hours,
                          style: TextStyle(
                            color: isClosed ? const Color(0xFFEF4444) : const Color(0xFF059669),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_outlined, size: 16, color: tc.textSecondary),
                    ],
                  ),
                  onTap: () => _editDayHours(day),
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          // 3. BOUTON ENREGISTRER
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAllSettings,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text(
                _isSaving ? 'Enregistrement...' : 'Enregistrer mes disponibilités',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

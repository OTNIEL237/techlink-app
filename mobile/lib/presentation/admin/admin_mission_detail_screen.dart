// =============================================================================
// FICHIER : admin_mission_detail_screen.dart
// RÔLE : Vue d'inspection et d'arbitrage forcé d'une mission (annulation d'urgence, vérification des photos)
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, supabase_flutter, app_colors.dart
// SÉCURITÉ / RLS : Rôle administrateur requis. Modification de statut d'urgence dans la table `missions`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Écran administrateur affichant les détails exhaustifs d'une intervention.
///
/// Permet de contrôler les identités du client et du prestataire assigné, de visualiser
/// les photographies du problème téléversées, et de forcer l'annulation d'une mission bloquée.
class AdminMissionDetailScreen extends StatefulWidget {
  /// Données brutes de la mission sélectionnée.
  final Map<String, dynamic> mission;

  /// Constructeur constant du widget [AdminMissionDetailScreen].
  const AdminMissionDetailScreen({super.key, required this.mission});

  @override
  State<AdminMissionDetailScreen> createState() => _AdminMissionDetailScreenState();
}

/// État associé à la vue détaillée de mission administrative.
///
/// Gère l'actualisation locale du statut et l'exécution de l'annulation d'urgence.
class _AdminMissionDetailScreenState extends State<AdminMissionDetailScreen> {
  /// Indicateur d'opération d'annulation réseau en cours.
  bool _isCancelling = false;

  /// Statut courant de la mission réactif aux modifications locales.
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.mission['status'] ?? 'pending';
  }

  /// Déclenche un dialogue de confirmation puis force le basculement du statut à `'cancelled'`.
  Future<void> _forceCancelMission() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forcer l\'annulation ?'),
        content: const Text('Cette action annulera définitivement la mission et avertira les deux parties. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await Supabase.instance.client
          .from('missions')
          .update({'status': 'cancelled'})
          .eq('id', widget.mission['id']);

      if (mounted) {
        setState(() => _currentStatus = 'cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mission annulée avec succès'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  /// Construit la vue de mission avec photos, informations des parties et bouton d'action d'urgence.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    final clientName = widget.mission['clients']?['name'] ?? 'Client Inconnu';
    final techName = widget.mission['technicians']?['name'] ?? 'Non assigné';
    final category = widget.mission['categories']?['name'] ?? 'Service';
    final List<dynamic> photos = widget.mission['photos'] ?? [];

    Color statusColor = AppColors.textSecondary;
    if (_currentStatus == 'pending') statusColor = AppColors.warning;
    if (_currentStatus == 'in_progress') statusColor = Colors.blue;
    if (_currentStatus == 'completed' || _currentStatus == 'paid') statusColor = AppColors.success;
    if (_currentStatus == 'cancelled') statusColor = AppColors.error;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Détails de la mission', style: TextStyle(color: Colors.white)),
        backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tc.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentStatus.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoCard('Client', clientName, widget.mission['clients']?['phone'], tc, isDark),
            const SizedBox(height: 12),
            _buildInfoCard('Technicien', techName, widget.mission['technicians']?['phone'], tc, isDark),
            const SizedBox(height: 20),
            Text('Description du problème', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? tc.surface : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? tc.border : Colors.transparent),
              ),
              child: Text(widget.mission['problem_description'] ?? 'Aucune description', style: TextStyle(color: tc.textPrimary)),
            ),
            const SizedBox(height: 20),
            if (photos.isNotEmpty) ...[
              Text('Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(photos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            if (_currentStatus != 'cancelled' && _currentStatus != 'completed' && _currentStatus != 'paid')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCancelling ? null : _forceCancelMission,
                  icon: _isCancelling ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cancel),
                  label: const Text('Forcer l\'annulation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Construit une carte d'informations d'identité et de contact pour un intervenant (client ou technicien).
  Widget _buildInfoCard(String title, String name, String? phone, TechLinkColors tc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? tc.surface : Colors.white,
        border: Border.all(color: isDark ? tc.border : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDark ? tc.primaryLight : AppColors.primaryLight,
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
                if (phone != null) Text(phone, style: TextStyle(color: tc.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

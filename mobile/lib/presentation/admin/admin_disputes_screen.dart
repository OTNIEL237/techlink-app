// =============================================================================
// FICHIER : admin_disputes_screen.dart
// RÔLE : Tableau de bord et supervision de l'ensemble des réclamations et litiges
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, supabase_flutter, app_colors.dart, admin_dispute_details_screen.dart
// SÉCURITÉ / RLS : Rôle administrateur requis. Lecture de la table `disputes` et des liaisons `users` et `missions`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'admin_dispute_details_screen.dart';

/// Écran administrateur répertoriant tous les litiges déclarés sur la plateforme.
///
/// Distingue les contestations ouvertes, en cours d'instruction, et résolues,
/// avec accès direct au détail pour procéder à l'arbitrage.
class AdminDisputesScreen extends StatefulWidget {
  /// Constructeur constant du widget [AdminDisputesScreen].
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

/// État associé au tableau de bord des litiges administrateur.
///
/// Gère la récupération des litiges avec les détails du rapporteur et de la mission,
/// ainsi que le rafraîchissement automatique après arbitrage.
class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  /// Liste des litiges récupérés depuis la base de données.
  List<Map<String, dynamic>> _disputes = [];

  /// Indicateur de chargement asynchrone des litiges.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  /// Charge tous les litiges par ordre chronologique décroissant depuis Supabase.
  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('disputes')
          .select('*, users:reporter_id(name, phone, role), missions:mission_id(problem_description, status, client_id, technician_id)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _disputes = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Erreur: $e');
    }
  }

  /// Ouvre l'écran d'arbitrage [AdminDisputeDetailsScreen] et recharge la liste si le litige a été résolu.
  void _navigateToDetails(Map<String, dynamic> dispute) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminDisputeDetailsScreen(dispute: dispute)),
    );
    if (result == true) {
      _loadDisputes();
    }
  }

  /// Construit la vue de liste des litiges avec badges de statut et boutons d'examen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Litiges'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _disputes.isEmpty
              ? const Center(child: Text('Aucun litige trouvé.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _disputes.length,
                  itemBuilder: (context, index) {
                    final d = _disputes[index];
                    final reporterName = d['users']?['name'] ?? 'Inconnu';
                    final reporterRole = d['users']?['role'] ?? '';
                    final reason = d['reason'] ?? 'Non spécifié';
                    final status = d['status'] ?? 'open';
                    
                    Color statusColor = status == 'open' ? AppColors.error : AppColors.success;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Signalé par : $reporterName ($reporterRole)', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(d['description'] ?? 'Aucune description'),
                            const SizedBox(height: 12),
                            if (d['resolution_notes'] != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: Colors.grey.shade100,
                                width: double.infinity,
                                child: Text('Notes: ${d['resolution_notes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                              ),
                            ] else if (status == 'open') ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () => _navigateToDetails(d),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                    child: const Text('Voir le Litige'),
                                  ),
                                )
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

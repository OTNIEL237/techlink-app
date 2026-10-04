import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'admin_dispute_details_screen.dart';

// =========================================================================
// ÉCRAN DES LITIGES (ADMIN)
// =========================================================================
// Affiche la liste des litiges ouverts et résolus entre clients et techniciens.

class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  List<Map<String, dynamic>> _disputes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

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

  void _navigateToDetails(Map<String, dynamic> dispute) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminDisputeDetailsScreen(dispute: dispute)),
    );
    if (result == true) {
      _loadDisputes();
    }
  }

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

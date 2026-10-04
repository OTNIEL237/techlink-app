import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

// =========================================================================
// ÉCRAN DE GESTION DES PAIEMENTS/RETRAITS (ADMIN)
// =========================================================================
// Permet à l'administrateur de traiter et de valider les demandes de retrait
// effectuées par les techniciens.

class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  Future<void> _loadPayouts() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('payouts')
          .select('*, technicians:technician_id(name, phone, users(name))')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _payouts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Erreur: $e');
    }
  }

  Future<void> _processPayout(String id, String newStatus) async {
    try {
      await Supabase.instance.client.from('payouts').update({
        'status': newStatus,
        'admin_id': Supabase.instance.client.auth.currentUser!.id,
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paiement marqué comme $newStatus'),
            backgroundColor: newStatus == 'completed' ? AppColors.success : AppColors.error,
          ),
        );
      }
      _loadPayouts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retraits (Payouts)'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payouts.isEmpty
              ? const Center(child: Text('Aucune demande de retrait.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payouts.length,
                  itemBuilder: (context, index) {
                    final p = _payouts[index];
                    final techName = p['technicians']?['users']?['name'] ?? p['technicians']?['name'] ?? 'Inconnu';
                    final status = p['status'] ?? 'pending';

                    Color statusColor = AppColors.warning;
                    if (status == 'completed') statusColor = AppColors.success;
                    if (status == 'failed') statusColor = AppColors.error;

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
                                Text('${p['amount']} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Technicien: $techName', style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text('Via ${p['payment_method']} (${p['phone_number']})', style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            if (status == 'pending')
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _processPayout(p['id'], 'completed'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                                      child: const Text('Marquer Payé'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _processPayout(p['id'], 'failed'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                      child: const Text('Rejeter'),
                                    ),
                                  ),
                                ],
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

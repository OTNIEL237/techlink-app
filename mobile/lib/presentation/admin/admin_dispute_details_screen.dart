import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/api_service.dart';

// =========================================================================
// ÉCRAN DE DÉTAILS D'UN LITIGE (ADMIN)
// =========================================================================
// Permet de voir les détails d'un litige spécifique et de le résoudre.

class AdminDisputeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> dispute;

  const AdminDisputeDetailsScreen({super.key, required this.dispute});

  @override
  State<AdminDisputeDetailsScreen> createState() => _AdminDisputeDetailsScreenState();
}

class _AdminDisputeDetailsScreenState extends State<AdminDisputeDetailsScreen> {
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  Future<void> _resolveDispute(String action) async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer des notes de résolution.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final apiService = ApiService();
      final response = await apiService.post('/admin/disputes/${widget.dispute['id']}/resolve', {
        'action': action,
        'adminId': Supabase.instance.client.auth.currentUser!.id,
        'notes': _notesController.text.trim(),
      });

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Litige résolu avec succès'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true); // return true to refresh
        }
      } else {
        throw Exception(response['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    final reporterName = d['users']?['name'] ?? 'Inconnu';
    final missionId = d['mission_id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Litige'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mission ID: $missionId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motif: ${d['reason']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Signalé par: $reporterName'),
                    const Divider(),
                    Text(d['description'] ?? 'Aucune description fournie.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (d['status'] == 'open' || d['status'] == 'investigating') ...[
              const Text('Notes de résolution obligatoires :', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Expliquez votre décision...',
                ),
              ),
              const SizedBox(height: 24),
              const Text('Choisir une Action de Résolution :', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else ...[
                _buildActionCard(
                  title: 'Annuler la mission',
                  description: 'Annule la mission et clôture le litige.',
                  color: AppColors.error,
                  icon: Icons.cancel,
                  onTap: () => _resolveDispute('neutral_cancel'),
                ),
              ]
            ] else ...[
              const Card(
                color: Colors.green,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Ce litige a déjà été résolu.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Notes: ${d['resolution_notes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String description, required Color color, required IconData icon, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

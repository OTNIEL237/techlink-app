import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

// =========================================================================
// ÉCRAN DES NOTIFICATIONS GLOBALES (ADMIN)
// =========================================================================
// Permet à l'administrateur d'envoyer des notifications (broadcasts)
// à tous les utilisateurs, aux clients ou aux techniciens.

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetAudience = 'all';
  bool _isSending = false;

  List<Map<String, dynamic>> _broadcasts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('broadcasts')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _broadcasts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Erreur chargement broadcasts: $e');
    }
  }

  Future<void> _sendBroadcast() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs')));
      return;
    }

    setState(() => _isSending = true);
    try {
      await Supabase.instance.client.from('broadcasts').insert({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'target_audience': _targetAudience,
        'admin_id': Supabase.instance.client.auth.currentUser!.id,
        'is_active': true,
      });

      _titleController.clear();
      _messageController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification globale envoyée avec succès !'), backgroundColor: AppColors.success));
      }
      _loadBroadcasts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleActive(String id, bool currentStatus) async {
    try {
      await Supabase.instance.client.from('broadcasts').update({'is_active': !currentStatus}).eq('id', id);
      _loadBroadcasts();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Notifications Globales', style: TextStyle(color: Colors.white)),
        backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Formulaire
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? tc.surface : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouvelle Notification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Titre de la notification',
                    labelStyle: TextStyle(color: tc.textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tc.border)),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: tc.textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tc.border)),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _targetAudience,
                  dropdownColor: tc.surface,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Cible',
                    labelStyle: TextStyle(color: tc.textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: tc.border)),
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tous les utilisateurs')),
                    DropdownMenuItem(value: 'clients', child: Text('Clients uniquement')),
                    DropdownMenuItem(value: 'technicians', child: Text('Techniciens uniquement')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _targetAudience = val);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendBroadcast,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text('Envoyer et Sauvegarder', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: tc.border),
          
          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _broadcasts.isEmpty
                    ? Center(child: Text('Aucune notification', style: TextStyle(color: tc.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _broadcasts.length,
                        itemBuilder: (context, index) {
                          final b = _broadcasts[index];
                          final isActive = b['is_active'] ?? false;
                          return Card(
                            color: isDark ? tc.card : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? tc.border : Colors.transparent),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(b['title'], style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? tc.textPrimary : tc.textSecondary.withOpacity(0.5))),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Cible: ${b['target_audience']}', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(b['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isActive ? tc.textSecondary : tc.textSecondary.withOpacity(0.5))),
                                ],
                              ),
                              trailing: Switch(
                                value: isActive,
                                activeColor: AppColors.primary,
                                onChanged: (val) => _toggleActive(b['id'], isActive),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

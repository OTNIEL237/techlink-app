import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/zego_call_service.dart';

// =========================================================================
// ÉCRAN D'HISTORIQUE DES APPELS
// =========================================================================
// Affiche la liste des appels émis et reçus par l'utilisateur courant.
// Permet de rappeler un contact directement depuis l'historique.

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('calls')
          .select('*, caller:users!calls_caller_id_fkey(id, name), receiver:users!calls_receiver_id_fkey(id, name)')
          .or('caller_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _calls = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading call history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Historique des appels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _calls.length,
                    itemBuilder: (context, index) {
                      final call = _calls[index];
                      final isOutgoing = call['caller_id'] == myUserId;
                      
                      final contact = isOutgoing 
                          ? call['receiver'] as Map<String, dynamic>?
                          : call['caller'] as Map<String, dynamic>?;
                          
                      final contactName = contact?['name'] as String? ?? 'Correspondant';
                      final contactId = contact?['id'] as String? ?? '';
                      final status = call['status'] as String? ?? 'ended';
                      final createdAtStr = call['created_at'] as String?;
                      
                      DateTime? date;
                      if (createdAtStr != null) {
                        date = DateTime.tryParse(createdAtStr)?.toLocal();
                      }

                      IconData icon;
                      Color iconColor;
                      String statusText;

                      if (status == 'missed' || status == 'ringing') {
                        icon = isOutgoing ? Icons.call_made : Icons.call_missed;
                        iconColor = isOutgoing ? AppColors.textSecondary : AppColors.error;
                        statusText = isOutgoing ? 'Sans réponse' : 'Manqué';
                      } else if (status == 'declined') {
                        icon = isOutgoing ? Icons.call_made : Icons.call_received;
                        iconColor = AppColors.error;
                        statusText = isOutgoing ? 'Rejeté' : 'Refusé';
                      } else {
                        icon = isOutgoing ? Icons.call_made : Icons.call_received;
                        iconColor = AppColors.success;
                        statusText = isOutgoing ? 'Sortant' : 'Entrant';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: iconColor.withOpacity(0.1),
                            child: Icon(icon, color: iconColor),
                          ),
                          title: Text(
                            contactName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              if (date != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          trailing: contactId.isNotEmpty
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.phone, color: AppColors.success),
                                      onPressed: () {
                                        ZegoCallService().startCall(
                                          context,
                                          receiverId: contactId,
                                          receiverName: contactName,
                                          callType: 'audio',
                                        );
                                      },
                                      tooltip: 'Appel Audio',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.videocam, color: AppColors.primary),
                                      onPressed: () {
                                        ZegoCallService().startCall(
                                          context,
                                          receiverId: contactId,
                                          receiverName: contactName,
                                          callType: 'video',
                                        );
                                      },
                                      tooltip: 'Appel Vidéo',
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun appel',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vos appels récents s\'afficheront ici.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

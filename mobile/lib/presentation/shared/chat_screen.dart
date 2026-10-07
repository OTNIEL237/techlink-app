// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : chat_screen.dart
// Rôle          : Messagerie instantanée en temps réel entre client et technicien pour une mission.
// Module        : Presentation / Shared
// Dépendances   : flutter, supabase_flutter, url_launcher, app_colors.dart, zego_call_service.dart
// Sécurité/RLS  : Écoute Supabase Realtime sur la table 'messages' filtrée par mission_id.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/zego_call_service.dart';

/// Écran de discussion instantanée rattaché à une mission d'intervention spécifique.
///
/// Permet l'échange de messages textuels en direct entre le client et le technicien affecté.
/// Intègre :
/// - La réception en temps réel via Supabase Realtime (`messages` table).
/// - L'appel direct (voix ou vidéo) via [ZegoCallService].
/// - La composition d'appel téléphonique cellulaire classique via [url_launcher].
class ChatScreen extends StatefulWidget {
  /// Identifiant unique de la mission associée à la conversation.
  final String missionId;

  /// Identifiant de l'utilisateur actuellement connecté.
  final String currentUserId;

  /// Rôle de l'utilisateur connecté ('client' ou 'technician').
  final String currentUserRole;

  /// Nom complet de l'interlocuteur affiché dans la barre d'en-tête.
  final String otherUserName;

  /// Numéro de téléphone de l'interlocuteur.
  final String otherUserPhone;

  /// Constructeur de [ChatScreen].
  const ChatScreen({
    super.key,
    required this.missionId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.otherUserName,
    required this.otherUserPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// État associé à l'écran de messagerie instantanée [ChatScreen].
class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('mission_id', widget.missionId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Nouvelle version : Realtime sans filtre + polling fallback
  void _subscribeToMessages() {
    // Realtime
    _channel = Supabase.instance.client
        .channel('chat-${widget.missionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg['mission_id'] == widget.missionId && mounted) {
              // Éviter les doublons
              final exists = _messages.any(
                  (m) => m['id'] == newMsg['id']);
              if (!exists) {
                setState(() => _messages.add(
                    Map<String, dynamic>.from(newMsg)));
                _scrollToBottom();
                _markAsRead();
              }
            }
          },
        )
        .subscribe();

    // Méthode de secours (polling) toutes les 3 secondes au cas où Realtime échoue
    _startPolling();
  }

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      await _refreshMessages();
      return mounted;
    });
  }

  Future<void> _refreshMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('mission_id', widget.missionId)
          .order('created_at', ascending: true);

      final newMessages = List<Map<String, dynamic>>.from(data);

      if (mounted && newMessages.length != _messages.length) {
        setState(() => _messages = newMessages);
        _scrollToBottom();
        _markAsRead();
      }
    } catch (_) {}
  }

  Future<void> _markAsRead() async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('mission_id', widget.missionId)
          .neq('sender_id', widget.currentUserId);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await Supabase.instance.client.from('messages').insert({
        'mission_id': widget.missionId,
        'sender_id': widget.currentUserId,
        'sender_role': widget.currentUserRole,
        'content': content,
      });

      // ✅ Rafraîchir immédiatement après envoi
      await _refreshMessages();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur envoi: $e'),
            backgroundColor: Colors.red),
        );
        // Remettre le texte si erreur
        _messageController.text = content;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _callOtherUser(String callType) async {
    try {
      // Récupérer la mission pour trouver l'ID du client et du technicien
      final mission = await Supabase.instance.client
          .from('missions')
          .select('client_id, technician_id')
          .eq('id', widget.missionId)
          .single();

      String otherUserId;
      if (widget.currentUserRole == 'client') {
        otherUserId = mission['technician_id'] as String? ?? '';
      } else {
        otherUserId = mission['client_id'] as String? ?? '';
      }

      if (otherUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Correspondant introuvable.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (mounted) {
        ZegoCallService().startCall(
          context,
          receiverId: otherUserId,
          receiverName: widget.otherUserName,
          callType: callType,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Erreur appel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        iconTheme: IconThemeData(color: tc.textPrimary),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? tc.textPrimary : AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: tc.textPrimary),
                  ),
                  Text(
                    widget.currentUserRole == 'client'
                        ? 'Technicien'
                        : 'Client',
                    style: TextStyle(
                      fontSize: 11,
                      color: tc.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Bouton appel audio Zego
          IconButton(
            onPressed: () {
              _callOtherUser('audio');
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone,
                  color: AppColors.success, size: 20),
            ),
            tooltip: 'Appel Audio',
          ),
          // Bouton appel vidéo Zego
          IconButton(
            onPressed: () {
              _callOtherUser('video');
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam,
                  color: AppColors.primary, size: 20),
            ),
            tooltip: 'Appel Vidéo',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── MESSAGES ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyChat(tc, isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] ==
                              widget.currentUserId;
                          final showDate = index == 0 ||
                              _shouldShowDate(
                                  _messages[index - 1], msg);

                          return Column(
                            children: [
                                if (showDate) _buildDateDivider(
                                    msg['created_at'] as String, tc, isDark),
                                _MessageBubble(
                                  message: msg,
                                  isMe: isMe,
                                  tc: tc,
                                  isDark: isDark,
                                ),
                              ],
                            );
                          },
                        ),
            ),

            // ── BARRE SAISIE ──
            _buildInputBar(tc, isDark),
        ],
      ),
    );
  }

  bool _shouldShowDate(
      Map<String, dynamic> prev, Map<String, dynamic> curr) {
    try {
      final prevDate =
          DateTime.parse(prev['created_at']).toLocal();
      final currDate =
          DateTime.parse(curr['created_at']).toLocal();
      return prevDate.day != currDate.day;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateDivider(String dateStr, TechLinkColors tc, bool isDark) {
    String label = '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(
              DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0) label = "Aujourd'hui";
      else if (diff == 1) label = 'Hier';
      else label =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
              style: TextStyle(
                color: tc.textSecondary,
                fontSize: 11)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(TechLinkColors tc, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Démarrez la conversation',
            style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Échangez avec ${widget.otherUserName}',
            style: TextStyle(
              color: tc.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInputBar(TechLinkColors tc, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 10, bottom: 10 +
            MediaQuery.of(context).viewInsets.bottom * 0.1,
      ),
      decoration: BoxDecoration(
        color: isDark ? tc.card : tc.surface,
        border: Border(
            top: BorderSide(color: tc.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              style: TextStyle(color: tc.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Écrire un message...',
                hintStyle: TextStyle(
                    color: tc.textSecondary),
                filled: true,
                fillColor: tc.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton envoyer
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
                ],
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BULLE MESSAGE ──
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final TechLinkColors tc;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.tc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final dateStr = message['created_at'] as String? ?? '';
    String time = '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      time =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.person,
                    size: 16,
                    color: AppColors.primary)),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary
                    : (isDark ? tc.card : tc.surface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(content,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : tc.textPrimary,
                      fontSize: 14,
                      height: 1.4)),
                  const SizedBox(height: 4),
                  Text(time,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : tc.textSecondary,
                      fontSize: 10)),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
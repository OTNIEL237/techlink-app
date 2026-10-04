import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

// =========================================================================
// ÉCRAN DE CHAT SUPPORT
// =========================================================================
// Permet à un utilisateur (Client ou Technicien) de discuter avec l'équipe
// d'administration TechLink. Les messages sont stockés dans la table
// `admin_messages` et écoutés via Supabase Realtime.

class SupportChatScreen extends StatefulWidget {
  final String conversationUserId; // L'ID du client ou technicien
  final String currentUserId;
  final String currentUserRole;
  final String otherUserName; // "Support Admin" ou le nom du client

  const SupportChatScreen({
    super.key,
    required this.conversationUserId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.otherUserName,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
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
          .from('admin_messages')
          .select('*')
          .eq('user_id', widget.conversationUserId)
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

  void _subscribeToMessages() {
    _channel = Supabase.instance.client
        .channel('admin-chat-${widget.conversationUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'admin_messages',
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg['user_id'] == widget.conversationUserId && mounted) {
              final exists = _messages.any((m) => m['id'] == newMsg['id']);
              if (!exists) {
                setState(() => _messages.add(Map<String, dynamic>.from(newMsg)));
                _scrollToBottom();
                _markAsRead();
              }
            }
          },
        )
        .subscribe();

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
          .from('admin_messages')
          .select('*')
          .eq('user_id', widget.conversationUserId)
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
          .from('admin_messages')
          .update({'is_read': true})
          .eq('user_id', widget.conversationUserId)
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
      await Supabase.instance.client.from('admin_messages').insert({
        'user_id': widget.conversationUserId,
        'sender_id': widget.currentUserId,
        'sender_role': widget.currentUserRole,
        'content': content,
      });

      await _refreshMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur envoi: $e'),
            backgroundColor: Colors.red),
        );
        _messageController.text = content;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
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
                    widget.currentUserRole == 'admin' ? 'Support Client' : 'Admin TechLink',
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
      ),
      body: Column(
        children: [
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
                          final isMe = msg['sender_id'] == widget.currentUserId;
                          final showDate = index == 0 || _shouldShowDate(_messages[index - 1], msg);

                          return Column(
                            children: [
                                if (showDate) _buildDateDivider(msg['created_at'] as String, tc, isDark),
                                _MessageBubble(message: msg, isMe: isMe, tc: tc, isDark: isDark),
                              ],
                            );
                          },
                        ),
            ),
            _buildInputBar(tc, isDark),
        ],
      ),
    );
  }

  bool _shouldShowDate(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    try {
      final prevDate = DateTime.parse(prev['created_at']).toLocal();
      final currDate = DateTime.parse(curr['created_at']).toLocal();
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
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0) label = "Aujourd'hui";
      else if (diff == 1) label = 'Hier';
      else label = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: TextStyle(color: tc.textSecondary, fontSize: 11)),
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
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Comment pouvons-nous vous aider ?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('L\'équipe de support est là pour vous.',
            style: TextStyle(color: tc.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInputBar(TechLinkColors tc, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 10, bottom: 10 + MediaQuery.of(context).viewInsets.bottom * 0.1,
      ),
      decoration: BoxDecoration(
        color: isDark ? tc.card : tc.surface,
        border: Border(top: BorderSide(color: tc.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -2)),
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
                hintText: 'Votre message...',
                hintStyle: TextStyle(color: tc.textSecondary),
                filled: true,
                fillColor: tc.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: _isSending
                  ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final TechLinkColors tc;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isMe, required this.tc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final dateStr = message['created_at'] as String? ?? '';
    String time = '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : (isDark ? tc.card : tc.surface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(content, style: TextStyle(color: isMe ? Colors.white : tc.textPrimary, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(color: isMe ? Colors.white.withOpacity(0.7) : tc.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

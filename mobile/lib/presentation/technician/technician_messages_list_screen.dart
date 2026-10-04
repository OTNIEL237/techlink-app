import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../shared/chat_screen.dart';
import '../shared/support_chat_screen.dart';

// =========================================================================
// ÉCRAN DES MESSAGES DU TECHNICIEN
// =========================================================================
// Affiche la liste des conversations du technicien avec ses clients et 
// avec le support administrateur. Permet d'y accéder.

class TechnicianMessagesListScreen extends StatefulWidget {
  const TechnicianMessagesListScreen({super.key});

  @override
  State<TechnicianMessagesListScreen> createState() => _TechnicianMessagesListScreenState();
}

class _TechnicianMessagesListScreenState extends State<TechnicianMessagesListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chats = [];

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreChats();
    }
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _hasMore = true;
      _chats = [];
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 1. Récupérer les missions où le technicien est impliqué
      final missions = await Supabase.instance.client
          .from('missions')
          .select('id, client_id, users!missions_client_id_fkey(id, name, avatar_url, phone)')
          .eq('technician_id', userId)
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      // 2. Récupérer le dernier message de chaque mission en parallèle
      final futures = missions.map((m) async {
        final missionId = m['id'] as String;
        final msgData = await Supabase.instance.client
            .from('messages')
            .select()
            .eq('mission_id', missionId)
            .order('created_at', ascending: false)
            .limit(1);
        return {'mission': m, 'msgData': msgData};
      });

      final results = await Future.wait(futures);

      Map<String, Map<String, dynamic>> clientChats = {};

      for (var result in results) {
        final m = result['mission'] as Map<String, dynamic>;
        final missionId = m['id'] as String;
        final user = m['users'] as Map<String, dynamic>?;

        if (user == null) continue;
        final clientId = user['id'];

        final msgData = result['msgData'] as List<dynamic>;

        if (msgData.isNotEmpty) {
          final latestMsg = msgData.first;
          final currentChat = clientChats[clientId];
          
          if (currentChat == null || DateTime.parse(latestMsg['created_at']).isAfter(DateTime.parse(currentChat['created_at']))) {
            clientChats[clientId] = {
              'mission_id': missionId,
              'client_id': clientId,
              'client_name': user['name'] ?? 'Client',
              'client_avatar': user['avatar_url'],
              'client_phone': user['phone'] ?? '',
              'last_message': latestMsg['content'],
              'created_at': latestMsg['created_at'],
              'is_read': latestMsg['is_read'],
              'sender_id': latestMsg['sender_id'],
            };
          }
        }
      }

      List<Map<String, dynamic>> chats = clientChats.values.toList();

      // Récupérer le dernier message envoyé par l'administrateur (support) à cet utilisateur
      final adminMsgData = await Supabase.instance.client
          .from('admin_messages')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      
      if (adminMsgData.isNotEmpty) {
        final latestAdminMsg = adminMsgData.first;
        chats.add({
          'is_support': true,
          'client_id': 'support',
          'client_name': 'Support TechLink',
          'client_avatar': null,
          'client_phone': '',
          'last_message': latestAdminMsg['content'],
          'created_at': latestAdminMsg['created_at'],
          'is_read': latestAdminMsg['is_read'],
          'sender_id': latestAdminMsg['sender_id'],
          'mission_id': 'support',
        });
      }

      // Trier les conversations par date du dernier message (du plus récent au plus ancien)
      chats.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _chats = chats;
          _hasMore = missions.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreChats() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _page++;
      final missions = await Supabase.instance.client
          .from('missions')
          .select('id, client_id, users!missions_client_id_fkey(id, name, avatar_url, phone)')
          .eq('technician_id', userId)
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      // Récupérer les derniers messages pour ces nouvelles missions en parallèle
      final futures = missions.map((m) async {
        final missionId = m['id'] as String;
        final msgData = await Supabase.instance.client
            .from('messages')
            .select()
            .eq('mission_id', missionId)
            .order('created_at', ascending: false)
            .limit(1);
        return {'mission': m, 'msgData': msgData};
      });

      final results = await Future.wait(futures);

      Map<String, Map<String, dynamic>> clientChats = {};

      for (var result in results) {
        final m = result['mission'] as Map<String, dynamic>;
        final missionId = m['id'] as String;
        final user = m['users'] as Map<String, dynamic>?;

        if (user == null) continue;
        final clientId = user['id'];

        final msgData = result['msgData'] as List<dynamic>;

        if (msgData.isNotEmpty) {
          final latestMsg = msgData.first;
          final currentChat = clientChats[clientId];
          
          if (currentChat == null || DateTime.parse(latestMsg['created_at']).isAfter(DateTime.parse(currentChat['created_at']))) {
            clientChats[clientId] = {
              'mission_id': missionId,
              'client_id': clientId,
              'client_name': user['name'] ?? 'Client',
              'client_avatar': user['avatar_url'],
              'client_phone': user['phone'] ?? '',
              'last_message': latestMsg['content'],
              'created_at': latestMsg['created_at'],
              'is_read': latestMsg['is_read'],
              'sender_id': latestMsg['sender_id'],
            };
          }
        }
      }

      List<Map<String, dynamic>> newChats = clientChats.values.toList();
      newChats.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _chats.addAll(newChats);
          // Re-trier toute la liste par sécurité après l'ajout de nouvelles conversations
          _chats.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
          _hasMore = missions.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
          
      if (diff == 0) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff == 1) {
        return 'Hier';
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
        centerTitle: true,
        backgroundColor: tc.background,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: tc.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? _buildEmpty(tc, isDark)
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _chats.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _chats.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final chat = _chats[index];
                      return _buildChatItem(chat, tc, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, TechLinkColors tc, bool isDark) {
    final avatarUrl = chat['client_avatar'] as String?;
    final name = chat['client_name'] as String;
    final lastMessage = chat['last_message'] as String;
    final time = _formatTime(chat['created_at'] as String);
    
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final isUnread = !(chat['is_read'] as bool? ?? true) && chat['sender_id'] != currentUserId;

    final isSupport = chat['is_support'] == true;

    return InkWell(
      onTap: () {
        if (isSupport) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupportChatScreen(
                conversationUserId: currentUserId,
                currentUserId: currentUserId,
                currentUserRole: 'technician',
                otherUserName: 'Support TechLink',
              ),
            ),
          ).then((_) => _loadChats());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                missionId: chat['mission_id'],
                currentUserId: currentUserId,
                currentUserRole: 'technician',
                otherUserName: name,
                otherUserPhone: chat['client_phone'],
              ),
            ),
          ).then((_) => _loadChats());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tc.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primary.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                image: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: chat['is_support'] == true
                  ? const Center(child: Icon(Icons.support_agent, color: AppColors.primary, size: 28))
                  : (avatarUrl == null || avatarUrl.isEmpty)
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        )
                      : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: tc.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnread ? AppColors.primary : tc.textSecondary,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: isUnread ? tc.textPrimary : tc.textSecondary,
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(TechLinkColors tc, bool isDark) {
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
            child: Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun message',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: tc.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez démarré aucune conversation.',
            style: TextStyle(color: tc.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

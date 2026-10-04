import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../shared/chat_screen.dart';
import '../shared/support_chat_screen.dart';

// =========================================================================
// ÉCRAN MODERNE DE LISTE DES MESSAGES CLIENT
// =========================================================================

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chats = [];

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((chat) {
      final name = (chat['technician_name'] as String? ?? '').toLowerCase();
      final msg = (chat['last_message'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) || msg.contains(_searchQuery);
    }).toList();
  }

  int get _unreadTotal {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return _chats.where((c) => !(c['is_read'] as bool? ?? true) && c['sender_id'] != currentUserId).length;
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

      // 1. Récupérer les missions où le client est impliqué et a un technicien
      final missions = await Supabase.instance.client
          .from('missions')
          .select('id, technician_id, users!missions_technician_id_fkey(id, name, avatar_url, phone)')
          .eq('client_id', userId)
          .not('technician_id', 'is', null)
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      // 2. Récupérer les derniers messages pour toutes les missions
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
      Map<String, Map<String, dynamic>> technicianChats = {};

      for (var result in results) {
        final m = result['mission'] as Map<String, dynamic>;
        final missionId = m['id'] as String;
        final user = m['users'] as Map<String, dynamic>?;

        if (user == null) continue;
        final techId = user['id'];
        final msgData = result['msgData'] as List<dynamic>;

        if (msgData.isNotEmpty) {
          final latestMsg = msgData.first;
          final currentChat = technicianChats[techId];

          if (currentChat == null || DateTime.parse(latestMsg['created_at']).isAfter(DateTime.parse(currentChat['created_at']))) {
            technicianChats[techId] = {
              'mission_id': missionId,
              'technician_id': techId,
              'technician_name': user['name'] ?? 'Artisan',
              'technician_avatar': user['avatar_url'],
              'technician_phone': user['phone'] ?? '',
              'last_message': latestMsg['content'],
              'created_at': latestMsg['created_at'],
              'is_read': latestMsg['is_read'],
              'sender_id': latestMsg['sender_id'],
            };
          }
        }
      }

      List<Map<String, dynamic>> chats = technicianChats.values.toList();

      // 3. Récupérer le dernier message du support
      try {
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
            'technician_id': 'support',
            'technician_name': 'Support TechLink',
            'technician_avatar': null,
            'technician_phone': '',
            'last_message': latestAdminMsg['content'],
            'created_at': latestAdminMsg['created_at'],
            'is_read': latestAdminMsg['is_read'],
            'sender_id': latestAdminMsg['sender_id'],
            'mission_id': 'support',
          });
        }
      } catch (_) {}

      // Trier les discussions par date décroissante
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
          .select('id, technician_id, users!missions_technician_id_fkey(id, name, avatar_url, phone)')
          .eq('client_id', userId)
          .not('technician_id', 'is', null)
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

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
      Map<String, Map<String, dynamic>> technicianChats = {};

      for (var result in results) {
        final m = result['mission'] as Map<String, dynamic>;
        final missionId = m['id'] as String;
        final user = m['users'] as Map<String, dynamic>?;

        if (user == null) continue;
        final techId = user['id'];
        final msgData = result['msgData'] as List<dynamic>;

        if (msgData.isNotEmpty) {
          final latestMsg = msgData.first;
          technicianChats[techId] = {
            'mission_id': missionId,
            'technician_id': techId,
            'technician_name': user['name'] ?? 'Artisan',
            'technician_avatar': user['avatar_url'],
            'technician_phone': user['phone'] ?? '',
            'last_message': latestMsg['content'],
            'created_at': latestMsg['created_at'],
            'is_read': latestMsg['is_read'],
            'sender_id': latestMsg['sender_id'],
          };
        }
      }

      List<Map<String, dynamic>> newChats = technicianChats.values.toList();
      if (mounted) {
        setState(() {
          _chats.addAll(newChats);
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
      } else if (diff < 7) {
        const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        return days[date.weekday - 1];
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
        automaticallyImplyLeading: false,
        backgroundColor: tc.background,
        elevation: 0,
        centerTitle: false,
        title: _isSearching
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: tc.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un message...',
                    hintStyle: TextStyle(color: tc.textSecondary, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            : Row(
                children: [
                  Text(
                    'Messages',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.4,
                      color: tc.textPrimary,
                    ),
                  ),
                  if (_unreadTotal > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unreadTotal non lu${_unreadTotal > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: tc.textPrimary),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: tc.textPrimary,
            onPressed: _loadChats,
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredChats.isEmpty && _chats.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: tc.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun message pour « $_searchQuery »',
                        style: TextStyle(color: tc.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : _chats.isEmpty
                  ? _buildEmpty(tc, isDark)
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        itemCount: _filteredChats.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == _filteredChats.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final chat = _filteredChats[index];
                          return _buildChatItem(chat, tc, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, TechLinkColors tc, bool isDark) {
    final avatarUrl = chat['technician_avatar'] as String?;
    final name = chat['technician_name'] as String;
    final lastMessage = chat['last_message'] as String;
    final time = _formatTime(chat['created_at'] as String);

    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final isUnread = !(chat['is_read'] as bool? ?? true) && chat['sender_id'] != currentUserId;
    final isSupport = chat['is_support'] == true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252526) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withOpacity(0.4)
              : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
          width: isUnread ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            if (isSupport) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupportChatScreen(
                    conversationUserId: currentUserId,
                    currentUserId: currentUserId,
                    currentUserRole: 'client',
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
                    currentUserRole: 'client',
                    otherUserName: name,
                    otherUserPhone: chat['technician_phone'],
                  ),
                ),
              ).then((_) => _loadChats());
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar avec statut actif
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSupport
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSupport
                              ? const Color(0xFF60A5FA)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
                          width: 1.5,
                        ),
                        image: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: isSupport
                          ? const Center(child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 26))
                          : (avatarUrl == null || avatarUrl.isEmpty)
                              ? Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 19,
                                    ),
                                  ),
                                )
                              : null,
                    ),
                    if (!isSupport)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF252526) : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Contenu : Nom, dernier message et date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                      color: tc.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSupport) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'SUPPORT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2563EB),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isUnread ? AppColors.primary : tc.textSecondary,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: isUnread ? tc.textPrimary : tc.textSecondary,
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(TechLinkColors tc, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vos échanges avec les artisans et le support technique apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tc.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

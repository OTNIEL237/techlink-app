// =============================================================================
// FICHIER : admin_support_list_screen.dart
// RÔLE : Interface administrative de support client et messagerie directe
// MODULE : Présentation Administrateur (Admin Support)
// DÉPENDANCES : flutter/material.dart, supabase_flutter, timeago, app_colors.dart, theme_provider.dart, support_chat_screen.dart
// SÉCURITÉ / RLS : Réservé aux administrateurs (rôle admin requis)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../shared/support_chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Écran administrateur listant les conversations de support technique et l'annuaire des utilisateurs.
///
/// Permet à un administrateur d'assurer l'assistance directe aux clients et techniciens,
/// de suivre les messages non lus en temps réel et d'initier de nouvelles discussions.
class AdminSupportListScreen extends StatefulWidget {
  /// Constructeur par défaut de [AdminSupportListScreen].
  const AdminSupportListScreen({super.key});

  @override
  State<AdminSupportListScreen> createState() => _AdminSupportListScreenState();
}

/// État associé à [AdminSupportListScreen] gérant les onglets, la pagination et le flux Realtime Supabase.
class _AdminSupportListScreenState extends State<AdminSupportListScreen>
    with SingleTickerProviderStateMixin {
  /// Contrôleur gérant la bascule entre l'onglet Discussions et l'onglet Annuaire.
  late TabController _tabController;

  /// Index de l'onglet actif (0: Discussions, 1: Annuaire).
  int _currentTab = 0;

  /// Indicateur de chargement asynchrone des conversations actives.
  bool _isLoadingConversations = true;

  /// Indicateur de chargement asynchrone de l'annuaire d'utilisateurs.
  bool _isLoadingDirectory = true;

  /// Liste des dernières conversations consolidées par utilisateur.
  List<Map<String, dynamic>> _conversations = [];

  /// Annuaire complet des utilisateurs (clients et techniciens).
  List<Map<String, dynamic>> _allUsers = [];

  /// Requête de filtrage textuel appliquée à l'annuaire.
  String _searchDirectoryQuery = '';

  /// Canal d'écoute temps réel Supabase pour les nouveaux messages entrants.
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadConversations();
    _loadDirectory();
    _subscribeToNewMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  /// Récupère les derniers messages de la table `admin_messages` et regroupe
  /// les échanges par utilisateur afin d'afficher le fil le plus récent.
  Future<void> _loadConversations() async {
    try {
      final data = await Supabase.instance.client
          .from('admin_messages')
          .select('*, users!user_id(id, name, role)')
          .order('created_at', ascending: false)
          .limit(1000);

      final Map<String, Map<String, dynamic>> grouped = {};

      for (var msg in data) {
        final userId = msg['user_id'] as String;
        if (!grouped.containsKey(userId)) {
          grouped[userId] = msg;
        }
      }

      final conversations = List<Map<String, dynamic>>.from(grouped.values);
      conversations.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoadingConversations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConversations = false);
      }
    }
  }

  /// Charge l'annuaire de tous les clients et techniciens enregistrés sur la plateforme.
  Future<void> _loadDirectory() async {
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('id, name, role')
          .inFilter('role', ['client', 'technician'])
          .order('name');

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(data);
          _isLoadingDirectory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDirectory = false);
      }
    }
  }

  /// Initialise la souscription temps réel Supabase sur la table `admin_messages`
  /// pour rafraîchir instantanément la liste des conversations lors d'un message reçu.
  void _subscribeToNewMessages() {
    _channel = Supabase.instance.client
        .channel('admin-messages-list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'admin_messages',
          callback: (payload) {
            _loadConversations();
          },
        )
        .subscribe();
  }

  /// Ouvre l'écran de messagerie instantanée [SupportChatScreen] avec l'utilisateur spécifié.
  ///
  /// [userId] : Identifiant Supabase de l'utilisateur concerné.
  /// [userName] : Nom d'affichage de l'utilisateur.
  void _openChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupportChatScreen(
          conversationUserId: userId,
          currentUserId: Supabase.instance.client.auth.currentUser!.id,
          currentUserRole: 'admin',
          otherUserName: userName,
        ),
      ),
    ).then((_) {
      _loadConversations();
    });
  }


  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: isDark ? tc.surface : Colors.white,
                border: Border(bottom: BorderSide(color: tc.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0EA5E9).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Support & Messages',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: tc.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Assistance directe aux utilisateurs',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rafraîchir',
                        icon: Icon(Icons.refresh_rounded, color: tc.textSecondary),
                        onPressed: () {
                          setState(() {
                            _isLoadingConversations = true;
                            _isLoadingDirectory = true;
                          });
                          _loadConversations();
                          _loadDirectory();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Modern Segmented Pill Switcher
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? tc.background : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tc.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _tabController.animateTo(0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _currentTab == 0 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentTab == 0
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.forum_rounded,
                                    size: 16,
                                    color: _currentTab == 0 ? Colors.white : tc.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Discussions (${_conversations.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _currentTab == 0 ? FontWeight.bold : FontWeight.w500,
                                      color: _currentTab == 0 ? Colors.white : tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _tabController.animateTo(1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _currentTab == 1 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentTab == 1
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.contacts_rounded,
                                    size: 16,
                                    color: _currentTab == 1 ? Colors.white : tc.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Annuaire (${_allUsers.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _currentTab == 1 ? FontWeight.bold : FontWeight.w500,
                                      color: _currentTab == 1 ? Colors.white : tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildConversationsView(tc, isDark),
                  _buildDirectoryView(tc, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la vue de la liste des conversations récentes avec aperçu du dernier message et badge non lu.
  Widget _buildConversationsView(TechLinkColors tc, bool isDark) {
    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_read_rounded, size: 56, color: tc.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'Aucune discussion active',
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Les demandes d\'aide des utilisateurs apparaîtront ici.',
              style: TextStyle(color: tc.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final convo = _conversations[index];
        final user = convo['users'];
        final userName = (user?['name'] as String?)?.trim() ?? 'Utilisateur';
        final role = user?['role'] == 'client' ? 'Client' : 'Technicien';
        final isClient = user?['role'] == 'client';
        final lastMsg = convo['content'] as String? ?? '';
        final isUnread = !(convo['is_read'] as bool? ?? true) &&
            convo['sender_id'] != Supabase.instance.client.auth.currentUser!.id;
        final dateStr = convo['created_at'] as String?;
        String timeAgoStr = '';
        if (dateStr != null) {
          try {
            final date = DateTime.parse(dateStr).toLocal();
            timeAgoStr = timeago.format(date, locale: 'fr');
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? tc.card : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withOpacity(0.4)
                  : tc.border,
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openChat(user?['id'] ?? '', userName),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Avatar with status
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isClient
                              ? const Color(0xFF3B82F6).withOpacity(0.15)
                              : const Color(0xFF10B981).withOpacity(0.15),
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isClient ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? tc.card : Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Info Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 15,
                                    color: tc.textPrimary,
                                  ),
                                ),
                              ),
                              if (timeAgoStr.isNotEmpty)
                                Text(
                                  timeAgoStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isUnread ? AppColors.primary : tc.textSecondary,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Role badge + Message preview
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isClient
                                      ? const Color(0xFF3B82F6).withOpacity(0.12)
                                      : const Color(0xFF10B981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    color: isClient ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lastMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isUnread ? tc.textPrimary : tc.textSecondary,
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  /// Construit la vue de l'annuaire des utilisateurs permettant la recherche et le lancement de nouvelles discussions.
  Widget _buildDirectoryView(TechLinkColors tc, bool isDark) {
    if (_isLoadingDirectory) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _allUsers.where((u) {
      final name = (u['name'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchDirectoryQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Directory search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.border),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchDirectoryQuery = val),
              style: TextStyle(color: tc.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                hintStyle: TextStyle(color: tc.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: tc.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Aucun utilisateur correspondant.',
                    style: TextStyle(color: tc.textSecondary, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final u = filtered[index];
                    final name = (u['name'] as String?)?.trim() ?? 'Utilisateur';
                    final isClient = u['role'] == 'client';
                    final roleLabel = isClient ? 'Client' : 'Technicien';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? tc.card : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tc.border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isClient
                              ? const Color(0xFF3B82F6).withOpacity(0.15)
                              : const Color(0xFF10B981).withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isClient ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tc.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          roleLabel,
                          style: TextStyle(color: tc.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                          onPressed: () => _openChat(u['id'] ?? '', name),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

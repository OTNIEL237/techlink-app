import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';

// =========================================================================
// ÉCRAN MODERNE DES NOTIFICATIONS (Personnel & Broadcasts)
// =========================================================================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Toutes', 'Non lues', 'Missions', 'Messages'];

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 1. Récupérer le rôle de l'utilisateur pour les broadcasts
      final userRoleResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final userRole = userRoleResponse['role'];

      // 2. Récupérer les notifications réelles
      final notificationsResponse = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      // 3. Récupérer les broadcasts récents
      final audiences = ['all'];
      if (userRole == 'client') audiences.add('clients');
      if (userRole == 'technician') audiences.add('technicians');

      final broadcastsResponse = await Supabase.instance.client
          .from('broadcasts')
          .select('id, title, message, created_at, target_audience')
          .eq('is_active', true)
          .inFilter('target_audience', audiences)
          .order('created_at', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> combined = [];

      // 4. Traitement des notifications personnelles
      for (var notif in notificationsResponse) {
        IconData icon = Icons.notifications_rounded;
        Color color = AppColors.primary;

        final type = notif['type']?.toString().toLowerCase() ?? '';
        if (type.contains('mission')) {
          icon = Icons.assignment_rounded;
          color = const Color(0xFF2563EB);
        } else if (type.contains('message') || type.contains('chat')) {
          icon = Icons.chat_bubble_rounded;
          color = const Color(0xFF7C3AED);
        } else if (type.contains('payment') || type.contains('paiement')) {
          icon = Icons.check_circle_rounded;
          color = const Color(0xFF059669);
        } else if (type.contains('system') || type.contains('alert')) {
          icon = Icons.info_rounded;
          color = const Color(0xFFD97706);
        }

        combined.add({
          'id': notif['id'],
          'type': notif['type'] ?? 'system',
          'title': notif['title'] ?? 'Notification',
          'body': notif['body'] ?? '',
          'date': DateTime.parse(notif['created_at']),
          'icon': icon,
          'color': color,
          'mission_id': notif['data'] != null ? notif['data']['mission_id'] : null,
          'action': notif['data'] != null ? notif['data']['action'] : null,
          'is_read': notif['is_read'] ?? false,
        });
      }

      // 5. Traitement des broadcasts
      for (var broadcast in broadcastsResponse) {
        combined.add({
          'id': broadcast['id'],
          'type': 'broadcast',
          'title': broadcast['title'],
          'body': broadcast['message'],
          'date': DateTime.parse(broadcast['created_at']),
          'icon': Icons.campaign_rounded,
          'color': const Color(0xFF2563EB),
          'mission_id': null,
          'is_read': true,
        });
      }

      // 6. Trier par date décroissante
      combined.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      if (mounted) {
        setState(() {
          _notifications = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);

      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          for (var n in _notifications) {
            n['is_read'] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications sont marquées comme lues'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilterIndex == 1) {
      // Non lues
      return _notifications.where((n) => !(n['is_read'] as bool? ?? true)).toList();
    } else if (_selectedFilterIndex == 2) {
      // Missions
      return _notifications.where((n) => (n['type'] as String? ?? '').contains('mission')).toList();
    } else if (_selectedFilterIndex == 3) {
      // Messages
      return _notifications.where((n) => (n['type'] as String? ?? '').contains('message')).toList();
    }
    return _notifications;
  }

  int get _unreadCount {
    return _notifications.where((n) => !(n['is_read'] as bool? ?? true)).length;
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemsToDisplay = _filteredNotifications;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                color: tc.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.4,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
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
        iconTheme: IconThemeData(color: tc.textPrimary),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              color: AppColors.primary,
              tooltip: 'Tout marquer comme lu',
              onPressed: _markAllAsRead,
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Tout supprimer',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Tout supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('Voulez-vous vraiment effacer toutes vos notifications ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    setState(() => _isLoading = true);
                    final userId = Supabase.instance.client.auth.currentUser!.id;
                    await Supabase.instance.client
                        .from('notifications')
                        .delete()
                        .eq('user_id', userId);
                    await _loadNotifications();
                  } catch (e) {
                    setState(() => _isLoading = false);
                  }
                }
              },
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, idx) {
                final isSelected = _selectedFilterIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilterIndex = idx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF252526) : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        _filters[idx],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : tc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : itemsToDisplay.isEmpty
              ? _buildEmpty(tc, isDark)
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: itemsToDisplay.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = itemsToDisplay[index];
                      return _buildNotificationCard(item, tc, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item, TechLinkColors tc, bool isDark) {
    final date = item['date'] as DateTime;
    final timeAgo = timeago.format(date, locale: 'fr');
    final isUnread = !(item['is_read'] as bool? ?? true);
    final color = item['color'] as Color? ?? AppColors.primary;
    final icon = item['icon'] as IconData? ?? Icons.notifications_rounded;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252526) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? color.withOpacity(0.5)
              : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
          width: isUnread ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            HapticFeedback.lightImpact();

            // Marquer comme lu
            if (item['type'] != 'broadcast' && isUnread) {
              try {
                await Supabase.instance.client
                    .from('notifications')
                    .update({'is_read': true})
                    .eq('id', item['id']);

                if (mounted) {
                  setState(() {
                    item['is_read'] = true;
                  });
                }
              } catch (_) {}
            }

            // Gérer les notifications systèmes admin
            if (item['type'] == 'system' && item['action'] != null) {
              if (item['action'] == 'validation') {
                context.go('/admin/home');
              }
              return;
            }

            if (item['mission_id'] == null) return;

            try {
              final mission = await Supabase.instance.client
                  .from('missions')
                  .select('*, client:users!missions_client_id_fkey(name, phone), technician:users!missions_technician_id_fkey(name, phone)')
                  .eq('id', item['mission_id'])
                  .single();

              final currentUserId = Supabase.instance.client.auth.currentUser!.id;
              final role = currentUserId == mission['client_id'] ? 'client' : 'technician';

              if (item['type'] == 'message') {
                final otherUser = role == 'client' ? mission['technician'] : mission['client'];
                context.push('/chat', extra: {
                  'mission_id': mission['id'],
                  'current_user_id': currentUserId,
                  'current_user_role': role,
                  'other_user_name': otherUser != null ? otherUser['name'] : 'Utilisateur',
                  'other_user_phone': otherUser != null ? otherUser['phone'] : '',
                });
              } else {
                if (role == 'technician') {
                  context.push('/technician/mission-request', extra: {'mission': mission});
                } else {
                  context.push('/client/tracking', extra: {'mission': mission});
                }
              }
            } catch (_) {}
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône avec badge de couleur
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),

                // Contenu : Titre, Corps et Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['title'] ?? 'Notification',
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 14.5,
                                color: tc.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['body'] ?? '',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isUnread ? tc.textPrimary.withOpacity(0.9) : tc.textSecondary,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: tc.textSecondary.withOpacity(0.7),
                        ),
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
              child: const Icon(Icons.notifications_off_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune notification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilterIndex > 0
                  ? 'Aucune notification ne correspond à ce filtre.'
                  : 'Vous êtes à jour ! Vos alertes de missions, paiements et messages s\'afficheront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tc.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

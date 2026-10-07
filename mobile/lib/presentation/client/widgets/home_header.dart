// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : home_header.dart
// Rôle          : En-tête personnalisé de l'écran d'accueil client affichant l'avatar,
//                 la salutation avec le nom et la cloche de notification temps réel.
// Module        : Présentation Client (Widgets Accueil)
// Dépendances   : flutter/material.dart, cached_network_image, supabase_flutter,
//                 go_router, app_colors.dart, theme_provider.dart
// Sécurité/RLS  : Écoute en temps réel du flux de notifications filtré par RLS.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';

/// En-tête supérieur affichant le profil de l'utilisateur et l'accès aux notifications.
class ClientHomeHeader extends StatelessWidget {
  /// Données du profil utilisateur (nom, avatar, etc.)
  final Map<String, dynamic>? userData;

  /// Thème de couleurs personnalisé de l'application
  final TechLinkColors tc;

  /// Indique si l'application est en mode sombre
  final bool isDark;

  /// Constructeur constant de l'en-tête d'accueil client
  const ClientHomeHeader({
    super.key,
    required this.userData,
    required this.tc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final userName = userData?['name'] as String? ?? 'Client';

    final topInset = MediaQuery.of(context).padding.top;
    final safeTop = (topInset > 0 ? topInset : 24.0) + 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, safeTop, 22, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            backgroundImage: userData?['avatar_url'] != null
                ? CachedNetworkImageProvider(userData!['avatar_url'])
                : null,
            child: userData?['avatar_url'] == null
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bonjour 👋', style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  userName,
                  style: TextStyle(color: tc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cloche de notification avec badge en temps réel
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/notifications');
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252526) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_outlined, color: tc.textPrimary, size: 22),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('notifications')
                          .stream(primaryKey: ['id'])
                          .map((events) => events.where((e) => e['is_read'] == false).toList()),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data?.length ?? 0;
                        if (unreadCount == 0) return const SizedBox.shrink();
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

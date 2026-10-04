import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Service centralisé de gestion des notifications TechLink
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;
  RealtimeChannel? _notificationsChannel;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isListening = false;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    // Écouter les changements de session Supabase
    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _subscribeToNotifications(session.user.id);
        // Demander la permission notification après un court délai pour une bonne UX
        Future.delayed(const Duration(seconds: 2), () {
          checkAndRequestPermission();
        });
      } else {
        _unsubscribeFromNotifications();
      }
    });

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _subscribeToNotifications(currentUser.id);
      Future.delayed(const Duration(seconds: 2), () {
        checkAndRequestPermission();
      });
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromNotifications();
  }

  /// Demande la permission système des notifications
  Future<bool> checkAndRequestPermission({bool forcePrompt = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAskedBefore = prefs.getBool('has_asked_notification_permission') ?? false;

      // Si déjà refusé et pas forcé par l'utilisateur, ne pas harceler
      if (hasAskedBefore && !forcePrompt) {
        final currentStatus = await Permission.notification.status;
        return currentStatus.isGranted;
      }

      // Demander la permission système (Android 13+ / iOS)
      final status = await Permission.notification.request();
      await prefs.setBool('has_asked_notification_permission', true);

      if (status.isGranted) {
        debugPrint('🔔 [NotificationService] Permission notifications accordée.');
        return true;
      } else if (status.isPermanentlyDenied && forcePrompt) {
        // Si l'utilisateur clique explicitement pour activer depuis les réglages
        _showOpenSettingsDialog();
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Erreur lors de la demande de permission: $e');
      return false;
    }
  }

  /// Vérifie si les notifications sont actuellement autorisées
  Future<bool> isPermissionGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Affiche une boîte de dialogue invitant à ouvrir les réglages système
  void _showOpenSettingsDialog() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications désactivées'),
        content: const Text(
          'Les notifications sont nécessaires pour recevoir les alertes de missions, '
          'les messages des correspondants et les informations urgentes. '
          'Veuillez les activer dans les paramètres de votre appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Ouvrir les réglages', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// S'abonne aux notifications Supabase en temps réel
  void _subscribeToNotifications(String userId) {
    if (_isListening) return;
    _unsubscribeFromNotifications();

    debugPrint('🔔 [NotificationService] Écoute des notifications en temps réel pour $userId');
    _isListening = true;

    _notificationsChannel = Supabase.instance.client
        .channel('user-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final title = record['title'] as String? ?? 'Nouvelle notification';
            final body = record['body'] as String? ?? '';
            final type = record['type'] as String? ?? 'system';
            final data = record['data'] as Map<String, dynamic>?;

            showInAppNotification(
              title: title,
              body: body,
              type: type,
              data: data,
            );
          },
        )
        .subscribe();
  }

  void _unsubscribeFromNotifications() {
    _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
    _isListening = false;
  }

  /// Affiche une bannière flottante élégante (Heads-up banner) dans l'application
  void showInAppNotification({
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic>? data,
  }) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    IconData icon = Icons.notifications;
    Color iconColor = AppColors.primary;

    if (type == 'mission') {
      icon = Icons.assignment_turned_in;
      iconColor = Colors.blue;
    } else if (type == 'message') {
      icon = Icons.chat_bubble_outline;
      iconColor = const Color(0xFF8B5CF6);
    } else if (type == 'warning') {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orange;
    }

    overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                overlayEntry.remove();
                _handleNotificationTap(type, data);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            body,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () {
                        try {
                          overlayEntry.remove();
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    // Auto-fermeture après 4 secondes
    Future.delayed(const Duration(seconds: 4), () {
      try {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      } catch (_) {}
    });
  }

  void _handleNotificationTap(String type, Map<String, dynamic>? data) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    if (type == 'message' && data != null && data['mission_id'] != null) {
      context.push('/chat', extra: {
        'mission_id': data['mission_id'],
        'current_user_id': Supabase.instance.client.auth.currentUser?.id ?? '',
        'current_user_role': 'client',
        'other_user_name': data['sender_name'] ?? 'Correspondant',
      });
    } else if (type == 'mission' && data != null && data['mission_id'] != null) {
      context.push('/client/tracking', extra: {'mission': data});
    } else {
      context.push('/notifications');
    }
  }

  /// Déclenche une notification de test immédiate
  void triggerTestNotification() {
    showInAppNotification(
      title: '🔔 Test TechLink',
      body: 'Les notifications sont bien actives et configurées avec succès !',
      type: 'system',
    );
  }
}

// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : notification_service.dart
// Rôle          : Service centralisé des notifications système, permissions et bannières in-app.
// Module        : Data / Services
// Dépendances   : go_router, permission_handler, shared_preferences, supabase_flutter, app_colors.dart
// Sécurité/RLS  : Écoute en temps réel Supabase Realtime Postgres Changes filtrée par user_id.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Service singleton orchestrant l'écoute, les autorisations et l'affichage des notifications.
///
/// Intègre :
/// - La demande progressive des autorisations du système d'exploitation (Android 13+ et iOS).
/// - L'abonnement aux événements en temps réel via Supabase Realtime (`notifications` table).
/// - L'affichage de bannières flottantes in-app (Heads-up banner) personnalisées.
/// - La navigation contextuelle au toucher d'une alerte (vers le chat, le tracking ou l'historique).
class NotificationService {
  /// Instance unique du singleton.
  static final NotificationService _instance = NotificationService._internal();

  /// Constructeur usine renvoyant l'instance partagée.
  factory NotificationService() => _instance;

  /// Constructeur interne privé.
  NotificationService._internal();

  /// Clé globale de navigation permettant d'accéder au contexte applicatif depuis n'importe où.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Canal Supabase Realtime actif pour les notifications de l'utilisateur.
  RealtimeChannel? _notificationsChannel;

  /// Souscription au flux d'authentification pour attacher/détacher l'écouteur.
  StreamSubscription<AuthState>? _authSubscription;

  /// Indicateur d'écoute active pour éviter les abonnements en doublon.
  bool _isListening = false;

  /// Initialise le service avec la clé de navigation globale de l'application.
  ///
  /// Met en place l'observation des sessions de connexion pour souscrire automatiquement
  /// aux notifications dès qu'un utilisateur est authentifié.
  ///
  /// [navigatorKey] Clé globale associée au [GoRouter] ou [Navigator].
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

  /// Libère les ressources, ferme les flux et désabonne les canaux temps réel.
  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromNotifications();
  }

  /// Vérifie et sollicite poliment l'autorisation système d'afficher des notifications.
  ///
  /// Sauvegarde le refus dans [SharedPreferences] pour ne pas importuner l'utilisateur à répétition,
  /// sauf si [forcePrompt] est explicite (ex: clic sur un bouton d'activation dans les paramètres).
  ///
  /// [forcePrompt] Force l'affichage ou l'invitation à ouvrir les réglages système.
  /// Retourne vrai si l'autorisation est accordée.
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

  /// Détermine si l'application possède actuellement la permission système d'envoyer des notifications.
  Future<bool> isPermissionGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Affiche une boîte de dialogue incitant l'utilisateur à activer les notifications dans les réglages système.
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

  /// Établit une souscription WebSocket temps réel à la table `notifications` pour un utilisateur donné.
  ///
  /// [userId] Identifiant de l'utilisateur concerné.
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

  /// Annule la souscription active au canal de notifications.
  void _unsubscribeFromNotifications() {
    _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
    _isListening = false;
  }

  /// Génère une bannière flottante élégante (Overlay Entry) en haut de l'écran.
  ///
  /// La bannière s'efface automatiquement après 4 secondes ou au toucher,
  /// et déclenche la navigation appropriée via [_handleNotificationTap].
  ///
  /// [title] Titre de la notification.
  /// [body] Message succinct.
  /// [type] Catégorie de notification ('mission', 'message', 'warning', 'system').
  /// [data] Métadonnées associées à la charge utile.
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

  /// Gère l'action de redirection lorsqu'une notification est touchée par l'utilisateur.
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

  /// Déclenche une notification de test immédiate pour valider le bon fonctionnement de l'interface.
  void triggerTestNotification() {
    showInAppNotification(
      title: '🔔 Test TechLink',
      body: 'Les notifications sont bien actives et configurées avec succès !',
      type: 'system',
    );
  }
}

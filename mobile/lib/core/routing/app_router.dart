// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : app_router.dart
// Rôle          : Configuration centrale du routage avec GoRouter.
//                 Gère la navigation déclarative, les transitions animées,
//                 l'écoute réactive des sessions Supabase Auth et les Route
//                 Guards stricts pour cloisonner les rôles (client, technicien, admin).
// Module        : Core / Routage & Navigation
// Dépendances   : GoRouter, Supabase, Flutter Material
// Sécurité/RLS  : Cloisonnement strict des espaces /admin, /technician et /client
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── IMPORTATION DES ÉCRANS PAR DOMAINE ──
import '../../presentation/admin/admin_home_screen.dart';
import '../../presentation/admin/technician_detail_screen.dart';
import '../../presentation/admin/technician_validation_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/otp_screen.dart';
import '../../presentation/auth/phone_input_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/client/ai_solution_screen.dart';
import '../../presentation/client/home_screen.dart';
import '../../presentation/client/client_transactions_screen.dart';
import '../../presentation/client/mission_history_screen.dart';
import '../../presentation/client/mission_tracking_screen.dart';
import '../../presentation/client/payment_screen.dart';
import '../../presentation/client/problem_input_screen.dart';
import '../../presentation/client/profile/edit_profile_screen.dart';
import '../../presentation/client/profile/notification_settings_screen.dart';
import '../../presentation/client/profile/security_screen.dart';
import '../../presentation/client/technician_profile_screen.dart';
import '../../presentation/client/technicians_map_screen.dart';
import '../../presentation/shared/audio_call_screen.dart';
import '../../presentation/shared/video_call_screen.dart';
import '../../presentation/shared/call_history_screen.dart';
import '../../presentation/shared/chat_screen.dart';
import '../../presentation/shared/incoming_call_screen.dart';
import '../../presentation/shared/notifications_screen.dart';
import '../../presentation/shared/payment_webview_screen.dart';
import '../../presentation/shared/splash_screen.dart';
import '../../presentation/auth/subscription_selection_screen.dart';
import '../../presentation/technician/earnings_screen.dart';
import '../../presentation/technician/mission_request_screen.dart';
import '../../presentation/technician/pending_validation_screen.dart';
import '../../presentation/technician/profile/technician_edit_profile_screen.dart';
import '../../presentation/technician/profile/technician_subscription_screen.dart';
import '../../presentation/technician/home_screen.dart' as tech;
import '../../presentation/technician/technician_messages_list_screen.dart';
import '../../presentation/technician/onboarding_screen.dart';
import '../../presentation/technician/availability_toggle_screen.dart';
import 'dart:async';


import '../../presentation/shared/not_found_screen.dart';
import '../animations/morph_transitions.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// Écouteur réactif pour GoRouter sur les changements d'état d'authentification Supabase
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Cache en mémoire pour le rôle utilisateur afin d'éviter de requêter Supabase à chaque changement de route
String? _cachedUserId;
String? _cachedUserRole;
String? _cachedValidationStatus;

class AppRouter {
  /// Indique si l'utilisateur est actuellement en train de soumettre son inscription.
  /// Empêche GoRouter d'interrompre le formulaire avec une redirection prématurée.
  static bool isRegistering = false;

  static void clearRoleCache() {
    _cachedUserId = null;
    _cachedUserRole = null;
    _cachedValidationStatus = null;
  }

  static void setCachedRole(String userId, String role, {String? validationStatus}) {
    _cachedUserId = userId;
    _cachedUserRole = role;
    if (validationStatus != null) {
      _cachedValidationStatus = validationStatus;
    }
    debugPrint('[ROUTAGE] Mise en cache du rôle pour $userId : rôle=$role, statut=$validationStatus');
  }

  static Future<String?> resolveUserRole(SupabaseClient supabase, User user) async {
    if (_cachedUserId == user.id && _cachedUserRole != null) {
      debugPrint('[ROUTAGE] Rôle en cache trouvé pour ${user.id} : $_cachedUserRole');
      return _cachedUserRole;
    }

    // 1. Métadonnées auth Supabase (disponibles immédiatement dès le signUp)
    final metaRole = user.userMetadata?['role'] as String?;

    // 2. Table users
    try {
      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final dbRole = userData?['role'] as String?;
      final effectiveRole = dbRole ?? metaRole ?? 'client';
      _cachedUserId = user.id;
      _cachedUserRole = effectiveRole;
      debugPrint('[ROUTAGE] Rôle résolu pour ${user.id} : $effectiveRole (DB: $dbRole, Meta: $metaRole)');
      return effectiveRole;
    } catch (e) {
      final effectiveRole = metaRole ?? 'client';
      _cachedUserId = user.id;
      _cachedUserRole = effectiveRole;
      debugPrint('[ROUTAGE] Avertissement lecture table users ($e). Rôle de repli appliqué : $effectiveRole');
      return effectiveRole;
    }
  }

  static Future<String> resolveTechnicianStatus(SupabaseClient supabase, String userId) async {
    if (_cachedUserId == userId && _cachedValidationStatus != null) {
      debugPrint('[ROUTAGE] Statut technicien en cache pour $userId : $_cachedValidationStatus');
      return _cachedValidationStatus!;
    }
    try {
      final tech = await supabase
          .from('technicians')
          .select('validation_status')
          .eq('user_id', userId)
          .maybeSingle();
      if (tech == null) {
        debugPrint('[ROUTAGE] Aucun profil dans technicians pour $userId -> statut "none"');
        return 'none';
      }
      final status = (tech['validation_status'] as String?) ?? 'pending';
      _cachedValidationStatus = status;
      debugPrint('[ROUTAGE] Statut technicien résolu pour $userId : $status');
      return status;
    } catch (e) {
      debugPrint('[ROUTAGE] Erreur lecture statut technicien ($e) -> repli "pending"');
      return 'pending';
    }
  }

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    errorBuilder: (context, state) => const NotFoundScreen(),
    // Route Guards : Vérifie l'authentification et le rôle de manière réactive
    redirect: (context, state) async {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final path = state.uri.path;

      final isAuthRoute = path == '/' || path == '/phone' || path == '/login' || path == '/otp' || path == '/register';

      // 1. Si NON CONNECTÉ et essaie d'accéder à une page protégée
      if (session == null) {
        clearRoleCache();
        if (!isAuthRoute) {
          debugPrint('[ROUTAGE-GUARD] Utilisateur non connecté sur route protégée ($path) -> Redirection /login');
          return '/login'; // Redirection automatique vers login
        }
        return null;
      }

      // 2. Si une inscription est en cours de soumission, ne JAMAIS couper le formulaire
      if (isRegistering) {
        debugPrint('[ROUTAGE-GUARD] Inscription en cours, navigation autorisée sur : $path');
        return null;
      }

      // 3. Résolution du rôle
      final role = await resolveUserRole(supabase, session.user);

      // Si l'utilisateur est sur /register et que le profil est en cours de création
      if (path == '/register') {
        if (role == null) {
          return null;
        }
      }

      // 4. Si CONNECTÉ et sur une page auth (autre que le splash screen '/')
      if (isAuthRoute && path != '/') {
        if (role == 'admin') {
          debugPrint('[ROUTAGE-GUARD] Connecté en tant qu\'admin sur $path -> Redirection /admin/home');
          return '/admin/home';
        }
        if (role == 'technician') {
          final status = await resolveTechnicianStatus(supabase, session.user.id);
          debugPrint('[ROUTAGE-GUARD] Connecté en tant que technicien (statut: $status) sur $path');
          if (status == 'approved') return '/technician/home';
          if (status == 'pending') return '/technician/pending';
          return '/technician/onboarding';
        }
        if (role == 'client') {
          debugPrint('[ROUTAGE-GUARD] Connecté en tant que client sur $path -> Redirection /client/home');
          return '/client/home';
        }
        return null;
      }

      // 5. Vérification et cloisonnement strict des rôles pour les espaces protégés
      if (role == null) {
        return null;
      }

      // Protection Espace ADMIN
      if (path.startsWith('/admin')) {
        if (role != 'admin') {
          if (role == 'technician') {
            final status = await resolveTechnicianStatus(supabase, session.user.id);
            return status == 'approved' ? '/technician/home' : '/technician/pending';
          }
          return '/client/home';
        }
      }

      // Protection Espace TECHNICIEN
      if (path.startsWith('/technician')) {
        if (role != 'technician' && role != 'admin') {
          return '/client/home';
        }
        if (role == 'technician') {
          final status = await resolveTechnicianStatus(supabase, session.user.id);
          // Si statut pas encore approuvé et essaie d'accéder au tableau de bord des missions
          if (path == '/technician/home' && status != 'approved') {
            return '/technician/pending';
          }
        }
      }

      // Protection Espace CLIENT : un technicien ne doit jamais atterrir sur le dashboard client
      if (path.startsWith('/client')) {
        if (role == 'technician') {
          final status = await resolveTechnicianStatus(supabase, session.user.id);
          return status == 'approved' ? '/technician/home' : '/technician/pending';
        }
      }

      return null;
    },
    routes: [
      // ==========================================
      // 1. ROUTES COMMUNES (Auth, Splash, Paiement)
      // ==========================================
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/phone',
        pageBuilder: (context, state) => PowerPointMorphPage(
          key: state.pageKey,
          child: const PhoneInputScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => PowerPointMorphPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/otp',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return PowerPointMorphPage(
            key: state.pageKey,
            child: OtpScreen(
              phone: args['phone'] as String? ?? '',
              role: args['role'] as String? ?? 'client',
            ),
          );
        },
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => PowerPointMorphPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/subscription/select',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return SubscriptionSelectionScreen(
            technicianId: args['technicianId'],
            technicianName: args['name'] ?? '',
            technicianEmail: args['email'],
            technicianPhone: args['phone'],
          );
        },
      ),
      GoRoute(
        path: '/payment/webview',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return PaymentWebViewScreen(
            url: args['url'],
            title: args['title'] ?? 'Paiement TechLink',
            reference: args['reference'],
            type: args['type'],
          );
        },
      ),

      // ==========================================
      // 2. ROUTES ADMINISTRATEUR
      // ==========================================
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/admin/validation',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return TechnicianValidationScreen(
            filter: args['filter'] ?? 'pending',
          );
        },
      ),
      GoRoute(
        path: '/admin/technician-detail',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return TechnicianDetailScreen(
            technician: args['technician'],
          );
        },
      ),

      // ==========================================
      // 3. ROUTES CLIENT
      // ==========================================
      GoRoute(
        path: '/client/home',
        pageBuilder: (context, state) => PowerPointMorphPage(
          key: state.pageKey,
          child: const ClientHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/client/problem',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return PowerPointMorphPage(
            key: state.pageKey,
            child: ProblemInputScreen(
              preselectedCategory: args?['category'],
              initialProblem: args?['query'],
              autofocus: args?['autofocus'] == true,
              startVoice: args?['voice'] == true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/client/ai-solution',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return AiSolutionScreen(
            problem: args['problem'],
            photos: args['photos'] ?? [],
            aiResult: args['ai_result'],
          );
        },
      ),
      GoRoute(
        path: '/client/map',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return TechniciansMapScreen(
            missionId: args['mission_id'] ?? '',
            aiResult: args['ai_result'] ?? {},
          );
        },
      ),
      GoRoute(
        path: '/client/history',
        builder: (context, state) => const MissionHistoryScreen(),
      ),
      GoRoute(
        path: '/client/technician-profile',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return TechnicianProfileScreen(
            technician: args['technician'],
            missionId: args['missionId'],
          );
        },
      ),
      GoRoute(
        path: '/client/tracking',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return MissionTrackingScreen(
            mission: args['mission'],
          );
        },
      ),
      GoRoute(
        path: '/client/payment',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return PaymentScreen(
            mission: args['mission'],
            quote: args['quote'],
          );
        },
      ),
      GoRoute(
        path: '/client/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/client/profile/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/client/profile/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/client/transactions',
        builder: (context, state) => const ClientTransactionsScreen(),
      ),

      // ==========================================
      // 4. ROUTES TECHNICIEN
      // ==========================================
      GoRoute(
        path: '/technician/home',
        pageBuilder: (context, state) => PowerPointMorphPage(
          key: state.pageKey,
          child: const tech.TechnicianHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/technician/onboarding',
        builder: (context, state) => const TechnicianOnboardingScreen(),
      ),
      GoRoute(
        path: '/technician/profile/edit',
        builder: (context, state) => const TechnicianEditProfileScreen(),
      ),
      GoRoute(
        path: '/technician/profile/subscription',
        builder: (context, state) => const TechnicianSubscriptionScreen(),
      ),
      GoRoute(
        path: '/technician/pending',
        builder: (context, state) => const PendingValidationScreen(),
      ),
      GoRoute(
        path: '/technician/mission-request',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return MissionRequestScreen(
            mission: args['mission'],
          );
        },
      ),
      GoRoute(
        path: '/technician/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: '/technician/messages',
        builder: (context, state) => const TechnicianMessagesListScreen(),
      ),
      GoRoute(
        path: '/technician/availability',
        builder: (context, state) => const AvailabilityToggleScreen(),
      ),

      // ==========================================
      // 5. ROUTES CHAT ET APPELS
      // ==========================================
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            missionId: args['mission_id'],
            currentUserId: args['current_user_id'],
            currentUserRole: args['current_user_role'],
            otherUserName: args['other_user_name'],
            otherUserPhone: args['other_user_phone'],
          );
        },
      ),
      GoRoute(
        path: '/call',
        builder: (context, state) => const AudioCallScreen(),
      ),
      GoRoute(
        path: '/call/audio',
        builder: (context, state) => const AudioCallScreen(),
      ),
      GoRoute(
        path: '/call/video',
        builder: (context, state) => const VideoCallScreen(),
      ),
      GoRoute(
        path: '/call/incoming',
        builder: (context, state) => const IncomingCallScreen(),
      ),
      GoRoute(
        path: '/call/history',
        builder: (context, state) => const CallHistoryScreen(),
      ),
    ],
  );
}

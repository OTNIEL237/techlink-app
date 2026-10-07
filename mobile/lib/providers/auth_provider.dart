// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : auth_provider.dart
// Rôle          : Fournisseurs d'état Riverpod pour l'authentification et l'identité utilisateur.
// Module        : Providers (Gestion d'état global)
// Dépendances   : flutter_riverpod, riverpod_annotation, supabase_flutter, app_router.dart
// Sécurité/RLS  : Écoute les sessions Supabase Auth et interroge la table 'users'.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/routing/app_router.dart';

part 'auth_provider.g.dart';

/// Flux continu (Stream) observant l'état de la session Supabase courante.
/// 
/// Conserve l'état en mémoire vive (`keepAlive: true`) pour notifier immédiatement
/// les widgets et le routeur de toute modification (connexion, déconnexion, rafraîchissement de token).
/// 
/// [ref] Référence Riverpod associée au fournisseur.
/// Retourne un flux émettant l'objet [User] courant ou `null` si non authentifié.
@Riverpod(keepAlive: true)
Stream<User?> authState(AuthStateRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) {
      final user = event.session?.user;
      debugPrint('[AUTH-FLUX] Événement Supabase Auth : ${event.event.name} | Utilisateur : ${user?.email ?? "Non connecté"} (ID: ${user?.id ?? "N/A"})');
      return user;
    },
  );
}

/// Contrôleur d'état (Notifier) gérant les opérations d'authentification explicites.
///
/// Fournit des actions asynchrones pour la connexion par identifiants et la déconnexion,
/// tout en synchronisant l'état du routeur et le cache des rôles utilisateurs.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  /// Initialisation du notifier lors de sa première lecture.
  @override
  FutureOr<void> build() {}

  /// Authentifie un utilisateur à l'aide de son adresse e-mail et de son mot de passe.
  ///
  /// Met l'état à [AsyncValue.loading] pendant la requête.
  /// En cas d'échec, capture et relance l'erreur Supabase pour affichage dans l'interface utilisateur.
  ///
  /// [email] L'adresse e-mail de l'utilisateur.
  /// [password] Le mot de passe associé.
  /// Retourne un [AuthResponse] contenant la session et les métadonnées de l'utilisateur.
  Future<AuthResponse> login(String email, String password) async {
    debugPrint('[AUTH-FOURNISSEUR] Tentative de connexion pour : $email');
    state = const AsyncValue.loading();
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(response);
      debugPrint('[AUTH-FOURNISSEUR] Connexion réussie pour l\'utilisateur : ${response.user?.id} (Email: ${response.user?.email})');
      debugPrint('[AUTH-FOURNISSEUR] Statut session : ${response.session != null ? "Active avec jeton JWT" : "Session absente"}');
      return response;
    } catch (e, stack) {
      debugPrint('[AUTH-FOURNISSEUR] ÉCHEC de connexion pour $email : $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Déconnecte l'utilisateur actuellement authentifié.
  ///
  /// Purge préalablement le cache de rôle d'AppRouter pour garantir qu'aucune
  /// redirection obsolète ne se produise lors de la prochaine authentification,
  /// puis termine la session Supabase active.
  Future<void> logout() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('[AUTH-FOURNISSEUR] Déconnexion demandée pour l\'utilisateur : ${currentUserId ?? "inconnu"}');
    state = const AsyncValue.loading();
    AppRouter.clearRoleCache();
    try {
      await Supabase.instance.client.auth.signOut();
      state = const AsyncValue.data(null);
      debugPrint('[AUTH-FOURNISSEUR] Déconnexion Supabase terminée avec succès.');
    } catch (e, stack) {
      debugPrint('[AUTH-FOURNISSEUR] Erreur lors de la déconnexion : $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

/// Fournisseur d'informations détaillées sur le profil de l'utilisateur connecté.
///
/// Surveille l'état d'authentification via [authStateProvider], puis interroge la table
/// publique `users` dans Supabase pour récupérer le profil complet (nom, rôle, téléphone, etc.).
///
/// [ref] Référence Riverpod associée au fournisseur.
/// Retourne une carte [Map<String, dynamic>] représentant la ligne utilisateur, ou `null` si non connecté.
@Riverpod(keepAlive: true)
Future<Map<String, dynamic>?> currentUser(CurrentUserRef ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    debugPrint('[AUTH-PROFIL] Aucun utilisateur connecté dans currentUserProvider.');
    return null;
  }

  debugPrint('[AUTH-PROFIL] Récupération du profil public.users pour ${user.id} (${user.email})...');
  try {
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    debugPrint('[AUTH-PROFIL] Profil chargé : Nom=${response?['name']}, Rôle=${response?['role']}, Téléphone=${response?['phone']}');
    return response;
  } catch (e) {
    debugPrint('[AUTH-PROFIL] Erreur lors de la lecture du profil users : $e');
    return null;
  }
}
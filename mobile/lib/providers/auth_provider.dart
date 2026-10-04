import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

// Stream de la session courante (pour écouter les changements auto)
@Riverpod(keepAlive: true)
Stream<User?> authState(AuthStateRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
}

// Notifier pour gérer explicitement l'authentification (login, logout, etc)
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<void> build() {}

  Future<AuthResponse> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    ));
    if (state.hasError) throw state.error!;
    return state.value as AuthResponse;
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => Supabase.instance.client.auth.signOut());
    if (state.hasError) throw state.error!;
  }
}

// Provider des infos utilisateur complètes
@Riverpod(keepAlive: true)
Future<Map<String, dynamic>?> currentUser(CurrentUserRef ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('users')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  return response;
}
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<AppUser?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final result = await _client.from('users').select().eq('id', user.id).maybeSingle();
    if (result == null) return null;
    return AppUser.fromJson(result);
  }
}

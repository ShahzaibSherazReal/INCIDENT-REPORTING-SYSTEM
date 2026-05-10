import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Hardcoded operator onboarding code (replace with admin-managed codes later).
const String kOperatorInviteCode = '000000';

enum LoginPortal { user, operator }

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// Email if typed; otherwise resolves username → email via Supabase RPC.
  Future<String> resolveLoginEmail(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      throw Exception('Enter email or username.');
    }
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    final res = await _client.rpc(
      'resolve_login_identifier',
      params: {'p_identifier': trimmed},
    );
    final email = res?.toString().trim() ?? '';
    if (email.isEmpty) {
      throw Exception('No account found for that username.');
    }
    return email.toLowerCase();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String username,
    required String password,
    required bool registerAsOperator,
    String operatorCode = '',
  }) async {
    await _client.auth.signUp(email: email.trim(), password: password);
    await _client.rpc(
      'complete_signup',
      params: {
        'p_username': username.trim(),
        'p_register_as_operator': registerAsOperator,
        'p_operator_code': operatorCode.trim(),
      },
    );
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

enum LoginPortal { user, operator }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _init();
  }

  final AuthService _authService;
  late final StreamSubscription<AuthState> _subscription;

  bool isLoading = true;
  Session? session;
  AppUser? profile;
  bool isGuest = false;

  bool get isAdmin => profile?.role == 'System Administrator';

  /// Operators and legacy admins can review / validate alerts.
  bool get canReviewAlerts => profile?.role == 'Operator' || profile?.role == 'System Administrator';

  Future<void> _init() async {
    session = _authService.currentSession;
    profile = await _authService.getCurrentProfile();
    _subscription = _authService.authStateChanges.listen((event) async {
      session = event.session;
      profile = await _authService.getCurrentProfile();
      notifyListeners();
    });
    isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({
    required String identifier,
    required String password,
    required LoginPortal portal,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final email = await _authService.resolveLoginEmail(identifier);
      await _authService.signInWithEmail(email: email, password: password);
      profile = await _authService.getCurrentProfile();
      session = _authService.currentSession;

      if (portal == LoginPortal.operator) {
        final r = profile?.role;
        if (r != 'Operator' && r != 'System Administrator') {
          await _authService.signOut();
          profile = null;
          session = null;
          throw Exception(
            'This account is not registered as an operator. Sign in as User or create an operator account.',
          );
        }
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String username,
    required String password,
    required bool registerAsOperator,
    required String operatorCode,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      await _authService.signUp(
        email: email,
        username: username,
        password: password,
        registerAsOperator: registerAsOperator,
        operatorCode: operatorCode,
      );
      profile = await _authService.getCurrentProfile();
      session = _authService.currentSession;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!isGuest) {
      await _authService.signOut();
    }
    profile = null;
    session = null;
    isGuest = false;
    notifyListeners();
  }

  void continueAsGuest() {
    isGuest = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

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

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    notifyListeners();
    await _authService.signIn(email: email, password: password);
    profile = await _authService.getCurrentProfile();
    isLoading = false;
    notifyListeners();
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

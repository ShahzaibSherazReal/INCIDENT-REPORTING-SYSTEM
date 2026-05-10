import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/built_in_staff_auth.dart';

enum LoginPortal { user, operator, administrator }

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

  /// Built-in Admin / Super Administrator (no Supabase session).
  bool isBuiltInStaffSession = false;
  BuiltInStaffTier builtInTier = BuiltInStaffTier.none;

  bool get isBuiltInSuperAdministrator =>
      isBuiltInStaffSession && builtInTier == BuiltInStaffTier.superAdmin;

  bool get canUseStaffPanel => isBuiltInStaffSession;

  bool get isAdmin =>
      profile?.role == 'System Administrator' ||
      profile?.role == 'Admin' ||
      profile?.role == 'Super Administrator';

  bool get canReviewAlerts =>
      profile?.role == 'Operator' ||
      profile?.role == 'System Administrator' ||
      profile?.role == 'Admin' ||
      profile?.role == 'Super Administrator';

  Future<void> _init() async {
    session = _authService.currentSession;
    profile = await _authService.getCurrentProfile();
    _subscription = _authService.authStateChanges.listen((event) async {
      session = event.session;
      if (isBuiltInStaffSession) {
        notifyListeners();
        return;
      }
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
      if (portal == LoginPortal.administrator) {
        final tier = matchBuiltInStaff(identifier, password);
        if (tier == BuiltInStaffTier.none) {
          throw Exception('Invalid administrator credentials.');
        }
        isBuiltInStaffSession = true;
        builtInTier = tier;
        session = null;
        profile = syntheticStaffProfile(tier);
        return;
      }

      final email = await _authService.resolveLoginEmail(identifier);
      await _authService.signInWithEmail(email: email, password: password);
      isBuiltInStaffSession = false;
      builtInTier = BuiltInStaffTier.none;
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
      isBuiltInStaffSession = false;
      builtInTier = BuiltInStaffTier.none;
      profile = await _authService.getCurrentProfile();
      session = _authService.currentSession;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!isGuest && !isBuiltInStaffSession) {
      await _authService.signOut();
    }
    profile = null;
    session = null;
    isGuest = false;
    isBuiltInStaffSession = false;
    builtInTier = BuiltInStaffTier.none;
    notifyListeners();
  }

  void continueAsGuest() {
    isGuest = true;
    isBuiltInStaffSession = false;
    builtInTier = BuiltInStaffTier.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/user_profile.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Central auth state: Firebase user + Firestore profile (which carries the
/// role that gates navigation in app_router.dart).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService) {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  AuthStatus status = AuthStatus.unknown;
  User? firebaseUser;
  UserProfile? profile;

  UserRole? get role => profile?.role;

  Future<void> _onAuthStateChanged(User? user) async {
    firebaseUser = user;
    if (user == null) {
      profile = null;
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    profile = await _authService.fetchProfile(user.uid);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _authService.signIn(email: email, password: password);

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String district,
    required UserRole role,
  }) =>
      _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        district: district,
        role: role,
      );

  Future<void> signOut() => _authService.signOut();
}

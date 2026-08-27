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

  Future<void> signIn(String email, String password) async {
    final fetchedProfile = await _authService.signInAndFetchProfile(
      email: email,
      password: password,
    );
    profile = fetchedProfile;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<UserProfile> signInFieldOfficer(String email, String password) async {
    final verifiedProfile = await _authService.authenticateFieldOfficer(
      email: email,
      password: password,
    );
    profile = verifiedProfile;
    status = AuthStatus.signedIn;
    notifyListeners();
    return verifiedProfile;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String district,
    required UserRole role,
    String? officerId,
  }) =>
      _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        district: district,
        role: role,
        officerId: officerId,
      );

  Future<void> signOut() async {
    await _authService.signOut();
    profile = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}

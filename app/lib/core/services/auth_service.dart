import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../app_config.dart';
import '../constants/app_constants.dart';

/// Wraps Firebase Auth + Firestore user profile operations with mock fallback
/// support when AppConfig.useMockData is true.
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  final StreamController<User?> _mockAuthStreamController = StreamController<User?>.broadcast();
  User? _mockCurrentUser;

  Stream<User?> get authStateChanges {
    if (AppConfig.useMockData) {
      return _mockAuthStreamController.stream;
    }
    return _auth.authStateChanges();
  }

  User? get currentUser {
    if (AppConfig.useMockData) {
      return _mockCurrentUser;
    }
    return _auth.currentUser;
  }

  // Pre-configured mock profiles for development/testing when Firebase isn't initialized
  static final Map<String, _MockAccount> _mockAccounts = {
    'officer@ner.gov.in': _MockAccount(
      password: 'Password123!',
      profile: const UserProfile(
        uid: 'demo_officer_uid_123',
        officerId: 'OFFICER-DV-001',
        fullName: 'Officer Tashi Rabha',
        email: 'officer@ner.gov.in',
        phoneNumber: '+91 9876543210',
        district: 'Dibang Valley',
        role: UserRole.fieldOfficial,
        status: 'active',
      ),
    ),
    'inactive_officer@ner.gov.in': _MockAccount(
      password: 'Password123!',
      profile: const UserProfile(
        uid: 'demo_officer_uid_456',
        officerId: 'OFFICER-DV-002',
        fullName: 'Officer Boren',
        email: 'inactive_officer@ner.gov.in',
        phoneNumber: '+91 9876543211',
        district: 'Dibang Valley',
        role: UserRole.fieldOfficial,
        status: 'disabled',
      ),
    ),
    'citizen@ner.gov.in': _MockAccount(
      password: 'Password123!',
      profile: const UserProfile(
        uid: 'citizen_uid_789',
        fullName: 'Pema Citizen',
        email: 'citizen@ner.gov.in',
        phoneNumber: '+91 9876543212',
        district: 'Dibang Valley',
        role: UserRole.citizen,
        status: 'active',
      ),
    ),
    'analyst@ner.gov.in': _MockAccount(
      password: 'Password123!',
      profile: const UserProfile(
        uid: 'analyst_uid_101',
        fullName: 'Dr. Roy Analyst',
        email: 'analyst@ner.gov.in',
        phoneNumber: '+91 9876543213',
        district: 'Dibang Valley',
        role: UserRole.analystAdmin,
        status: 'active',
      ),
    ),
  };

  Future<UserCredential> signIn({required String email, required String password}) async {
    if (AppConfig.useMockData) {
      final account = _mockAccounts[email.toLowerCase().trim()];
      if (account == null || account.password != password) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email/password combination.',
        );
      }
      return _MockUserCredential(account.profile);
    }
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserProfile> signInAndFetchProfile({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      final account = _mockAccounts[email.toLowerCase().trim()];
      if (account == null || account.password != password) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid email or password.',
        );
      }
      return account.profile;
    }

    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;
    final profile = await fetchProfile(uid);
    if (profile == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User profile not found in database.',
      );
    }
    return profile;
  }

  /// Specific Field Officer authentication flow:
  /// 1. Authenticate via Email + Password
  /// 2. Fetch User Profile
  /// 3. Verify Account Status == 'active'
  /// 4. Verify Role == UserRole.fieldOfficial
  Future<UserProfile> authenticateFieldOfficer({
    required String email,
    required String password,
  }) async {
    final profile = await signInAndFetchProfile(email: email, password: password);

    // Account Status Verification
    if (profile.status != 'active') {
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'Field Officer account is inactive or suspended. Access denied.',
      );
    }

    // Role Verification
    if (profile.role != UserRole.fieldOfficial) {
      throw FirebaseAuthException(
        code: 'unauthorized-role',
        message: 'Unauthorized access. Only Field Officers may log in to this portal.',
      );
    }

    return profile;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String district,
    required UserRole role,
    String? officerId,
  }) async {
    if (AppConfig.useMockData) {
      final uid = 'mock_user_${DateTime.now().millisecondsSinceEpoch}';
      final profile = UserProfile(
        uid: uid,
        officerId: officerId ?? (role == UserRole.fieldOfficial ? 'OFFICER-$uid' : null),
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        district: district,
        role: role,
        status: 'active',
      );
      _mockAccounts[email.toLowerCase().trim()] = _MockAccount(
        password: password,
        profile: profile,
      );
      return _MockUserCredential(profile);
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final profile = UserProfile(
      uid: credential.user!.uid,
      officerId: officerId ?? (role == UserRole.fieldOfficial ? 'OFFICER-${credential.user!.uid.substring(0, 6).toUpperCase()}' : null),
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      district: district,
      role: role,
      status: 'active',
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(profile.uid)
        .set(profile.toFirestore());

    return credential;
  }

  Future<void> signOut() async {
    if (AppConfig.useMockData) {
      _mockCurrentUser = null;
      _mockAuthStreamController.add(null);
      return;
    }
    await _auth.signOut();
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    if (AppConfig.useMockData) {
      for (final account in _mockAccounts.values) {
        if (account.profile.uid == uid) {
          return account.profile;
        }
      }
      return null;
    }

    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(uid, doc.data()!);
  }
}

class _MockAccount {
  final String password;
  final UserProfile profile;

  _MockAccount({required this.password, required this.profile});
}

class _MockUserCredential implements UserCredential {
  final UserProfile profile;

  _MockUserCredential(this.profile);

  @override
  User? get user => null;

  @override
  AuthCredential? get credential => null;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;
}

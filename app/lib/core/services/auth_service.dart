import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../constants/app_constants.dart';

/// Wraps Firebase Auth + the Firestore user profile write on signup.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates the Auth user, then writes the role-tagged profile doc.
  /// TODO: the role -> custom claim mirroring happens server-side via the
  /// onUserCreateSetRole Cloud Function (functions/src/auth/onUserCreate.ts);
  /// the ID token must be refreshed (getIdToken(true)) after signup before
  /// role-gated calls will see the claim.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String district,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final profile = UserProfile(
      uid: credential.user!.uid,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      district: district,
      role: role,
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(profile.uid)
        .set(profile.toFirestore());

    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(uid, doc.data()!);
  }
}

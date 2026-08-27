import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../models/app_user.dart';
import '../models/user_role.dart';

/// Wraps firebase_auth + the `users/{uid}` Firestore profile. This is the
/// single source of truth for "who is signed in" — AppState just relays
/// [currentAppUser].
///
/// There is no self-serve sign-up for Field Officer/Analyst anymore (see
/// sign_up_screen.dart, which only offers Citizen): those two roles are
/// fixed demo accounts created directly in Firebase Authentication, with
/// their matching `users/{uid}` doc created once by a bootstrap script
/// (see scripts/bootstrap_demo_users.js, deleted after use) rather than
/// through this class's signUp(). `enabled` still exists on the schema as
/// a manual kill-switch — an account can be disabled by flipping it to
/// `false` directly in the Firestore console; every enabled*() check in
/// firestore.rules still honors that — there's just no in-app approval
/// flow to set it anymore.
class AuthRepository {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'users';

  /// Citizen self-registration. Always enabled immediately.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final user = AppUser(
      uid: uid,
      email: email,
      role: role,
      enabled: role == UserRole.citizen,
      displayName: displayName,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collection).doc(uid).set(user.toFirestore());
    return user;
  }

  /// Signs in, then reads the matching `users/{uid}` profile. Throws a
  /// [StateError] with a clear message (rather than letting a null-check
  /// crash surface) if the Auth account has no matching Firestore doc —
  /// only possible for an account created directly in Firebase Auth
  /// whose bootstrap doc-creation step hasn't run yet.
  Future<AppUser> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;

    final doc = await _firestore.collection(_collection).doc(uid).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw StateError(
        'This account has no profile set up yet. Contact an administrator before signing in.',
      );
    }

    return AppUser.fromFirestore(uid, doc.data()!);
  }

  Future<void> signOut() => _auth.signOut();

  /// Firebase Auth state combined with the matching Firestore profile;
  /// null when signed out (or, transiently, if the profile doc doesn't
  /// exist yet).
  Stream<AppUser?> get currentAppUser {
    return _auth.authStateChanges().asyncExpand((fbUser) {
      if (fbUser == null) return Stream<AppUser?>.value(null);

      return _firestore.collection(_collection).doc(fbUser.uid).snapshots().map((doc) {
        // ignore: avoid_print
        print('AuthRepository.currentAppUser snapshot: uid=${fbUser.uid} exists=${doc.exists} '
            'fromCache=${doc.metadata.isFromCache} data=${doc.data()}');
        if (!doc.exists) return null;
        return AppUser.fromFirestore(fbUser.uid, doc.data()!);
      });
    });
  }

  /// Enabled Field Officer accounts, so an Analyst can assign a real
  /// account to a task instead of typing an arbitrary id (see
  /// screens/analyst/reports_queue_screen.dart and tasks_screen.dart).
  Stream<List<AppUser>> watchEnabledFieldOfficers() {
    return _firestore
        .collection(_collection)
        .where('role', isEqualTo: UserRole.fieldOfficial.firestoreValue)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppUser.fromFirestore(doc.id, doc.data())).toList());
  }
}

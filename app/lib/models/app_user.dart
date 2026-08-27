import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

/// A real, authenticated account — the `users/{uid}` Firestore profile
/// that sits alongside the Firebase Auth user. Field Officer and Analyst
/// accounts are created with `enabled: false` and stay locked out of
/// their role's screens until an existing enabled Analyst approves them
/// (see services/auth_repository.dart).
class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final bool enabled;
  final String? displayName;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.enabled,
    required this.createdAt,
    this.displayName,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    final createdAtValue = data['created_at'];
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      role: UserRoleX.fromFirestoreValue(data['role'] as String? ?? 'citizen'),
      enabled: data['enabled'] as bool? ?? false,
      displayName: data['display_name'] as String?,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'role': role.firestoreValue,
        'enabled': enabled,
        'display_name': displayName,
        'created_at': FieldValue.serverTimestamp(),
      };
}

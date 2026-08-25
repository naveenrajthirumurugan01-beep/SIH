import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

class UserProfile {
  final String uid;
  final String fullName;
  final String? email;
  final String phoneNumber;
  final String district;
  final UserRole role;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.district,
    required this.role,
    this.email,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String?,
      phoneNumber: data['phone_number'] as String? ?? '',
      district: data['district'] as String? ?? '',
      role: UserRoleX.fromFirestoreValue(data['role'] as String? ?? 'citizen'),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'district': district,
        'role': role.firestoreValue,
        'created_at': FieldValue.serverTimestamp(),
      };
}

/// Canonical user role definition, shared by the citizen-facing mock-data
/// stack and the earlier multi-role scaffold (see
/// core/constants/app_constants.dart, which now re-exports this file).
enum UserRole { citizen, fieldOfficial, analystAdmin }

extension UserRoleX on UserRole {
  String get firestoreValue => switch (this) {
        UserRole.citizen => 'citizen',
        UserRole.fieldOfficial => 'field_official',
        UserRole.analystAdmin => 'analyst_admin',
      };

  String get label => switch (this) {
        UserRole.citizen => 'Citizen',
        UserRole.fieldOfficial => 'Field Official',
        UserRole.analystAdmin => 'Analyst / Admin',
      };

  static UserRole fromFirestoreValue(String value) => switch (value) {
        'field_official' => UserRole.fieldOfficial,
        'analyst_admin' => UserRole.analystAdmin,
        _ => UserRole.citizen,
      };
}

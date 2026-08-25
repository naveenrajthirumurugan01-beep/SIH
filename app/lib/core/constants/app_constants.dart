/// App-wide constants: risk color mapping, districts, Firestore collection names.
library;

import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, veryHigh }

enum UserRole { citizen, fieldOfficial, analystAdmin }

extension UserRoleX on UserRole {
  String get firestoreValue => switch (this) {
        UserRole.citizen => 'citizen',
        UserRole.fieldOfficial => 'field_official',
        UserRole.analystAdmin => 'analyst_admin',
      };

  static UserRole fromFirestoreValue(String value) => switch (value) {
        'field_official' => UserRole.fieldOfficial,
        'analyst_admin' => UserRole.analystAdmin,
        _ => UserRole.citizen,
      };

  String get label => switch (this) {
        UserRole.citizen => 'Citizen',
        UserRole.fieldOfficial => 'Field Official',
        UserRole.analystAdmin => 'Analyst / Admin',
      };
}

extension RiskLevelX on RiskLevel {
  /// Color-coded per the PS spec: green/amber/orange/red for
  /// low/medium/high/very high risk.
  Color get color => switch (this) {
        RiskLevel.low => const Color(0xFF2E7D32), // green
        RiskLevel.medium => const Color(0xFFF9A825), // amber
        RiskLevel.high => const Color(0xFFEF6C00), // orange
        RiskLevel.veryHigh => const Color(0xFFC62828), // red
      };

  String get label => switch (this) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
        RiskLevel.veryHigh => 'Very High',
      };

  static RiskLevel fromString(String value) => switch (value) {
        'medium' => RiskLevel.medium,
        'high' => RiskLevel.high,
        'very_high' => RiskLevel.veryHigh,
        _ => RiskLevel.low,
      };
}

class FirestoreCollections {
  FirestoreCollections._();

  static const users = 'users';
  static const districtsRisk = 'districts_risk';
  static const reports = 'reports';
  static const roads = 'roads';
  static const alerts = 'alerts';
}

class AppConstants {
  AppConstants._();

  static const appName = 'NER Landslide EWS';

  /// TODO: point at the deployed FastAPI backend; use 10.0.2.2 for Android
  /// emulator localhost, or the LAN IP when testing on a physical device.
  static const apiBaseUrl = 'http://localhost:8000/api/v1';

  /// Default map center: roughly central NER (near Guwahati, Assam).
  static const defaultMapLat = 26.1445;
  static const defaultMapLng = 91.7362;
  static const defaultMapZoom = 7.0;
}

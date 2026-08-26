import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import '../services/alert_repository.dart';
import '../services/inspection_repository.dart';
import '../services/location_service.dart';
import '../services/report_repository.dart';
import '../services/risk_repository.dart';
import '../services/task_repository.dart';
import 'app_config.dart';

const _deviceIdPrefsKey = 'device_id';
const _rolePrefsKey = 'current_role';
const _officerNamePrefsKey = 'officer_name';
const _officerIdPrefsKey = 'officer_id';

/// App-wide DI container + light UI state. Builds the mock or Firestore
/// repository implementations based on [AppConfig.useMockData], hands out
/// a stable per-device anonymous id (persisted via shared_preferences) so
/// "My Reports" works without a real Firebase Auth user, and — for the
/// Field Officer build — a lightweight officer identity persisted the same
/// stopgap way (see screens/role_entry_screen.dart, which is explicitly a
/// placeholder for real login).
class AppState extends ChangeNotifier {
  AppState._({
    required this.deviceId,
    required this.riskRepository,
    required this.reportRepository,
    required this.alertRepository,
    required this.taskRepository,
    required this.inspectionRepository,
    required this._prefs,
    UserRole? currentRole,
    String? officerName,
    String? officerId,
  }) {
    _currentRole = currentRole;
    _officerName = officerName;
    _officerId = officerId;
  }

  final String deviceId;
  final RiskRepository riskRepository;
  final ReportRepository reportRepository;
  final AlertRepository alertRepository;
  final TaskRepository taskRepository;
  final InspectionRepository inspectionRepository;

  final SharedPreferences _prefs;
  final LocationService _locationService = LocationService();

  UserRole? _currentRole;
  UserRole? get currentRole => _currentRole;

  String? _officerName;
  String? get officerName => _officerName;

  String? _officerId;
  String? get officerId => _officerId;

  LatLng? _currentLocation;
  LatLng get currentLocation => _currentLocation ?? LocationService.studyAreaCenter;
  bool get hasResolvedLocation => _currentLocation != null;

  static Future<AppState> create() async {
    final prefs = await SharedPreferences.getInstance();

    var deviceId = prefs.getString(_deviceIdPrefsKey);
    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdPrefsKey, deviceId);
    }

    final roleValue = prefs.getString(_rolePrefsKey);

    final RiskRepository riskRepository =
        AppConfig.useMockData ? MockRiskRepository() : FirestoreRiskRepository();
    final ReportRepository reportRepository =
        AppConfig.useMockData ? MockReportRepository() : FirestoreReportRepository();
    final AlertRepository alertRepository =
        AppConfig.useMockData ? MockAlertRepository() : FirestoreAlertRepository();
    final TaskRepository taskRepository = AppConfig.useMockData
        ? MockTaskRepository(reportRepository: reportRepository)
        : FirestoreTaskRepository(reportRepository: reportRepository);
    final InspectionRepository inspectionRepository = AppConfig.useMockData
        ? MockInspectionRepository(
            reportRepository: reportRepository,
            taskRepository: taskRepository,
          )
        : FirestoreInspectionRepository(
            reportRepository: reportRepository,
            taskRepository: taskRepository,
          );

    if (reportRepository is MockReportRepository) {
      reportRepository.seedDemoDataIfNeeded(deviceId);
    }

    return AppState._(
      deviceId: deviceId,
      riskRepository: riskRepository,
      reportRepository: reportRepository,
      alertRepository: alertRepository,
      taskRepository: taskRepository,
      inspectionRepository: inspectionRepository,
      prefs: prefs,
      currentRole: roleValue == null ? null : UserRoleX.fromFirestoreValue(roleValue),
      officerName: prefs.getString(_officerNamePrefsKey),
      officerId: prefs.getString(_officerIdPrefsKey),
    );
  }

  /// Set by the role-entry screen (screens/role_entry_screen.dart) — a
  /// stand-in for real login until Firebase Auth exists. [officerName]/
  /// [officerId] are required when [role] is fieldOfficial.
  Future<void> setRole(UserRole role, {String? officerName, String? officerId}) async {
    _currentRole = role;
    await _prefs.setString(_rolePrefsKey, role.firestoreValue);

    if (role == UserRole.fieldOfficial) {
      _officerName = officerName;
      _officerId = officerId;
      if (officerName != null) await _prefs.setString(_officerNamePrefsKey, officerName);
      if (officerId != null) await _prefs.setString(_officerIdPrefsKey, officerId);
    }

    notifyListeners();
  }

  /// Bounces back to the role-entry screen. Reachable via a small "switch
  /// role" action in each shell — see citizen home / field task list
  /// app bars — since there's no real sign-out flow yet.
  Future<void> clearRole() async {
    _currentRole = null;
    await _prefs.remove(_rolePrefsKey);
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    _currentLocation = await _locationService.getCurrentOrFallback();
    notifyListeners();
  }

  static String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'device_${timestamp}_$suffix';
  }
}

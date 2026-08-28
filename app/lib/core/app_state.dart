import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/alert_repository.dart';
import '../services/auth_repository.dart';
import '../services/inspection_repository.dart';
import '../services/location_service.dart';
import '../services/report_repository.dart';
import '../services/risk_repository.dart';
import '../services/task_repository.dart';
import 'app_config.dart';

class AppState extends ChangeNotifier {
  AppState._({
    required this.authRepository,
    required this.riskRepository,
    required this.reportRepository,
    required this.alertRepository,
    required this.taskRepository,
    required this.inspectionRepository,
  }) {
    _authSubscription = authRepository.currentAppUser.listen(
      (user) {
        _currentUser = user;
        _authResolved = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _currentUser = null;
        _authResolved = true;
        notifyListeners();
      },
    );
  }

  final AuthRepository authRepository;
  final RiskRepository riskRepository;
  final ReportRepository reportRepository;
  final AlertRepository alertRepository;
  final TaskRepository taskRepository;
  final InspectionRepository inspectionRepository;

  late final StreamSubscription<AppUser?> _authSubscription;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  UserRole? _currentRole;
  UserRole? get currentRole => _currentRole;

  bool _authResolved = false;
  bool get authResolved => _authResolved;

  String get uid => fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'demo_user_id';

  String get deviceId => currentUser?.uid ?? 'device_demo_01';
  String? get officerName => currentUser?.displayName ?? currentUser?.email ?? 'Demo Field Officer';
  String? get officerId => currentUser?.uid ?? demoOfficerUid;

  final LocationService _locationService = LocationService();

  LatLng? _currentLocation;
  LatLng get currentLocation => _currentLocation ?? LocationService.studyAreaCenter;
  bool get hasResolvedLocation => _currentLocation != null;

  static Future<AppState> create() async {
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

    return AppState._(
      authRepository: AuthRepository(),
      riskRepository: riskRepository,
      reportRepository: reportRepository,
      alertRepository: alertRepository,
      taskRepository: taskRepository,
      inspectionRepository: inspectionRepository,
    );
  }

  Future<void> setRole(UserRole role, {String? officerName, String? officerId}) async {
    _currentRole = role;
    notifyListeners();
  }

  Future<void> clearRole() async {
    _currentRole = null;
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    _currentLocation = await _locationService.getCurrentOrFallback();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

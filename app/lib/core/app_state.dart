import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../services/alert_repository.dart';
import '../services/auth_repository.dart';
import '../services/inspection_repository.dart';
import '../services/location_service.dart';
import '../services/report_repository.dart';
import '../services/risk_repository.dart';
import '../services/task_repository.dart';
import 'app_config.dart';

/// App-wide DI container + light UI state. Builds the mock or Firestore
/// repository implementations based on [AppConfig.useMockData], and
/// relays the signed-in [AppUser] (or null) from AuthRepository so
/// main.dart's router and every screen can read the current user's role
/// and approval state from one place.
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
      // A background auth error (e.g. a stale/stuck identitytoolkit
      // token-refresh attempt against cached Firebase Auth state) must
      // never surface as a crash or a stuck UI. Treat it exactly like
      // "signed out" — the router falls back to RoleSelectScreen/sign-in,
      // which is always a safe, recoverable state to land in; the
      // subscription itself keeps listening, so a subsequent valid auth
      // state still comes through normally.
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

  /// True once the auth stream has emitted at least once, so main.dart's
  /// router can show a brief loading state instead of flashing the sign-in
  /// screen for an already-signed-in user while the first snapshot loads.
  bool _authResolved = false;
  bool get authResolved => _authResolved;

  /// Only valid while signed in (every screen that reads this is reached
  /// through main.dart's auth-gated router).
  String get uid => fb_auth.FirebaseAuth.instance.currentUser!.uid;

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

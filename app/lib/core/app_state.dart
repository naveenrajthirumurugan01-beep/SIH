import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity_log_entry.dart';
import '../models/app_user.dart';
import '../services/alert_repository.dart';
import '../services/auth_repository.dart';
import '../services/historical_landslide_repository.dart';
import '../services/inspection_repository.dart';
import '../services/location_service.dart';
import '../services/report_repository.dart';
import '../services/risk_factor_provider.dart';
import '../services/risk_repository.dart';
import '../services/task_repository.dart';
import '../services/weather_provider.dart';
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
    required this.riskFactorProvider,
    required this.weatherProvider,
    required this.historicalLandslideRepository,
  }) {
    _authSubscription = authRepository.currentAppUser.listen(
      (user) {
        // ignore: avoid_print
        print('AppState.currentAppUser emitted: uid=${user?.uid} role=${user?.role} enabled=${user?.enabled}');
        _currentUser = user;
        _authResolved = true;
        notifyListeners();
      },
      // A background auth error (e.g. a Firestore listener hiccup around
      // ID-token refresh/reconnect) must never surface as a crash or a
      // stuck UI — but it also must not be treated as a sign-out unless
      // Firebase Auth itself agrees the user is signed out. We've seen
      // the Firestore-level users/{uid} listener throw a transient
      // permission-denied right after successfully emitting a valid
      // user, with no real sign-out involved; nulling currentUser there
      // bounced a legitimately-signed-in user back to the sign-in
      // screen. So: only clear currentUser if FirebaseAuth.currentUser
      // is actually null (a real sign-out) or we never had a user to
      // begin with. Otherwise keep the last known-good user and just
      // log the error — the subscription keeps listening, so a
      // subsequent valid snapshot still comes through normally.
      onError: (Object error, StackTrace stackTrace) {
        // ignore: avoid_print
        print('AUTH STREAM ERROR: $error');
        final reallySignedOut = fb_auth.FirebaseAuth.instance.currentUser == null;
        if (reallySignedOut || _currentUser == null) {
          _currentUser = null;
        }
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
  final HistoricalLandslideRepository historicalLandslideRepository;

  /// Not gated by AppConfig.useMockData — it's pure computation over a
  /// [RiskZone]'s already-loaded fields, not an I/O-backed repository.
  /// Swap for a real `MLModelRiskFactorProvider` here once one exists.
  final RiskFactorProvider riskFactorProvider;

  /// Same rationale as [riskFactorProvider] — swap for a real IMD/weather
  /// API-backed implementation here once one exists.
  final WeatherProvider weatherProvider;

  late final StreamSubscription<AppUser?> _authSubscription;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  /// True once the auth stream has emitted at least once, so main.dart's
  /// router can show a brief loading state instead of flashing the sign-in
  /// screen for an already-signed-in user while the first snapshot loads.
  bool _authResolved = false;
  bool get authResolved => _authResolved;

  /// Only valid while signed in (every screen that reads this is reached
  /// through main.dart's auth-gated router). Prefers the current
  /// [AppUser]'s uid over Firebase Auth's directly so this also works for
  /// a caller-set [setDemoUser] user with no backing Firebase Auth
  /// session — not the normal path anymore (see AppConfig.skipAuthForDemo
  /// / RoleSelectScreen, which now do a real authRepository.signIn()), but
  /// kept as a safe fallback for [setDemoUser]'s other possible callers.
  String get uid => _currentUser?.uid ?? fb_auth.FirebaseAuth.instance.currentUser!.uid;

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
    final HistoricalLandslideRepository historicalLandslideRepository = AppConfig.useMockData
        ? MockHistoricalLandslideRepository()
        : FirestoreHistoricalLandslideRepository();

    return AppState._(
      authRepository: AuthRepository(),
      riskRepository: riskRepository,
      reportRepository: reportRepository,
      alertRepository: alertRepository,
      taskRepository: taskRepository,
      inspectionRepository: inspectionRepository,
      riskFactorProvider: DemoRiskFactorProvider(),
      weatherProvider: DemoWeatherProvider(),
      historicalLandslideRepository: historicalLandslideRepository,
    );
  }

  Future<void> refreshLocation() async {
    _currentLocation = await _locationService.getCurrentOrFallback();
    notifyListeners();
  }

  /// Recent Analyst actions this session (Assign, Reassign, Acknowledge,
  /// Escalate, Resolve, ...) — newest first. See recordActivity and the
  /// Analyst Activity Log screen. Deliberately in-memory only: it exists
  /// to make a demo run feel complete, not as an audit trail, so it does
  /// not survive a reload and is never written to Firestore.
  final List<ActivityLogEntry> _activityLog = [];
  List<ActivityLogEntry> get activityLog => List.unmodifiable(_activityLog.reversed);

  void recordActivity(String message) {
    _activityLog.add(ActivityLogEntry(timestamp: DateTime.now(), message: message));
    notifyListeners();
  }

  /// Sets the signed-in user directly, completely independent of the real
  /// auth flow: no Firebase Auth or Firestore call, just local state.
  /// main.dart's _AuthRouter reacts the same way it does to a real
  /// sign-in, since it only watches [currentUser]/[authResolved]. NOT used
  /// by the AppConfig.skipAuthForDemo bypass anymore — a locally-faked
  /// user has no real Firebase Auth session, so every Firestore security
  /// rule (which reads request.auth.uid) denies it; RoleSelectScreen now
  /// calls the real authRepository.signIn() with known demo credentials
  /// instead. Left here in case another caller needs a fully-local fake
  /// user (e.g. a widget test) with no network/Firestore dependency.
  void setDemoUser(AppUser user) {
    _currentUser = user;
    _authResolved = true;
    notifyListeners();
  }

  /// The one correct way to sign out, for every role/screen. Calling
  /// [authRepository]'s signOut() alone is not enough: if [_currentUser]
  /// was ever set directly via [setDemoUser] rather than by Firebase Auth,
  /// there is no real session for Firebase to end — signOut() on an
  /// already-signed-out FirebaseAuth is a no-op that never emits a new
  /// authStateChanges() event, so [_currentUser] (and the router showing
  /// the previous dashboard) never updates. Clearing [_currentUser] here
  /// directly, rather than only waiting on the auth stream, makes
  /// sign-out deterministic no matter how the session was established.
  Future<void> signOut() async {
    await authRepository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

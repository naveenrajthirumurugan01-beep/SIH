import 'package:go_router/go_router.dart';

import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/analyst/screens/analyst_home_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/citizen/screens/citizen_home_screen.dart';
import '../../features/field_official/screens/field_official_home_screen.dart';
import '../../features/reports/screens/report_detail_screen.dart';
import '../../features/reports/screens/report_submission_screen.dart';
import '../../features/reports/screens/reports_list_screen.dart';
import '../../features/risk_map/screens/risk_map_screen.dart';
import '../constants/app_constants.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const signup = '/signup';
  static const citizenHome = '/citizen';
  static const fieldOfficialHome = '/field-official';
  static const analystHome = '/analyst';
  static const riskMap = '/risk-map';
  static const alerts = '/alerts';
  static const reportsList = '/reports';
  static const reportSubmit = '/reports/new';
  static const reportDetail = '/reports/:id';
}

/// Maps a role to its dedicated home screen route, per the three
/// role-based navigation flows in the PS spec.
String homeRouteForRole(UserRole role) => switch (role) {
      UserRole.citizen => AppRoutes.citizenHome,
      UserRole.fieldOfficial => AppRoutes.fieldOfficialHome,
      UserRole.analystAdmin => AppRoutes.analystHome,
    };

GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;

      if (authProvider.status != AuthStatus.signedIn) {
        return loggingIn ? null : AppRoutes.login;
      }

      // Signed in: bounce away from auth screens into the role home.
      if (loggingIn) {
        final role = authProvider.role;
        return role == null ? null : homeRouteForRole(role);
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: AppRoutes.citizenHome,
        builder: (context, state) => const CitizenHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.fieldOfficialHome,
        builder: (context, state) => const FieldOfficialHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.analystHome,
        builder: (context, state) => const AnalystHomeScreen(),
      ),
      GoRoute(path: AppRoutes.riskMap, builder: (context, state) => const RiskMapScreen()),
      GoRoute(path: AppRoutes.alerts, builder: (context, state) => const AlertsScreen()),
      GoRoute(
        path: AppRoutes.reportsList,
        builder: (context, state) => const ReportsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportSubmit,
        builder: (context, state) => const ReportSubmissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportDetail,
        builder: (context, state) =>
            ReportDetailScreen(reportId: state.pathParameters['id']!),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/providers/auth_provider.dart';

/// List of submitted reports. Citizens see their own; field officials see
/// district reports; analysts see all reports with approve/reject actions
/// (TODO: gate the moderation actions to UserRole.analystAdmin and wire up
/// ReportService.watchReports() + reviewReport()).
class ReportsListScreen extends StatelessWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? UserRole.citizen;
    final isModerator = role == UserRole.analystAdmin;

    return Scaffold(
      appBar: AppBar(title: Text(isModerator ? 'Report Moderation Queue' : 'Reports')),
      body: const Center(
        // TODO: replace with a StreamBuilder<List<Report>> over
        // ReportService.watchReports(), rendering RiskBadge-style status
        // chips and (for analysts) approve/reject buttons per tile.
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'TODO: live report list not yet connected to Firestore.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      floatingActionButton: role != UserRole.analystAdmin
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.reportSubmit),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

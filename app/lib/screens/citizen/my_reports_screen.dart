import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../models/report.dart';
import '../../widgets/hazard_icons.dart';
import '../../widgets/status_stepper.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: StreamBuilder<List<Report>>(
        stream: appState.reportRepository.watchMyReports(appState.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You haven\'t submitted any reports yet.\nUse the Report tab to submit one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: context.responsiveValue(mobile: const EdgeInsets.all(12), tablet: const EdgeInsets.all(16), desktop: const EdgeInsets.all(16)),
            itemCount: reports.length,
            itemBuilder: (context, index) => _ReportCard(report: reports[index]),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(iconForHazard(report.hazardType)),
        title: Text(report.hazardType.label),
        subtitle: Text(DateFormat('d MMM y, HH:mm').format(report.createdAt)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.description),
                const SizedBox(height: 16),
                StatusStepper(current: report.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

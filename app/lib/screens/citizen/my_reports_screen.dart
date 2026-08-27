import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/citizen_theme.dart';
import '../../models/report.dart';
import '../../widgets/hazard_icons.dart';
import '../../widgets/status_stepper.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: CitizenTheme.background,
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        title: const Text('My Reports', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<Report>>(
        stream: appState.reportRepository.watchMyReports(appState.deviceId),
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
                  'You haven\'t submitted any reports yet.\nUse Quick Actions on Home or the Report form to submit one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: Icon(iconForHazard(report.hazardType), color: CitizenTheme.primary),
        title: Text(report.hazardType.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(DateFormat('d MMM yyyy, hh:mm a').format(report.createdAt)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.description.isNotEmpty) ...[
                  Text(report.description, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                StatusStepper(current: report.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

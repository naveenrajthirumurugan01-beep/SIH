import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/date_range_filter.dart';
import '../../core/responsive.dart';
import '../../models/alert.dart';
import '../../models/report.dart';
import '../../models/risk_zone.dart';
import '../../models/user_role.dart';
import '../../services/report_severity.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/hazard_icons.dart';
import 'assign_officer_dialog.dart';

const _activeStatuses = {ReportStatus.submitted, ReportStatus.underReview};

class ReportsQueueScreen extends StatefulWidget {
  const ReportsQueueScreen({super.key});

  @override
  State<ReportsQueueScreen> createState() => _ReportsQueueScreenState();
}

class _ReportsQueueScreenState extends State<ReportsQueueScreen> {
  DateRangePreset _dateFilter = DateRangePreset.allTime;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports Queue')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.isMobile ? 12 : 16, 12, context.isMobile ? 12 : 16, 4),
            child: Row(
              children: [
                Text('Submitted:', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in DateRangePreset.values)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: _dateFilter == preset,
                        onSelected: (_) => setState(() => _dateFilter = preset),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Report>>(
              stream: appState.reportRepository.watchAllReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorStateView(
                    message: 'Could not load reports: ${snapshot.error}',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final reports =
                    snapshot.data!.where((r) => _dateFilter.includes(r.createdAt)).toList();
                final active = reports.where((r) => _activeStatuses.contains(r.status)).toList();
                final inMotion =
                    reports.where((r) => !_activeStatuses.contains(r.status)).toList();

                if (reports.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.inbox_outlined,
                    message: _dateFilter == DateRangePreset.allTime
                        ? 'No citizen or field reports yet.'
                        : 'No reports submitted in the ${_dateFilter.label.toLowerCase()}.',
                  );
                }

                return ListView(
                  padding: EdgeInsets.all(context.isMobile ? 12 : 16),
                  children: [
                    if (active.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No reports awaiting triage.', textAlign: TextAlign.center),
                      )
                    else
                      for (final report in active) _ActiveReportCard(report: report),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: Text('Already in motion (${inMotion.length})'),
                      initiallyExpanded: false,
                      children: [
                        for (final report in inMotion) _InMotionReportTile(report: report),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveReportCard extends StatelessWidget {
  final Report report;

  const _ActiveReportCard({required this.report});

  Future<void> _setStatus(BuildContext context, ReportStatus status) async {
    final appState = context.read<AppState>();
    await appState.reportRepository.updateReportStatus(report.id, status);
    appState.recordActivity('${status.label} report "${report.hazardType.label}"');
  }

  Future<void> _assign(BuildContext context) async {
    final appState = context.read<AppState>();
    final officers = await appState.authRepository.watchEnabledFieldOfficers().first;
    if (!context.mounted) return;

    if (officers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No approved Field Officer accounts yet — approve one under Pending Accounts first.'),
        ),
      );
      return;
    }

    final officer = await pickFieldOfficer(context, officers);
    if (officer == null || !context.mounted) return;

    // Ties the new task's risk level to the model's own read of this
    // location, rather than guessing — same data the citizen map shows.
    final nearestZone = await appState.riskRepository.getNearestZone(report.lat, report.lng);
    final riskLevel = nearestZone?.level ?? inferredSeverityForReport(report);

    await assignInspectionAt(
      appState,
      officer: officer,
      lat: report.lat,
      lng: report.lng,
      riskLevel: riskLevel,
      reason: 'Citizen report: ${report.description}',
      instructions:
          'Field-verify the ${report.hazardType.label.toLowerCase()} reported at this '
          'location. Reporter notes: "${report.description}"',
      linkedReportId: report.id,
    );
    // Assigning a field officer is what moves a report from triage into
    // active field verification — previously this button created the task
    // but left the report stuck as submitted/underReview forever.
    await appState.reportRepository.updateReportStatus(report.id, ReportStatus.fieldVerification);
    appState.recordActivity(
      'Assigned report "${report.hazardType.label}" to ${officer.displayName ?? officer.email}',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigned to ${officer.displayName ?? officer.email}.')),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Report'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Duplicate of an existing report',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // NOTE: the rejection reason is not persisted — Report has no
    // reviewer-note field yet. Surfaced only in this confirmation for now.
    await _setStatus(context, ReportStatus.rejected);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report rejected.')));
  }

  Future<void> _escalate(BuildContext context) async {
    final appState = context.read<AppState>();
    await appState.alertRepository.createAlert(
      HazardAlert(
        id: '',
        title: 'Escalated citizen report — ${report.hazardType.label}',
        message: report.description,
        severity: RiskLevel.critical,
        lat: report.lat,
        lng: report.lng,
        radiusKm: 3.0,
        district: report.district,
        createdAt: DateTime.now(),
        source: AlertSource.citizenReport,
        recommendedAction: 'Escalated by analyst from the Reports Queue — verify and dispatch urgently.',
      ),
    );
    appState.recordActivity('Escalated report "${report.hazardType.label}" to a critical alert');

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escalated — a critical alert was issued for this location.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = report.mediaUrls.isEmpty ? null : report.mediaUrls.first;
    final severity = inferredSeverityForReport(report);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconForHazard(report.hazardType)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.hazardType.label, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        report.reporterRole == UserRole.citizen ? 'Citizen report' : 'Field report',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                if (thumbnail != null) _Thumbnail(path: thumbnail),
              ],
            ),
            const SizedBox(height: 8),
            _ReportMeta(report: report, severity: severity),
            const SizedBox(height: 8),
            Text(report.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (report.status == ReportStatus.submitted)
                  OutlinedButton(
                    onPressed: () => _setStatus(context, ReportStatus.underReview),
                    child: const Text('Review'),
                  ),
                OutlinedButton(
                  onPressed: () => _setStatus(context, ReportStatus.verified),
                  child: const Text('Verify'),
                ),
                OutlinedButton(onPressed: () => _reject(context), child: const Text('Reject')),
                OutlinedButton(onPressed: () => _escalate(context), child: const Text('Escalate')),
                FilledButton(
                  onPressed: () => _assign(context),
                  child: const Text('Assign Field Officer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportMeta extends StatelessWidget {
  final Report report;
  final RiskLevel severity;

  const _ReportMeta({required this.report, required this.severity});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ID: ${report.id} · Citizen: ${_shortUid(report.reporterUid)}', style: style),
        Text(
          '${report.lat.toStringAsFixed(4)}, ${report.lng.toStringAsFixed(4)} · '
          '${DateFormat('d MMM y, HH:mm').format(report.createdAt)}',
          style: style,
        ),
        Text(
          'Reported severity (estimated from hazard type): ${severity.label} · Status: ${report.status.label}',
          style: style,
        ),
      ],
    );
  }

  String _shortUid(String uid) => uid.length <= 8 ? uid : '${uid.substring(0, 8)}…';
}

class _Thumbnail extends StatelessWidget {
  final String path;

  const _Thumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final image = path.startsWith('http')
        ? Image.network(path, width: 56, height: 56, fit: BoxFit.cover)
        : Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }
}

class _InMotionReportTile extends StatelessWidget {
  final Report report;

  const _InMotionReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(iconForHazard(report.hazardType)),
      title: Text(report.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${report.status.label} · ${report.lat.toStringAsFixed(3)}, ${report.lng.toStringAsFixed(3)} · '
        '${DateFormat('d MMM').format(report.createdAt)}',
      ),
      trailing: report.status == ReportStatus.verified
          ? TextButton(
              onPressed: () {
                final appState = context.read<AppState>();
                appState.reportRepository.updateReportStatus(report.id, ReportStatus.resolved);
                appState.recordActivity('Resolved report "${report.hazardType.label}"');
              },
              child: const Text('Mark Resolved'),
            )
          : null,
    );
  }
}

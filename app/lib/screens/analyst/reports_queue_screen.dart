import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/geofence_utils.dart';
import '../../models/app_user.dart';
import '../../models/geofence.dart';
import '../../models/report.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../models/user_role.dart';
import '../../widgets/hazard_icons.dart';

const _activeStatuses = {ReportStatus.submitted, ReportStatus.underReview};

class ReportsQueueScreen extends StatelessWidget {
  const ReportsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports Queue')),
      body: StreamBuilder<List<Report>>(
        stream: appState.reportRepository.watchAllReports(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;
          final active = reports.where((r) => _activeStatuses.contains(r.status)).toList();
          final inMotion = reports.where((r) => !_activeStatuses.contains(r.status)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
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
    );
  }
}

class _ActiveReportCard extends StatelessWidget {
  final Report report;

  const _ActiveReportCard({required this.report});

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

    final selected = await showDialog<AppUser>(
      context: context,
      builder: (dialogContext) => _AssignOfficerDialog(officers: officers),
    );

    if (selected == null || !context.mounted) return;

    // Ties the new task's risk level to the model's own read of this
    // location, rather than guessing — same data the citizen map shows.
    final nearestZone = await appState.riskRepository.getNearestZone(report.lat, report.lng);
    final riskLevel = nearestZone?.level ?? RiskLevel.moderate;

    await appState.taskRepository.createTask(
      InspectionTask(
        id: '',
        assignedOfficerUid: selected.uid,
        linkedReportId: report.id,
        lat: report.lat,
        lng: report.lng,
        riskLevel: riskLevel,
        reason: 'Citizen report: ${report.description}',
        instructions:
            'Field-verify the ${report.hazardType.label.toLowerCase()} reported at this '
            'location. Reporter notes: "${report.description}"',
        status: InspectionTaskStatus.assigned,
        createdAt: DateTime.now(),
        customBoundary: GeofenceBoundary.radius(
          centerLat: report.lat,
          centerLng: report.lng,
          radiusMeters: 500.0,
        ),
        assignmentType: AssignmentType.manual,
        assignedBy: appState.uid,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigned to ${selected.displayName ?? selected.email}.')),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final appState = context.read<AppState>();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dismiss Report'),
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
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // NOTE: the dismissal reason is not persisted — Report has no
    // reviewer-note field yet. Surfaced only in this confirmation for now.
    await appState.reportRepository.updateReportStatus(report.id, ReportStatus.rejected);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report dismissed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = report.mediaUrls.isEmpty ? null : report.mediaUrls.first;

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
            Text(report.description),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismiss(context),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _assign(context),
                    child: const Text('Assign Field Officer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignOfficerDialog extends StatefulWidget {
  final List<AppUser> officers;

  const _AssignOfficerDialog({required this.officers});

  @override
  State<_AssignOfficerDialog> createState() => _AssignOfficerDialogState();
}

class _AssignOfficerDialogState extends State<_AssignOfficerDialog> {
  late AppUser _selected = widget.officers.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Field Officer'),
      content: DropdownButtonFormField<AppUser>(
        initialValue: _selected,
        decoration: const InputDecoration(labelText: 'Field Officer'),
        items: [
          for (final officer in widget.officers)
            DropdownMenuItem(
              value: officer,
              child: Text(officer.displayName ?? officer.email),
            ),
        ],
        onChanged: (officer) => setState(() => _selected = officer ?? _selected),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String path;

  const _Thumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final image = path.startsWith('http') || kIsWeb
        ? Image.network(path, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 32))
        : const Icon(Icons.image, size: 32, color: Colors.blue);

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
      subtitle: Text(report.status.label),
      trailing: report.status == ReportStatus.verified
          ? TextButton(
              onPressed: () => context
                  .read<AppState>()
                  .reportRepository
                  .updateReportStatus(report.id, ReportStatus.resolved),
              child: const Text('Mark Resolved'),
            )
          : null,
    );
  }
}

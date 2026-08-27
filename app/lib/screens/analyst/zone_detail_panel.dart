import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../services/risk_factor_provider.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/risk_factor_bar.dart';
import '../../widgets/task_status_chip.dart';
import 'assign_officer_dialog.dart';

/// Opens the Analyst zone-detail panel (spec sections 5/6/7) as a large
/// modal sheet — matches the existing app's `showModalBottomSheet`
/// convention (see AnalystDashboardScreen._showZoneSheet), just with far
/// more content.
Future<void> showZoneDetailPanel(BuildContext context, RiskZone zone) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ZoneDetailSheet(zone: zone),
  );
}

/// Opens the shared officer picker (see assign_officer_dialog.dart) and, on
/// selection, creates a "notified" InspectionTask centered on [zone] —
/// mirrors AnalystAlertsScreen's own notify action so both entry points
/// behave identically.
Future<void> _notifyFieldOfficer(BuildContext context, RiskZone zone) async {
  final appState = context.read<AppState>();
  final officers = await appState.authRepository.watchEnabledFieldOfficers().first;
  if (!context.mounted) return;

  if (officers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No approved Field Officer accounts yet.')),
    );
    return;
  }

  final officer = await pickFieldOfficer(context, officers);
  if (officer == null || !context.mounted) return;

  await notifyFieldOfficerAt(
    appState,
    officer: officer,
    lat: zone.lat,
    lng: zone.lng,
    riskLevel: zone.level,
    reason: 'Zone flagged for inspection: ${zone.name}',
    instructions: 'Inspect ${zone.name} (${zone.level.label} risk). Confirm current '
        'ground conditions and respond to this notification once reviewed.',
  );
  appState.recordActivity(
    'Notified ${officer.displayName ?? officer.email} to inspect ${zone.name}',
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Notified ${officer.displayName ?? officer.email} — awaiting response.'),
    ),
  );
}

class _ZoneDetailSheet extends StatelessWidget {
  final RiskZone zone;

  const _ZoneDetailSheet({required this.zone});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final assessment = appState.riskFactorProvider.assess(zone);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          context.isMobile ? 16 : 20,
          12,
          context.isMobile ? 16 : 20,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ZONE ID: ${zone.id}', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(zone.name, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        zone.district,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                RiskBadge(level: zone.level),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _notifyFieldOfficer(context, zone),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Notify Field Officer'),
              ),
            ),
            const SizedBox(height: 12),
            _ZoneTaskStatusSection(zone: zone),
            const SizedBox(height: 12),
            _KeyStatsGrid(zone: zone),
            const SizedBox(height: 24),
            Text('Susceptibility · Dynamic Risk · Event Prediction',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Three distinct concepts — see labels below. Demo-derived, not a '
              'scientifically validated prediction.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            _RiskConceptRow(assessment: assessment),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Why is this area ${zone.level.label.toLowerCase()} risk?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  'Confidence: ${assessment.confidencePercent.toStringAsFixed(0)}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final factor in assessment.factors) RiskFactorBarRow(factor: factor),
            if (zone.notes != null) ...[
              const SizedBox(height: 16),
              Text('Notes', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(zone.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live status of every InspectionTask centered on [zone] — matched by
/// exact lat/lng, which is reliable here since [_notifyFieldOfficer] (and
/// TasksScreen's Flag Zone flow) always creates the task at the zone's own
/// coordinates with no jitter. Updates via the same Firestore stream
/// TasksScreen already reads, so an officer's Accept lands here without a
/// manual refresh.
class _ZoneTaskStatusSection extends StatelessWidget {
  final RiskZone zone;

  const _ZoneTaskStatusSection({required this.zone});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return StreamBuilder<List<InspectionTask>>(
      stream: appState.taskRepository.watchAllTasks(),
      builder: (context, snapshot) {
        final tasks = (snapshot.data ?? const <InspectionTask>[])
            .where((t) => t.lat == zone.lat && t.lng == zone.lng)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (tasks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inspection Notifications', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final task in tasks) _ZoneTaskStatusRow(task: task),
          ],
        );
      },
    );
  }
}

class _ZoneTaskStatusRow extends StatelessWidget {
  final InspectionTask task;

  const _ZoneTaskStatusRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final subtitle = task.assignedOfficerUid == null
        ? 'Unassigned'
        : 'Officer ${task.assignedOfficerUid}'
            '${task.acceptedAt != null ? ' · accepted ${DateFormat('d MMM, HH:mm').format(task.acceptedAt!)}' : ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TaskStatusChip(status: task.status),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyStatsGrid extends StatelessWidget {
  final RiskZone zone;

  const _KeyStatsGrid({required this.zone});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('Risk Score', zone.riskScore.toStringAsFixed(2)),
      ('Location', '${zone.lat.toStringAsFixed(4)}, ${zone.lng.toStringAsFixed(4)}'),
      (
        'Slope',
        zone.slopeMaxDegrees > 0
            ? '${zone.slopeMinDegrees.toStringAsFixed(0)}°–${zone.slopeMaxDegrees.toStringAsFixed(0)}°'
            : 'No data',
      ),
      ('Rainfall (24h)', '${zone.rainfall24hMm.toStringAsFixed(1)} mm'),
      ('Soil Moisture', '${zone.soilMoisturePercent.toStringAsFixed(0)}%'),
      ('Historical Events', '${zone.historicalEventCount}'),
      ('Nearest Road', '${zone.nearestRoadKm.toStringAsFixed(1)} km'),
      ('Lithology', zone.lithology),
      ('LULC', zone.lulc),
      ('Model Confidence', '${zone.confidencePercent.toStringAsFixed(0)}%'),
      ('Last Updated', DateFormat('d MMM y, HH:mm').format(zone.updatedAt)),
    ];

    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        for (final (label, value) in entries)
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _RiskConceptRow extends StatelessWidget {
  final RiskAssessment assessment;

  const _RiskConceptRow({required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ConceptCard(
          title: 'SUSCEPTIBILITY',
          subtitle: 'Long-term terrain tendency',
          score: assessment.susceptibilityScore,
        ),
        _ConceptCard(
          title: 'DYNAMIC RISK',
          subtitle: 'Current conditions',
          score: assessment.dynamicRiskScore,
        ),
        _ConceptCard(
          title: 'EVENT PREDICTION',
          subtitle: 'Probability in prediction window',
          score: assessment.eventPredictionProbability,
        ),
      ],
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double score;

  const _ConceptCard({required this.title, required this.subtitle, required this.score});

  RiskLevel get _level {
    if (score >= 0.75) return RiskLevel.critical;
    if (score >= 0.5) return RiskLevel.high;
    if (score >= 0.25) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorForRisk(_level);
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            score.toStringAsFixed(2),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../models/app_user.dart';
import '../../models/report.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../services/auto_assignment_service.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/hazard_icons.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/task_status_chip.dart';
import 'zone_detail_panel.dart';

const _openReportStatuses = {ReportStatus.submitted, ReportStatus.underReview};

/// One-glance view of the whole system: headline stats + a toggleable map.
/// The stat counts are all computed client-side from the same
/// streams/lists the other Analyst screens already use — no separate
/// aggregation backend needed for a prototype this size.
class AnalystDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenReportsQueue;
  final void Function({RiskLevel? severityFilter})? onOpenRiskMap;
  final VoidCallback? onOpenAlerts;
  final VoidCallback? onOpenInspections;

  const AnalystDashboardScreen({
    super.key,
    this.onOpenReportsQueue,
    this.onOpenRiskMap,
    this.onOpenAlerts,
    this.onOpenInspections,
  });

  @override
  State<AnalystDashboardScreen> createState() => _AnalystDashboardScreenState();
}

class _AnalystDashboardScreenState extends State<AnalystDashboardScreen> {
  List<RiskZone> _zones = [];
  List<HazardAlert> _alerts = [];
  bool _loadingStatic = true;
  String? _loadError;

  // Deliberately independent from RiskMapScreen's own _showRiskZones/
  // _showCitizenReports/_showFieldOfficers toggles (see risk_map_screen.dart)
  // rather than lifted into shared state — this mini-map is a compact
  // at-a-glance summary embedded in the dashboard, not the same GIS session
  // as the dedicated Risk Map page, so there's no expectation a toggle here
  // should carry over there (or vice versa). Revisit if that assumption
  // turns out to be wrong in practice.
  bool _showZones = true;
  bool _showReportPins = true;
  bool _showTaskPins = false;

  @override
  void initState() {
    super.initState();
    _loadStatic();
  }

  Future<void> _loadStatic() async {
    setState(() {
      _loadingStatic = true;
      _loadError = null;
    });
    final appState = context.read<AppState>();
    try {
      final zones = await appState.riskRepository.getRiskZones();
      final alerts = await appState.alertRepository.getAlerts();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _alerts = alerts;
        _loadingStatic = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load dashboard data: $e';
        _loadingStatic = false;
      });
    }
  }

  void _showZoneSheet(RiskZone zone) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(zone.name, style: Theme.of(sheetContext).textTheme.titleMedium),
                ),
                RiskBadge(level: zone.level),
              ],
            ),
            const SizedBox(height: 8),
            Text(zone.district),
            Text('Lat ${zone.lat.toStringAsFixed(4)}, Lng ${zone.lng.toStringAsFixed(4)}'),
            if (zone.notes != null) ...[
              const SizedBox(height: 8),
              Text(zone.notes!),
            ],
            const SizedBox(height: 16),
            if (Breakpoints.mobile > MediaQuery.of(sheetContext).size.width)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        showZoneDetailPanel(context, zone);
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Full Details'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _simulateAiDetection(sheetContext, zone),
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text('Simulate AI Detection'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        showZoneDetailPanel(context, zone);
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Full Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _simulateAiDetection(sheetContext, zone),
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text('Simulate AI Detection'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Demo-only stand-in for a real risk-engine trigger (no FastAPI backend
  /// exists yet — see services/auto_assignment_service.dart). Creates an
  /// automatically-assigned inspection task for [zone] exactly as a future
  /// real trigger would, just fired by hand from here instead of a
  /// scheduled/event-driven backend job.
  Future<void> _simulateAiDetection(BuildContext sheetContext, RiskZone zone) async {
    final appState = context.read<AppState>();
    Navigator.of(sheetContext).pop();

    final task = await autoAssignInspection(
      zone: zone,
      taskRepository: appState.taskRepository,
      authRepository: appState.authRepository,
    );
    appState.recordActivity(
      task.assignedOfficerUid == null
          ? 'Simulated AI detection at ${zone.name} — no Field Officer available, task left unassigned'
          : 'Simulated AI detection at ${zone.name} — task auto-assigned',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          task.assignedOfficerUid == null
              ? 'Task created for ${zone.name}, but no Field Officer is available — left unassigned.'
              : 'Task auto-assigned for ${zone.name}.',
        ),
      ),
    );
  }

  void _showReportSheet(Report report) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconForHazard(report.hazardType)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.hazardType.label, style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(report.status.label),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.description),
            const SizedBox(height: 16),
            if (_openReportStatuses.contains(report.status))
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenReportsQueue?.call();
                },
                child: const Text('Open in Reports Queue'),
              ),
          ],
        ),
      ),
    );
  }

  RiskZone? get _mostCriticalZone {
    if (_zones.isEmpty) return null;
    final sorted = [..._zones]..sort((a, b) {
        final byLevel = b.level.index.compareTo(a.level.index);
        if (byLevel != 0) return byLevel;
        return b.riskScore.compareTo(a.riskScore);
      });
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final highRiskZoneCount =
        _zones.where((z) => z.level == RiskLevel.high || z.level == RiskLevel.critical).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStatic),
        ],
      ),
      body: Builder(
        builder: (context) {
          // The dashboard's headline numbers (risk zones, alerts) come from
          // one static load — that's the screen's primary loading/error
          // surface. The task/officer/report streams below it only feed
          // small supplementary counts and map pins, so a transient error
          // on one of those just shows as 0/empty rather than blocking the
          // whole dashboard.
          if (_loadingStatic) return const LoadingView();
          if (_loadError != null) {
            return ErrorStateView(message: _loadError!, onRetry: _loadStatic);
          }

          return StreamBuilder<List<InspectionTask>>(
            stream: appState.taskRepository.watchAllTasks(),
            builder: (context, taskSnapshot) {
              final tasks = taskSnapshot.data ?? const <InspectionTask>[];
              final pendingInspectionCount =
                  tasks.where((t) => t.status == InspectionTaskStatus.unassigned).length;

              return StreamBuilder<List<AppUser>>(
                stream: appState.authRepository.watchEnabledFieldOfficers(),
                builder: (context, officerSnapshot) {
                  final officerCount = officerSnapshot.data?.length ?? 0;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.isMobile ? 12 : 16,
                            16,
                            context.isMobile ? 12 : 16,
                            0,
                          ),
                          child: _SummaryCardsRow(
                            highRiskZoneCount: highRiskZoneCount,
                            activeAlertCount: _alerts.length,
                            pendingInspectionCount: pendingInspectionCount,
                            fieldOfficerCount: officerCount,
                            onOpenRiskMap: widget.onOpenRiskMap,
                            onOpenAlerts: widget.onOpenAlerts,
                            onOpenInspections: widget.onOpenInspections,
                          ),
                        ),
                        if (_mostCriticalZone != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              context.isMobile ? 12 : 16,
                              12,
                              context.isMobile ? 12 : 16,
                              0,
                            ),
                            child: _AiRiskStatusCard(
                              zone: _mostCriticalZone!,
                              onViewFactors: () => showZoneDetailPanel(context, _mostCriticalZone!),
                            ),
                          ),
                        _LayerToggles(
                          showZones: _showZones,
                          showReportPins: _showReportPins,
                          showTaskPins: _showTaskPins,
                          onZonesChanged: (v) => setState(() => _showZones = v),
                          onReportPinsChanged: (v) => setState(() => _showReportPins = v),
                          onTaskPinsChanged: (v) => setState(() => _showTaskPins = v),
                        ),
                        SizedBox(
                          height: context.responsiveValue(mobile: 260, tablet: 340, desktop: 420),
                          child: StreamBuilder<List<Report>>(
                            stream: appState.reportRepository.watchAllReports(),
                            builder: (context, reportSnapshot) {
                              final reports = reportSnapshot.data ?? const <Report>[];
                              return _DashboardMap(
                                zones: _showZones ? _zones : const [],
                                reports: _showReportPins ? reports : const [],
                                tasks: _showTaskPins ? tasks : const [],
                                onZoneTap: _showZoneSheet,
                                onReportTap: _showReportSheet,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  final int highRiskZoneCount;
  final int activeAlertCount;
  final int pendingInspectionCount;
  final int fieldOfficerCount;
  final void Function({RiskLevel? severityFilter})? onOpenRiskMap;
  final VoidCallback? onOpenAlerts;
  final VoidCallback? onOpenInspections;

  const _SummaryCardsRow({
    required this.highRiskZoneCount,
    required this.activeAlertCount,
    required this.pendingInspectionCount,
    required this.fieldOfficerCount,
    this.onOpenRiskMap,
    this.onOpenAlerts,
    this.onOpenInspections,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 5 : (constraints.maxWidth >= 560 ? 3 : 2);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            StatTile(
              icon: Icons.warning_amber,
              value: highRiskZoneCount.toString().padLeft(2, '0'),
              label: 'High Risk Zones',
              color: AppTheme.colorForRisk(RiskLevel.high),
              onTap: () => onOpenRiskMap?.call(severityFilter: RiskLevel.high),
            ),
            StatTile(
              icon: Icons.campaign,
              value: activeAlertCount.toString().padLeft(2, '0'),
              label: 'Active Alerts',
              onTap: onOpenAlerts,
            ),
            StatTile(
              icon: Icons.assignment_late_outlined,
              value: pendingInspectionCount.toString().padLeft(2, '0'),
              label: 'Pending Inspections',
              onTap: onOpenInspections,
            ),
            StatTile(
              icon: Icons.badge_outlined,
              value: fieldOfficerCount.toString().padLeft(2, '0'),
              label: 'Field Officers Active',
            ),
            // No sensor network is wired up yet (see spec scope for this
            // pass) — shown honestly as zero rather than a fabricated
            // number. Once services/sensor_repository.dart exists, wire
            // this to a real stream the same way the other cards are.
            const StatTile(
              icon: Icons.sensors_outlined,
              value: '00',
              label: 'Sensor Alerts',
            ),
          ],
        );
      },
    );
  }
}

class _AiRiskStatusCard extends StatelessWidget {
  final RiskZone zone;
  final VoidCallback onViewFactors;

  const _AiRiskStatusCard({required this.zone, required this.onViewFactors});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final assessment = appState.riskFactorProvider.assess(zone);
    final color = AppTheme.colorForRisk(zone.level);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: color),
                const SizedBox(width: 8),
                Text('AI/ML RISK STATUS', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Flexible(
                  child: Text(
                    zone.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _AiStat(label: 'CURRENT RISK', value: zone.level.label.toUpperCase(), color: color),
                _AiStat(label: 'RISK SCORE', value: assessment.dynamicRiskScore.toStringAsFixed(2)),
                _AiStat(label: 'CONFIDENCE', value: '${assessment.confidencePercent.toStringAsFixed(0)}%'),
                _AiStat(label: 'LAST UPDATED', value: DateFormat('HH:mm').format(assessment.lastUpdated)),
                _AiStat(label: 'PREDICTION STATUS', value: assessment.predictionStatus),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onViewFactors,
                icon: const Icon(Icons.bar_chart),
                label: const Text('VIEW RISK FACTORS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _AiStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LayerToggles extends StatelessWidget {
  final bool showZones;
  final bool showReportPins;
  final bool showTaskPins;
  final ValueChanged<bool> onZonesChanged;
  final ValueChanged<bool> onReportPinsChanged;
  final ValueChanged<bool> onTaskPinsChanged;

  const _LayerToggles({
    required this.showZones,
    required this.showReportPins,
    required this.showTaskPins,
    required this.onZonesChanged,
    required this.onReportPinsChanged,
    required this.onTaskPinsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Risk zones'),
            selected: showZones,
            onSelected: onZonesChanged,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Citizen reports'),
            selected: showReportPins,
            onSelected: onReportPinsChanged,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Field tasks'),
            selected: showTaskPins,
            onSelected: onTaskPinsChanged,
          ),
        ],
      ),
    );
  }
}

class _DashboardMap extends StatelessWidget {
  final List<RiskZone> zones;
  final List<Report> reports;
  final List<InspectionTask> tasks;
  final ValueChanged<RiskZone> onZoneTap;
  final ValueChanged<Report> onReportTap;

  const _DashboardMap({
    required this.zones,
    required this.reports,
    required this.tasks,
    required this.onZoneTap,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(AppConfig.studyAreaCenterLat, AppConfig.studyAreaCenterLng),
        initialZoom: AppConfig.defaultMapZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ner.landslide.landslide_ews',
        ),
        MarkerLayer(
          markers: [
            for (final zone in zones)
              Marker(
                point: LatLng(zone.lat, zone.lng),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => onZoneTap(zone),
                  child: Icon(Icons.location_on, color: AppTheme.colorForRisk(zone.level), size: 36),
                ),
              ),
            for (final report in reports)
              Marker(
                point: LatLng(report.lat, report.lng),
                width: 32,
                height: 32,
                child: GestureDetector(
                  onTap: () => onReportTap(report),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: Icon(iconForHazard(report.hazardType), size: 16, color: Colors.white),
                  ),
                ),
              ),
            for (final task in tasks)
              Marker(
                point: LatLng(task.lat, task.lng),
                width: 28,
                height: 28,
                child: Icon(Icons.assignment, color: colorForTaskStatus(task.status), size: 28),
              ),
          ],
        ),
      ],
    );
  }
}

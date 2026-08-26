import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../models/report.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../widgets/hazard_icons.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/task_status_chip.dart';

const _openReportStatuses = {ReportStatus.submitted, ReportStatus.underReview};
const _activeTaskStatuses = {
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
};

/// One-glance view of the whole system: headline stats + a toggleable map.
/// The stat counts are all computed client-side from the same
/// streams/lists the other Analyst screens already use — no separate
/// aggregation backend needed for a prototype this size.
class AnalystDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenReportsQueue;

  const AnalystDashboardScreen({super.key, this.onOpenReportsQueue});

  @override
  State<AnalystDashboardScreen> createState() => _AnalystDashboardScreenState();
}

class _AnalystDashboardScreenState extends State<AnalystDashboardScreen> {
  List<RiskZone> _zones = [];
  List<HazardAlert> _alerts = [];
  bool _loadingStatic = true;

  bool _showZones = true;
  bool _showReportPins = true;
  bool _showTaskPins = false;

  @override
  void initState() {
    super.initState();
    _loadStatic();
  }

  Future<void> _loadStatic() async {
    final appState = context.read<AppState>();
    final zones = await appState.riskRepository.getRiskZones();
    final alerts = await appState.alertRepository.getAlerts();
    if (!mounted) return;
    setState(() {
      _zones = zones;
      _alerts = alerts;
      _loadingStatic = false;
    });
  }

  void _showZoneSheet(RiskZone zone) {
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
                Expanded(
                  child: Text(zone.name, style: Theme.of(context).textTheme.titleMedium),
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
          ],
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final criticalZoneCount = _zones.where((z) => z.level == RiskLevel.critical).length;
    final recentAlertCount = _alerts
        .where((a) => DateTime.now().difference(a.createdAt) <= const Duration(days: 7))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStatic),
        ],
      ),
      body: StreamBuilder<List<Report>>(
        stream: appState.reportRepository.watchAllReports(),
        builder: (context, reportSnapshot) {
          final reports = reportSnapshot.data ?? const <Report>[];
          final openReportCount =
              reports.where((r) => _openReportStatuses.contains(r.status)).length;

          return StreamBuilder<List<InspectionTask>>(
            stream: appState.taskRepository.watchAllTasks(),
            builder: (context, taskSnapshot) {
              final tasks = taskSnapshot.data ?? const <InspectionTask>[];
              final activeTaskCount =
                  tasks.where((t) => _activeTaskStatuses.contains(t.status)).length;

              if (_loadingStatic) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      children: [
                        StatTile(
                          icon: Icons.inbox,
                          value: '$openReportCount',
                          label: 'Open reports',
                        ),
                        StatTile(
                          icon: Icons.assignment,
                          value: '$activeTaskCount',
                          label: 'Active field tasks',
                        ),
                        StatTile(
                          icon: Icons.warning_amber,
                          value: '$criticalZoneCount',
                          label: 'Critical risk zones',
                          color: AppTheme.colorForRisk(RiskLevel.critical),
                        ),
                        StatTile(
                          icon: Icons.campaign,
                          value: '$recentAlertCount',
                          label: 'Alerts (last 7 days)',
                        ),
                      ],
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
                  Expanded(
                    child: _DashboardMap(
                      zones: _showZones ? _zones : const [],
                      reports: _showReportPins ? reports : const [],
                      tasks: _showTaskPins ? tasks : const [],
                      onZoneTap: _showZoneSheet,
                      onReportTap: _showReportSheet,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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

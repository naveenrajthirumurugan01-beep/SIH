import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/date_range_filter.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/historical_landslide.dart';
import '../../models/report.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../services/report_severity.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/hazard_icons.dart';
import '../../widgets/task_status_chip.dart';
import 'zone_detail_panel.dart';

const _activeOfficerTaskStatuses = {
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
};

/// The Analyst's dedicated, full-size Dibang Valley risk map (spec section
/// 4), with a toggleable GIS layer panel (Phase 2 section 6). Every
/// data-backed layer here reuses an existing repository/stream — there is
/// no fabricated roads/rivers/villages/satellite geometry: those layers are
/// present as disabled entries labeled "no data source yet" rather than
/// invented for the demo.
class RiskMapScreen extends StatefulWidget {
  /// When set, the page opens pre-filtered to this severity (e.g. reached
  /// from the dashboard's "High Risk Zones" summary card) — still
  /// changeable from the filter row.
  final RiskLevel? initialSeverityFilter;

  const RiskMapScreen({super.key, this.initialSeverityFilter});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  final MapController _mapController = MapController();
  List<RiskZone>? _zones;
  List<HistoricalLandslide> _historicalLandslides = [];
  RiskLevel? _filter;
  bool _layerPanelOpen = false;
  String? _loadError;

  bool _showRiskZones = true;
  bool _showHistoricalLandslides = false;
  bool _showCitizenReports = false;
  bool _showFieldOfficers = false;
  bool _showInspectionZones = false;
  bool _showSensors = false;
  DateRangePreset _historicalDateFilter = DateRangePreset.allTime;

  /// True if [level] should be shown under the current severity filter —
  /// shared by every layer with a risk/severity concept (zones, tasks,
  /// reports via their inferred severity, historical events via their
  /// related zone's level) so picking a severity narrows all of them
  /// together, not just the risk-zone markers.
  bool _matchesSeverity(RiskLevel level) => _filter == null || level == _filter;

  static const _initialCenter = LatLng(AppConfig.studyAreaCenterLat, AppConfig.studyAreaCenterLng);
  static const _initialZoom = AppConfig.defaultMapZoom;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialSeverityFilter;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _zones = null;
      _loadError = null;
    });
    final appState = context.read<AppState>();
    try {
      final zones = await appState.riskRepository.getRiskZones();
      final historicalLandslides =
          await appState.historicalLandslideRepository.getHistoricalLandslides();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _historicalLandslides = historicalLandslides;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load the risk map: $e');
    }
  }

  void _resetView() {
    _mapController.move(_initialCenter, _initialZoom);
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3, 18));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final zones = _zones;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.isMobile ? 12 : 16, 12, context.isMobile ? 12 : 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Dibang Valley Risk Map',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'GIS Layers',
                  icon: Icon(_layerPanelOpen ? Icons.layers : Icons.layers_outlined),
                  onPressed: () => setState(() => _layerPanelOpen = !_layerPanelOpen),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Applies to every layer with a risk/severity concept, not
                // just Risk Zones — see _matchesSeverity.
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                for (final level in RiskLevel.values) ...[
                  ChoiceChip(
                    label: Text(level.label),
                    selected: _filter == level,
                    onSelected: (_) => setState(() => _filter = level),
                    avatar: CircleAvatar(backgroundColor: AppTheme.colorForRisk(level), radius: 6),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadError != null
                ? ErrorStateView(message: _loadError!, onRetry: _load)
                : zones == null
                ? const LoadingView()
                : StreamBuilder<List<Report>>(
                    stream: appState.reportRepository.watchAllReports(),
                    builder: (context, reportSnapshot) {
                      final reports = reportSnapshot.data ?? const <Report>[];
                      return StreamBuilder<List<InspectionTask>>(
                        stream: appState.taskRepository.watchAllTasks(),
                        builder: (context, taskSnapshot) {
                          final tasks = taskSnapshot.data ?? const <InspectionTask>[];
                          return StreamBuilder<List<AppUser>>(
                            stream: appState.authRepository.watchEnabledFieldOfficers(),
                            builder: (context, officerSnapshot) {
                              final officers = officerSnapshot.data ?? const <AppUser>[];
                              final enabledOfficerUids = officers.map((o) => o.uid).toSet();
                              // Keyed off the full (unfiltered) zone list so
                              // a historical event still resolves to its
                              // zone's level even when that zone itself is
                              // filtered out of the Risk Zones layer.
                              final zoneLevelById = {for (final z in zones) z.id: z.level};

                              return Stack(
                                children: [
                                  _GisMap(
                                    controller: _mapController,
                                    zones: _showRiskZones
                                        ? zones.where((z) => _matchesSeverity(z.level)).toList()
                                        : const [],
                                    historicalLandslides: _showHistoricalLandslides
                                        ? _historicalLandslides.where((e) {
                                            if (!_historicalDateFilter.includes(e.eventDate)) {
                                              return false;
                                            }
                                            final zoneLevel = zoneLevelById[e.relatedZoneId];
                                            return zoneLevel != null && _matchesSeverity(zoneLevel);
                                          }).toList()
                                        : const [],
                                    reports: _showCitizenReports
                                        ? reports
                                            .where((r) => _matchesSeverity(inferredSeverityForReport(r)))
                                            .toList()
                                        : const [],
                                    inspectionZoneTasks: _showInspectionZones
                                        ? tasks.where((t) => _matchesSeverity(t.riskLevel)).toList()
                                        : const [],
                                    officerTasks: _showFieldOfficers
                                        ? tasks
                                            .where((t) =>
                                                t.assignedOfficerUid != null &&
                                                enabledOfficerUids.contains(t.assignedOfficerUid) &&
                                                _activeOfficerTaskStatuses.contains(t.status) &&
                                                _matchesSeverity(t.riskLevel))
                                            .toList()
                                        : const [],
                                    onZoneTap: (zone) => showZoneDetailPanel(context, zone),
                                  ),
                                  Positioned(
                                    right: 12,
                                    bottom: 90,
                                    child: Column(
                                      children: [
                                        _MapButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                                        const SizedBox(height: 8),
                                        _MapButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                                        const SizedBox(height: 8),
                                        _MapButton(
                                          icon: Icons.center_focus_strong,
                                          onTap: _resetView,
                                          tooltip: 'Reset view',
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_showRiskZones)
                                    const Positioned(left: 12, bottom: 12, child: _Legend()),
                                  if (_showRiskZones && zones.isEmpty)
                                    const Positioned(
                                      left: 12,
                                      top: 12,
                                      child: _EmptyLayerNote(message: 'No risk zones seeded yet.'),
                                    ),
                                  if (_showHistoricalLandslides && _historicalLandslides.isEmpty)
                                    Positioned(
                                      left: 12,
                                      top: _showRiskZones && zones.isEmpty ? 56 : 12,
                                      child: const _EmptyLayerNote(
                                        message: 'No historical landslide records yet.',
                                      ),
                                    ),
                                  if (_showSensors && _showRiskZones)
                                    const Positioned(
                                      left: 12,
                                      bottom: 148,
                                      child: _EmptyLayerNote(
                                        message: 'No sensor network deployed yet — layer is empty by design.',
                                      ),
                                    ),
                                  if (_showSensors && !_showRiskZones)
                                    const Positioned(
                                      left: 12,
                                      bottom: 12,
                                      child: _EmptyLayerNote(
                                        message: 'No sensor network deployed yet — layer is empty by design.',
                                      ),
                                    ),
                                  if (_layerPanelOpen)
                                    Positioned(
                                      right: 12,
                                      top: 12,
                                      child: _GisLayerPanel(
                                        // Narrower than the desktop 260px so the panel doesn't
                                        // dominate a phone-width map view; never wider than the
                                        // screen itself minus margins.
                                        width: context.isMobile
                                            ? (MediaQuery.of(context).size.width - 24)
                                                .clamp(180.0, 220.0)
                                            : 260,
                                        showRiskZones: _showRiskZones,
                                        showHistoricalLandslides: _showHistoricalLandslides,
                                        showCitizenReports: _showCitizenReports,
                                        showFieldOfficers: _showFieldOfficers,
                                        showInspectionZones: _showInspectionZones,
                                        showSensors: _showSensors,
                                        historicalDateFilter: _historicalDateFilter,
                                        onRiskZonesChanged: (v) => setState(() => _showRiskZones = v),
                                        onHistoricalLandslidesChanged: (v) =>
                                            setState(() => _showHistoricalLandslides = v),
                                        onCitizenReportsChanged: (v) =>
                                            setState(() => _showCitizenReports = v),
                                        onFieldOfficersChanged: (v) =>
                                            setState(() => _showFieldOfficers = v),
                                        onInspectionZonesChanged: (v) =>
                                            setState(() => _showInspectionZones = v),
                                        onSensorsChanged: (v) => setState(() => _showSensors = v),
                                        onHistoricalDateFilterChanged: (v) =>
                                            setState(() => _historicalDateFilter = v),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLayerNote extends StatelessWidget {
  final String message;

  const _EmptyLayerNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _GisLayerPanel extends StatelessWidget {
  final double width;
  final bool showRiskZones;
  final bool showHistoricalLandslides;
  final bool showCitizenReports;
  final bool showFieldOfficers;
  final bool showInspectionZones;
  final bool showSensors;
  final DateRangePreset historicalDateFilter;
  final ValueChanged<bool> onRiskZonesChanged;
  final ValueChanged<bool> onHistoricalLandslidesChanged;
  final ValueChanged<bool> onCitizenReportsChanged;
  final ValueChanged<bool> onFieldOfficersChanged;
  final ValueChanged<bool> onInspectionZonesChanged;
  final ValueChanged<bool> onSensorsChanged;
  final ValueChanged<DateRangePreset> onHistoricalDateFilterChanged;

  const _GisLayerPanel({
    this.width = 260,
    required this.showRiskZones,
    required this.showHistoricalLandslides,
    required this.showCitizenReports,
    required this.showFieldOfficers,
    required this.showInspectionZones,
    required this.showSensors,
    required this.historicalDateFilter,
    required this.onRiskZonesChanged,
    required this.onHistoricalLandslidesChanged,
    required this.onCitizenReportsChanged,
    required this.onFieldOfficersChanged,
    required this.onInspectionZonesChanged,
    required this.onSensorsChanged,
    required this.onHistoricalDateFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('GIS Layers', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            CheckboxListTile(
              dense: true,
              title: const Text('Landslide Risk Zones'),
              value: showRiskZones,
              onChanged: (v) => onRiskZonesChanged(v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Historical Landslides'),
              value: showHistoricalLandslides,
              onChanged: (v) => onHistoricalLandslidesChanged(v ?? false),
            ),
            if (showHistoricalLandslides)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final preset in DateRangePreset.values)
                      ChoiceChip(
                        label: Text(preset.label, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        selected: historicalDateFilter == preset,
                        onSelected: (_) => onHistoricalDateFilterChanged(preset),
                      ),
                  ],
                ),
              ),
            CheckboxListTile(
              dense: true,
              title: const Text('Citizen Reports'),
              value: showCitizenReports,
              onChanged: (v) => onCitizenReportsChanged(v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Field Officers'),
              value: showFieldOfficers,
              onChanged: (v) => onFieldOfficersChanged(v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Inspection Zones'),
              value: showInspectionZones,
              onChanged: (v) => onInspectionZonesChanged(v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Sensors'),
              value: showSensors,
              onChanged: (v) => onSensorsChanged(v ?? false),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'No data source wired up yet:',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
            for (final label in const [
              'Roads',
              'Rivers / Drainage',
              'Villages',
              'Slope',
              'LULC',
              'Lithology',
              'Lineaments',
              'Satellite Imagery',
            ])
              CheckboxListTile(
                dense: true,
                enabled: false,
                title: Text(label, style: const TextStyle(color: Colors.grey)),
                value: false,
                onChanged: null,
              ),
          ],
        ),
      ),
    );
  }
}

class _GisMap extends StatelessWidget {
  final MapController controller;
  final List<RiskZone> zones;
  final List<HistoricalLandslide> historicalLandslides;
  final List<Report> reports;
  final List<InspectionTask> inspectionZoneTasks;
  final List<InspectionTask> officerTasks;
  final ValueChanged<RiskZone> onZoneTap;

  const _GisMap({
    required this.controller,
    required this.zones,
    required this.historicalLandslides,
    required this.reports,
    required this.inspectionZoneTasks,
    required this.officerTasks,
    required this.onZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: const MapOptions(
        initialCenter: LatLng(AppConfig.studyAreaCenterLat, AppConfig.studyAreaCenterLng),
        initialZoom: AppConfig.defaultMapZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ner.landslide.landslide_ews',
        ),
        CircleLayer(
          circles: [
            for (final zone in zones)
              CircleMarker(
                point: LatLng(zone.lat, zone.lng),
                radius: zone.radiusKm * 1000,
                useRadiusInMeter: true,
                color: AppTheme.colorForRisk(zone.level).withValues(alpha: 0.18),
                borderColor: AppTheme.colorForRisk(zone.level),
                borderStrokeWidth: 1.5,
              ),
            for (final task in inspectionZoneTasks)
              CircleMarker(
                point: LatLng(task.lat, task.lng),
                radius: task.geofence.radiusMeters,
                useRadiusInMeter: true,
                color: colorForTaskStatus(task.status).withValues(alpha: 0.12),
                borderColor: colorForTaskStatus(task.status),
                borderStrokeWidth: 1.5,
              ),
          ],
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
            for (final event in historicalLandslides)
              Marker(
                point: LatLng(event.lat, event.lng),
                width: 28,
                height: 28,
                child: Tooltip(
                  message: '${event.locationName} — ${event.severity} (${event.eventDate.year})',
                  child: const Icon(Icons.history, color: Colors.deepPurple, size: 26),
                ),
              ),
            for (final report in reports)
              Marker(
                point: LatLng(report.lat, report.lng),
                width: 32,
                height: 32,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: Icon(iconForHazard(report.hazardType), size: 16, color: Colors.white),
                ),
              ),
            for (final task in officerTasks)
              Marker(
                point: LatLng(task.lat, task.lng),
                width: 32,
                height: 32,
                child: Tooltip(
                  message: 'Assigned zone (not live GPS) — ${task.reason}',
                  child: Icon(Icons.person_pin_circle, color: AppTheme.colorForRisk(task.riskLevel), size: 32),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _MapButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Risk level', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            for (final level in RiskLevel.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.colorForRisk(level),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(level.label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

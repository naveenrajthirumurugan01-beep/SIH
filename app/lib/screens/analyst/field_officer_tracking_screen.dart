import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/task.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/task_status_chip.dart';

const _activeTaskStatuses = {
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
};

/// Field Officer live tracking (spec section 11). There is no real GPS
/// stream from the Field Officer app yet — see the Field Officer geofence
/// check flow, which only reports a position at check-in/submission time,
/// not continuously — so this shows each officer's *assigned zone* as a
/// stand-in, honestly labeled, rather than inventing a live position.
class FieldOfficerTrackingScreen extends StatefulWidget {
  const FieldOfficerTrackingScreen({super.key});

  @override
  State<FieldOfficerTrackingScreen> createState() => _FieldOfficerTrackingScreenState();
}

class _FieldOfficerTrackingScreenState extends State<FieldOfficerTrackingScreen> {
  String? _selectedOfficerUid;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Field Officers')),
      body: StreamBuilder<List<AppUser>>(
        stream: appState.authRepository.watchEnabledFieldOfficers(),
        builder: (context, officerSnapshot) {
          if (officerSnapshot.hasError) {
            return ErrorStateView(
              message: 'Could not load Field Officers: ${officerSnapshot.error}',
              onRetry: () => setState(() {}),
            );
          }
          if (!officerSnapshot.hasData) {
            return const LoadingView();
          }
          final officers = officerSnapshot.data!;
          if (officers.isEmpty) {
            return const EmptyStateView(
              icon: Icons.groups_outlined,
              message: 'No enabled Field Officer accounts yet.',
            );
          }

          return StreamBuilder<List<InspectionTask>>(
            stream: appState.taskRepository.watchAllTasks(),
            builder: (context, taskSnapshot) {
              final tasks = taskSnapshot.data ?? const <InspectionTask>[];
              final isWide = MediaQuery.of(context).size.width >= 900;

              final list = ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: officers.length,
                itemBuilder: (context, index) {
                  final officer = officers[index];
                  final activeTask = _activeTaskFor(tasks, officer.uid);
                  return _OfficerCard(
                    officer: officer,
                    activeTask: activeTask,
                    selected: officer.uid == _selectedOfficerUid,
                    onTap: () => setState(() => _selectedOfficerUid = officer.uid),
                  );
                },
              );

              final selectedTask = _selectedOfficerUid == null
                  ? null
                  : _activeTaskFor(tasks, _selectedOfficerUid!);
              final map = _OfficerMap(task: selectedTask);

              if (!isWide) {
                return Column(
                  children: [
                    SizedBox(height: 320, child: map),
                    Expanded(child: list),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 360, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(child: map),
                ],
              );
            },
          );
        },
      ),
    );
  }

  InspectionTask? _activeTaskFor(List<InspectionTask> tasks, String officerUid) {
    for (final task in tasks) {
      if (task.assignedOfficerUid == officerUid && _activeTaskStatuses.contains(task.status)) {
        return task;
      }
    }
    return null;
  }
}

class _OfficerCard extends StatelessWidget {
  final AppUser officer;
  final InspectionTask? activeTask;
  final bool selected;
  final VoidCallback onTap;

  const _OfficerCard({
    required this.officer,
    required this.activeTask,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      officer.displayName ?? officer.email,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (activeTask != null) TaskStatusChip(status: activeTask!.status),
                ],
              ),
              Text(
                'Officer ID: ${officer.uid}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 6),
              if (activeTask == null)
                const Text('No active assignment.')
              else ...[
                Text('Assigned zone: ${activeTask!.reason}'),
                Text(
                  'Lat ${activeTask!.lat.toStringAsFixed(4)}, Lng ${activeTask!.lng.toStringAsFixed(4)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficerMap extends StatelessWidget {
  final InspectionTask? task;

  const _OfficerMap({required this.task});

  @override
  Widget build(BuildContext context) {
    final center = task != null
        ? LatLng(task!.lat, task!.lng)
        : const LatLng(AppConfig.studyAreaCenterLat, AppConfig.studyAreaCenterLng);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: task != null ? 13 : AppConfig.defaultMapZoom),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ner.landslide.landslide_ews',
            ),
            if (task != null) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: task!.geofence.radiusMeters,
                    useRadiusInMeter: true,
                    color: AppTheme.colorForRisk(task!.riskLevel).withValues(alpha: 0.15),
                    borderColor: AppTheme.colorForRisk(task!.riskLevel),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 36,
                    height: 36,
                    child: Icon(Icons.person_pin_circle, color: AppTheme.colorForRisk(task!.riskLevel), size: 36),
                  ),
                ],
              ),
            ],
          ],
        ),
        if (task == null)
          const Positioned(
            top: 12,
            left: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('Select an officer to see their assigned zone.'),
              ),
            ),
          )
        else
          Positioned(
            top: 12,
            left: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'Assigned zone — not a live GPS position (no continuous field-device tracking yet)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

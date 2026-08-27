import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/geo_utils.dart';
import '../../models/task.dart';
import '../../services/location_service.dart';
import '../../widgets/geofence_indicator.dart';
import 'inspection_form_screen.dart';

/// Minimum GPS accuracy (meters, per Geolocator's reported horizontal
/// accuracy) below which we don't trust the fix enough to silently accept
/// it — worse than this shows a warning instead of just proceeding.
const _minTrustedAccuracyMeters = 100.0;

/// Live distance-to-target check. The officer must physically be within
/// the task's geofence radius (set at task-creation time based on risk
/// severity — see core/geofence_utils.dart) before "Start Inspection"
/// unlocks — this is what makes the field report trustworthy (no
/// desk-filing an inspection from home).
class GeofenceCheckScreen extends StatefulWidget {
  final InspectionTask task;

  const GeofenceCheckScreen({super.key, required this.task});

  @override
  State<GeofenceCheckScreen> createState() => _GeofenceCheckScreenState();
}

class _GeofenceCheckScreenState extends State<GeofenceCheckScreen> {
  final _locationService = LocationService();
  StreamSubscription<Position>? _subscription;

  double? _distanceMeters;
  bool _isWithin = false;
  LatLng? _lastPosition;

  /// Null until a real GPS fix (via [LocationService.watchPositionRaw])
  /// comes in — the initial [LocationService.getCurrentOrFallback] call
  /// doesn't report accuracy, so it shouldn't trip the low-accuracy warning.
  double? _lastAccuracyMeters;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final initial = await _locationService.getCurrentOrFallback();
    _onPosition(point: initial, accuracyMeters: null);
    _subscription = _locationService.watchPositionRaw().listen(
          (position) => _onPosition(
            point: LatLng(position.latitude, position.longitude),
            accuracyMeters: position.accuracy,
          ),
        );
  }

  void _onPosition({required LatLng point, required double? accuracyMeters}) {
    if (!mounted) return;
    final geofence = widget.task.geofence;
    final meters = distanceMeters(
      point.latitude,
      point.longitude,
      geofence.centerLat,
      geofence.centerLng,
    );
    setState(() {
      _lastPosition = point;
      _lastAccuracyMeters = accuracyMeters;
      _distanceMeters = meters;
      _isWithin = isInsideGeofence(point.latitude, point.longitude, geofence);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (!_isWithin || _lastPosition == null) return;

    final appState = context.read<AppState>();
    await appState.taskRepository.updateTaskStatus(widget.task.id, InspectionTaskStatus.onSite);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionFormScreen(
          task: widget.task.copyWith(status: InspectionTaskStatus.onSite),
          checkInLat: _lastPosition!.latitude,
          checkInLng: _lastPosition!.longitude,
          checkInAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radiusMeters = widget.task.geofence.radiusMeters;
    final lowAccuracy =
        _lastAccuracyMeters != null && _lastAccuracyMeters! > _minTrustedAccuracyMeters;

    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Check')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_distanceMeters == null)
                const CircularProgressIndicator()
              else
                GeofenceProgressIndicator(
                  distanceMeters: _distanceMeters!,
                  radiusMeters: radiusMeters,
                ),
              const SizedBox(height: 16),
              if (lowAccuracy)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.gps_not_fixed, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS accuracy low (±${_lastAccuracyMeters!.toStringAsFixed(0)}m) — '
                          'move to open sky before relying on this check.',
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'You must be within ${radiusMeters.toStringAsFixed(0)}m of the target '
                'location before starting the inspection.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isWithin ? _proceed : null,
                child: const Text('Start Inspection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

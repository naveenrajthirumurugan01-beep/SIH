import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/geo_utils.dart';
import '../../models/task.dart';
import '../../services/location_service.dart';
import '../../widgets/geofence_indicator.dart';
import 'inspection_form_screen.dart';

const _geofenceRadiusMeters = 100.0;

/// Live distance-to-target check. The officer must physically be within
/// [_geofenceRadiusMeters] of the task location before "Start Inspection"
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
  StreamSubscription<LatLng>? _subscription;

  double? _distanceMeters;
  bool _isWithin = false;
  LatLng? _lastPosition;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final initial = await _locationService.getCurrentOrFallback();
    _onPosition(initial);
    _subscription = _locationService.watchPosition().listen(_onPosition);
  }

  void _onPosition(LatLng position) {
    if (!mounted) return;
    final meters = distanceMeters(
      position.latitude,
      position.longitude,
      widget.task.lat,
      widget.task.lng,
    );
    setState(() {
      _lastPosition = position;
      _distanceMeters = meters;
      _isWithin = isWithinGeofence(
        currentLat: position.latitude,
        currentLng: position.longitude,
        targetLat: widget.task.lat,
        targetLng: widget.task.lng,
        radiusMeters: _geofenceRadiusMeters,
      );
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
                  radiusMeters: _geofenceRadiusMeters,
                ),
              const SizedBox(height: 32),
              const Text(
                'You must be within the geofence around the target location '
                'before starting the inspection.',
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

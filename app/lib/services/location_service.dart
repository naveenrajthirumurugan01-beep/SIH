import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_config.dart';

enum FieldGpsStatus {
  disabled, // Location services disabled in device settings
  permissionDenied, // Location permission denied by user
  permissionDeniedForever, // Location permission permanently denied
  acquiring, // Acquiring satellite fix
  activeHighAccuracy, // Satellite fix acquired, accuracy <= 30m
  activeLowAccuracy, // Satellite fix acquired, but poor accuracy > 30m
  error, // System/Hardware error
}

class FieldGpsFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final FieldGpsStatus status;
  final String? errorMessage;

  const FieldGpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    required this.status,
    this.errorMessage,
  });

  /// Accuracy threshold <= 30m is required for reliable field inspection
  bool get isReliable =>
      status == FieldGpsStatus.activeHighAccuracy && accuracyMeters <= 30.0;

  String get accuracyLabel =>
      accuracyMeters <= 0 ? 'Unknown' : '±${accuracyMeters.toStringAsFixed(1)} m';
}

/// Wraps Geolocator to handle GPS permissions, location availability,
/// accuracy evaluation, and recovery actions for Field Officer inspections.
class LocationService {
  static const LatLng studyAreaCenter = LatLng(
    AppConfig.studyAreaCenterLat,
    AppConfig.studyAreaCenterLng,
  );

  /// Constant for accuracy classification
  static const double HighAccuracyThresholdMeters = 30.0;

  Future<FieldGpsFix> getFieldGpsFix() async {
    // 1. Check if device location services are enabled
    if (!await Geolocator.isLocationServiceEnabled()) {
      return FieldGpsFix(
        latitude: studyAreaCenter.latitude,
        longitude: studyAreaCenter.longitude,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
        status: FieldGpsStatus.disabled,
        errorMessage: 'Device GPS / Location Services are turned off.',
      );
    }

    // 2. Check & Request Permissions
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return FieldGpsFix(
          latitude: studyAreaCenter.latitude,
          longitude: studyAreaCenter.longitude,
          accuracyMeters: 0,
          timestamp: DateTime.now(),
          status: FieldGpsStatus.permissionDenied,
          errorMessage: 'Location permission was denied by user.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return FieldGpsFix(
        latitude: studyAreaCenter.latitude,
        longitude: studyAreaCenter.longitude,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
        status: FieldGpsStatus.permissionDeniedForever,
        errorMessage: 'Location permission is permanently denied in device settings.',
      );
    }

    // 3. Retrieve position with accuracy & timestamp
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final status = position.accuracy <= HighAccuracyThresholdMeters
          ? FieldGpsStatus.activeHighAccuracy
          : FieldGpsStatus.activeLowAccuracy;

      return FieldGpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp ?? DateTime.now(),
        status: status,
        errorMessage: status == FieldGpsStatus.activeLowAccuracy
            ? 'Weak GPS accuracy (${position.accuracy.toStringAsFixed(1)}m). Open sky view required.'
            : null,
      );
    } catch (e) {
      return FieldGpsFix(
        latitude: studyAreaCenter.latitude,
        longitude: studyAreaCenter.longitude,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
        status: FieldGpsStatus.error,
        errorMessage: 'Failed to acquire GPS fix: ${e.toString()}',
      );
    }
  }

  /// Live Stream of GPS position fixes for active Field Officer inspection
  Stream<FieldGpsFix> watchFieldGpsFix() async* {
    if (!await Geolocator.isLocationServiceEnabled()) {
      yield FieldGpsFix(
        latitude: studyAreaCenter.latitude,
        longitude: studyAreaCenter.longitude,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
        status: FieldGpsStatus.disabled,
        errorMessage: 'Device GPS / Location Services are turned off.',
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      yield FieldGpsFix(
        latitude: studyAreaCenter.latitude,
        longitude: studyAreaCenter.longitude,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
        status: permission == LocationPermission.deniedForever
            ? FieldGpsStatus.permissionDeniedForever
            : FieldGpsStatus.permissionDenied,
        errorMessage: 'Location permission required.',
      );
      return;
    }

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).map((position) {
      final status = position.accuracy <= HighAccuracyThresholdMeters
          ? FieldGpsStatus.activeHighAccuracy
          : FieldGpsStatus.activeLowAccuracy;

      return FieldGpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp ?? DateTime.now(),
        status: status,
        errorMessage: status == FieldGpsStatus.activeLowAccuracy
            ? 'Weak GPS accuracy (${position.accuracy.toStringAsFixed(1)}m). Open sky view required.'
            : null,
      );
    });
  }

  // Recovery Actions
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  Future<LatLng> getCurrentOrFallback() async {
    final fix = await getFieldGpsFix();
    return LatLng(fix.latitude, fix.longitude);
  }

  Stream<LatLng> watchPosition({int distanceFilterMeters = 5}) async* {
    yield* watchFieldGpsFix().map((fix) => LatLng(fix.latitude, fix.longitude));
  }
}

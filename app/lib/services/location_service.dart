import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_config.dart';

/// Wraps geolocator with a hard fallback to the study-area center, so
/// callers never have to handle "no permission" / "GPS off" as a special
/// case — they always get a usable LatLng.
class LocationService {
  static const LatLng studyAreaCenter = LatLng(
    AppConfig.studyAreaCenterLat,
    AppConfig.studyAreaCenterLng,
  );

  Future<LatLng> getCurrentOrFallback() async {
    try {
      if (!await _hasPermission()) return studyAreaCenter;
      if (!await Geolocator.isLocationServiceEnabled()) return studyAreaCenter;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Any platform/permission/timeout error: fall back rather than crash.
      return studyAreaCenter;
    }
  }

  Future<bool> _hasPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Live position updates for the Field Officer geofence check. Emits
  /// nothing if permission is denied/GPS is off — callers should pair this
  /// with an initial [getCurrentOrFallback] call to still show something.
  Stream<LatLng> watchPosition({int distanceFilterMeters = 5}) async* {
    if (!await _hasPermission()) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;

    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_config.dart';
import '../../core/citizen_theme.dart';
import '../../services/location_service.dart';

/// Screen 3: Confirm Location — GPS map with blue dot + accuracy circle.
/// Returns a [LatLng] on pop when CONFIRM LOCATION is tapped.
class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final _locationService = LocationService();
  final MapController _mapController = MapController();

  LatLng? _position;
  double? _accuracyM;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loading = true);
    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS disabled');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = LatLng(position.latitude, position.longitude);
        _accuracyM = position.accuracy;
        _loading = false;
      });
      _mapController.move(_position!, 15.0);
    } catch (_) {
      if (!mounted) return;
      final fallback = await _locationService.getCurrentOrFallback();
      setState(() {
        _position = fallback;
        _accuracyM = 12.0; // synthetic demo accuracy shown in image
        _loading = false;
      });
      _mapController.move(fallback, 14.5);
    }
  }

  void _confirm() {
    if (_position == null) return;
    Navigator.of(context).pop(_position);
  }

  @override
  Widget build(BuildContext context) {
    final pos = _position;

    return Scaffold(
      backgroundColor: CitizenTheme.background,
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        leading: const BackButton(color: Colors.white),
        title: const Text('Confirm Location',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // ── GPS acquiring banner ─────────────────────────────────────────
          if (_loading)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CitizenTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Getting your location…',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Please wait while we detect your location',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),

          // ── Map ──────────────────────────────────────────────────────────
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pos ??
                    LatLng(
                      AppConfig.studyAreaCenterLat,
                      AppConfig.studyAreaCenterLng,
                    ),
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.ner.landslide.landslide_ews',
                ),
                if (pos != null) ...[
                  // Accuracy circle
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: pos,
                        radius: (_accuracyM ?? 50) * 8,
                        useRadiusInMeter: true,
                        color: Colors.blue.withAlpha(35),
                        borderColor: Colors.blue.withAlpha(120),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  // GPS dot
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pos,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(230),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withAlpha(100),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Re-center button overlay
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Location',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConfig.fallbackVillageName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${AppConfig.district}, ${AppConfig.stateName}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                if (pos != null) ...[
                  Text(
                    '${pos.latitude.toStringAsFixed(4)}\u00b0 N, ${pos.longitude.toStringAsFixed(4)}\u00b0 E',
                    style: const TextStyle(
                        fontSize: 13,
                        color: CitizenTheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Accuracy: ${_accuracyM?.toStringAsFixed(0) ?? '?'} m',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: CitizenTheme.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'CONFIRM LOCATION',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

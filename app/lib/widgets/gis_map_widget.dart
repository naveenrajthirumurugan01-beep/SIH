import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/app_state.dart';
import '../core/citizen_theme.dart';
import '../models/risk_zone.dart';

enum MapBaseStyle { satellite, standard, weatherRadar, topo }

/// Classifies one of [RiskZone]'s demo-derived numeric factors into a
/// LOW/MODERATE/HIGH label for the compact factor-breakdown display. The
/// underlying numbers are demo/placeholder-shaped (see RiskZone's doc
/// comment) — this is presentation only, not a real severity model.
String _bandLabel(double value, {required double moderateAt, required double highAt}) {
  if (value >= highAt) return 'HIGH';
  if (value >= moderateAt) return 'MODERATE';
  return 'LOW';
}

/// High-Definition Watermark-Free Interactive GIS Map Component for Dibang Valley.
/// Uses ESRI Satellite World Imagery & OpenStreetMap standard tiles (100% free, 0 watermarks).
class GisMapWidget extends StatefulWidget {
  final double height;
  final bool isFullScreen;
  final VoidCallback? onOpenFullScreen;

  const GisMapWidget({
    super.key,
    this.height = 320,
    this.isFullScreen = false,
    this.onOpenFullScreen,
  });

  @override
  State<GisMapWidget> createState() => _GisMapWidgetState();
}

class _GisMapWidgetState extends State<GisMapWidget> {
  final MapController _mapController = MapController();
  static const _distance = Distance();

  List<RiskZone> _zones = [];

  // Default to Satellite Map as primary visual mode!
  MapBaseStyle _activeStyle = MapBaseStyle.satellite;
  bool _showRiskOverlay = true;
  bool _showGeofence = true;
  final bool _showVillages = true;

  // Geo-fence Radius
  double _geofenceRadiusKm = 5.0;

  // Location state
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    final zones = await appState.riskRepository.getRiskZones();
    final loc = appState.currentLocation;

    if (!mounted) return;
    setState(() {
      _zones = zones;
      _userLocation = loc;
    });
  }

  void _recenterGps() {
    final appState = context.read<AppState>();
    appState.refreshLocation().then((_) {
      final loc = appState.currentLocation;
      setState(() {
        _userLocation = loc;
      });
      _mapController.move(loc, 11.5);
    });
  }

  void _inspectZone(RiskZone zone, double distKm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RiskZoneDetailsSheet(
        zone: zone,
        distKm: distKm,
        geofenceRadiusKm: _geofenceRadiusKm,
      ),
    );
  }

  void _showLayersDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers_outlined, color: CitizenTheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Map Layers & Imagery Style',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Base Map Style Selection
                  const Text('MAP BASE STYLE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.satellite_alt, size: 16),
                        label: const Text('🛰 Satellite HD'),
                        selected: _activeStyle == MapBaseStyle.satellite,
                        onSelected: (_) {
                          setSheetState(() => _activeStyle = MapBaseStyle.satellite);
                          setState(() => _activeStyle = MapBaseStyle.satellite);
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.map, size: 16),
                        label: const Text('🗺 Standard Map'),
                        selected: _activeStyle == MapBaseStyle.standard,
                        onSelected: (_) {
                          setSheetState(() => _activeStyle = MapBaseStyle.standard);
                          setState(() => _activeStyle = MapBaseStyle.standard);
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.thunderstorm, size: 16),
                        label: const Text('🌧 Weather Radar'),
                        selected: _activeStyle == MapBaseStyle.weatherRadar,
                        onSelected: (_) {
                          setSheetState(() => _activeStyle = MapBaseStyle.weatherRadar);
                          setState(() => _activeStyle = MapBaseStyle.weatherRadar);
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.terrain, size: 16),
                        label: const Text('⛰ Topographic'),
                        selected: _activeStyle == MapBaseStyle.topo,
                        onSelected: (_) {
                          setSheetState(() => _activeStyle = MapBaseStyle.topo);
                          setState(() => _activeStyle = MapBaseStyle.topo);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Radius
                  const Text('GEO-FENCE MONITORING RADIUS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 5.0, label: Text('5 km')),
                      ButtonSegment(value: 10.0, label: Text('10 km')),
                      ButtonSegment(value: 25.0, label: Text('25 km')),
                    ],
                    selected: {_geofenceRadiusKm},
                    onSelectionChanged: (val) {
                      setSheetState(() => _geofenceRadiusKm = val.first);
                      setState(() => _geofenceRadiusKm = val.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Feature Switches
                  const Text('GIS OVERLAYS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  SwitchListTile(
                    title: const Text('Landslide Risk Heatmap Overlay'),
                    value: _showRiskOverlay,
                    activeTrackColor: CitizenTheme.primary,
                    onChanged: (v) {
                      setSheetState(() => _showRiskOverlay = v);
                      setState(() => _showRiskOverlay = v);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Geo-fence Radius Boundary'),
                    value: _showGeofence,
                    activeTrackColor: CitizenTheme.primary,
                    onChanged: (v) {
                      setSheetState(() => _showGeofence = v);
                      setState(() => _showGeofence = v);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 100% Watermark-Free & Reliable Tile URLs
  String _baseTileUrl() {
    switch (_activeStyle) {
      case MapBaseStyle.satellite:
        // ESRI Pristine Satellite World Imagery (100% Free, NO Watermarks, NO API key required!)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapBaseStyle.topo:
        // ESRI World Topo Map (Clean, NO Watermarks!)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
      case MapBaseStyle.weatherRadar:
      case MapBaseStyle.standard:
        // Official OpenStreetMap Standard (Pristine, 100% Free, NO Watermarks!)
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  bool _isInsideGeofence(RiskZone z, LatLng userLoc) {
    final distKm = _distance.as(LengthUnit.Kilometer, userLoc, LatLng(z.lat, z.lng));
    return distKm <= _geofenceRadiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final userLoc = _userLocation ?? const LatLng(AppConfig.studyAreaCenterLat, AppConfig.studyAreaCenterLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.isFullScreen ? 0 : 12),
      child: SizedBox(
        height: widget.isFullScreen ? null : widget.height,
        child: Stack(
          children: [
            // ── 1. MAP CANVAS ────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(AppConfig.studyAreaCenterLat, AppConfig.studyAreaCenterLng),
                initialZoom: widget.isFullScreen ? 10.2 : 9.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // Clean Base Map Tile Layer (0 watermarks!)
                TileLayer(
                  urlTemplate: _baseTileUrl(),
                  userAgentPackageName: 'com.ner.landslide.landslide_ews',
                  maxZoom: 18,
                ),

                // Weather Radar Layer
                if (_activeStyle == MapBaseStyle.weatherRadar)
                  Opacity(
                    opacity: 0.55,
                    child: TileLayer(
                      urlTemplate: 'https://tilecache.rainviewer.com/v2/coverage/0/256/{z}/{x}/{y}/2/1_1.png',
                      userAgentPackageName: 'com.ner.landslide.landslide_ews',
                    ),
                  ),

                // Geo-fence Circle around Citizen
                if (_showGeofence)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: userLoc,
                        radius: _geofenceRadiusKm * 1000,
                        useRadiusInMeter: true,
                        color: Colors.blue.withAlpha(20),
                        borderColor: Colors.blue.shade400,
                        borderStrokeWidth: 2.0,
                      ),
                    ],
                  ),

                // Landslide Risk Polygons (Semi-Transparent Overlay)
                if (_showRiskOverlay)
                  PolygonLayer(
                    polygons: [
                      for (final z in _zones)
                        if (z.polygonPoints.isNotEmpty)
                          Polygon(
                            points: z.polygonPoints,
                            color: _isInsideGeofence(z, userLoc)
                                ? _colorForRisk(z.level).withAlpha(120)
                                : _colorForRisk(z.level).withAlpha(50),
                            borderColor: _colorForRisk(z.level),
                            borderStrokeWidth: _isInsideGeofence(z, userLoc) ? 2.5 : 1.2,
                          ),
                    ],
                  ),

                // Circular Risk Heatmap Buffers
                if (_showRiskOverlay)
                  CircleLayer(
                    circles: [
                      for (final z in _zones)
                        CircleMarker(
                          point: LatLng(z.lat, z.lng),
                          radius: z.radiusKm * 700,
                          useRadiusInMeter: true,
                          color: _colorForRisk(z.level).withAlpha(45),
                          borderColor: _colorForRisk(z.level).withAlpha(140),
                          borderStrokeWidth: 1.2,
                        ),
                    ],
                  ),

                // Clean Compact Markers
                if (_showVillages)
                  MarkerLayer(
                    markers: [
                      for (final z in _zones) ...[
                        Marker(
                          point: LatLng(z.lat, z.lng),
                          width: 95,
                          height: 28,
                          child: GestureDetector(
                            onTap: () {
                              final dist = _distance.as(LengthUnit.Kilometer, userLoc, LatLng(z.lat, z.lng));
                              _inspectZone(z, dist);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorForRisk(z.level),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white, width: 1.0),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 4)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_rounded, size: 10, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      '${z.name.replaceAll("Near ", "")} ${z.riskScore.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Citizen GPS Location Marker
                      Marker(
                        point: userLoc,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(color: Colors.blue.withAlpha(140), blurRadius: 8, spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // ── 2. TOP FLOATING CONTROL BAR ──────────────────────────────────
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _activeStyle == MapBaseStyle.satellite ? Icons.satellite_alt : Icons.map_outlined,
                          color: Colors.greenAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _activeStyle == MapBaseStyle.satellite ? '🛰 DIBANG VALLEY SATELLITE GIS' : '🗺 DIBANG VALLEY GIS MAP',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Quick Satellite / Map Switcher Pill
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeStyle = _activeStyle == MapBaseStyle.satellite ? MapBaseStyle.standard : MapBaseStyle.satellite;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _activeStyle == MapBaseStyle.satellite ? Icons.map : Icons.satellite_alt,
                            size: 13,
                            color: CitizenTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _activeStyle == MapBaseStyle.satellite ? 'Map Mode' : 'Satellite Mode',
                            style: const TextStyle(color: CitizenTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.isFullScreen && widget.onOpenFullScreen != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onOpenFullScreen,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CitizenTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── 3. RIGHT FLOATING ACTION BUTTONS ─────────────────────────────
            Positioned(
              right: 10,
              bottom: 34,
              child: Column(
                children: [
                  _MapControlBtn(
                    icon: Icons.add,
                    onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.remove,
                    onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.layers_outlined,
                    onTap: _showLayersDialog,
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.my_location,
                    iconColor: Colors.blue.shade600,
                    onTap: _recenterGps,
                  ),
                ],
              ),
            ),

            // ── 4. COMPACT LEGEND (Left Side Overlay) ────────────────────────
            Positioned(
              left: 10,
              bottom: 34,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    _LegendItem(color: Color(0xFF4CAF50), label: '0.00-0.25 LOW'),
                    _LegendItem(color: Color(0xFFFBC02D), label: '0.25-0.50 MODERATE'),
                    _LegendItem(color: Color(0xFFEF6C00), label: '0.50-0.75 HIGH'),
                    _LegendItem(color: Color(0xFFD32F2F), label: '0.75-1.00 VERY HIGH'),
                  ],
                ),
              ),
            ),

            // ── 5. BOTTOM GPS LOCATION BAR ───────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withAlpha(220),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'YOUR LOCATION: ${userLoc.latitude.toStringAsFixed(4)}°N, ${userLoc.longitude.toStringAsFixed(4)}°E (${AppConfig.fallbackVillageName})',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForRisk(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return const Color(0xFF4CAF50);
      case RiskLevel.moderate:
        return const Color(0xFFFBC02D);
      case RiskLevel.high:
        return const Color(0xFFEF6C00);
      case RiskLevel.critical:
        return const Color(0xFFD32F2F);
    }
  }
}

class _MapControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 4)],
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class _RiskZoneDetailsSheet extends StatelessWidget {
  final RiskZone zone;
  final double distKm;
  final double geofenceRadiusKm;

  const _RiskZoneDetailsSheet({
    required this.zone,
    required this.distKm,
    required this.geofenceRadiusKm,
  });

  Color _colorForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.moderate:
        return Colors.amber.shade700;
      case RiskLevel.high:
        return Colors.orange.shade800;
      case RiskLevel.critical:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWithinRadius = distKm <= geofenceRadiusKm;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _colorForLevel(zone.level).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: _colorForLevel(zone.level), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LANDSLIDE RISK ZONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                    Text('Zone ID: ${zone.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(zone.name, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    const SizedBox(height: 2),
                    Text(
                      '${distKm.toStringAsFixed(1)} km from you',
                      style: const TextStyle(fontSize: 12, color: CitizenTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _colorForLevel(zone.level),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Text(zone.level.label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(zone.riskScore.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isWithinRadius ? Colors.red.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isWithinRadius ? Colors.red.shade200 : Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  isWithinRadius ? Icons.error_outline : Icons.info_outline,
                  size: 16,
                  color: isWithinRadius ? Colors.red.shade700 : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  isWithinRadius ? 'Status: WITHIN YOUR MONITORING RADIUS (${geofenceRadiusKm.toStringAsFixed(0)} KM)' : 'Status: OUTSIDE YOUR MONITORING RADIUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isWithinRadius ? Colors.red.shade900 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),

          // Factors
          const Text('RISK FACTORS BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              _FactorBadge(
                label: 'Slope',
                value: _bandLabel(zone.slopeMaxDegrees, moderateAt: 20, highAt: 35),
              ),
              const SizedBox(width: 6),
              _FactorBadge(
                label: 'Rainfall',
                value: _bandLabel(zone.rainfall24hMm, moderateAt: 40, highAt: 100),
              ),
              const SizedBox(width: 6),
              _FactorBadge(
                label: 'Soil Moisture',
                value: _bandLabel(zone.soilMoisturePercent, moderateAt: 40, highAt: 70),
              ),
              const SizedBox(width: 6),
              _FactorBadge(
                label: 'History',
                value: _bandLabel(zone.historicalEventCount.toDouble(), moderateAt: 1, highAt: 3),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (zone.notes != null) ...[
            Text('Notes: ${zone.notes}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
          ],

          Text(
            'Last Updated: ${DateFormat('d MMM yyyy, HH:mm').format(zone.updatedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Row(
                      children: const [
                        Icon(Icons.shield_outlined, color: CitizenTheme.primary),
                        SizedBox(width: 8),
                        Text('Safety Instructions'),
                      ],
                    ),
                    content: Text(
                      '1. Avoid travelling near ${zone.name} during continuous heavy rainfall.\n'
                      '2. Stay away from steep slope cuts and unreinforced retaining walls.\n'
                      '3. Report any new tension cracks or soil movement immediately.\n'
                      '4. Emergency Helpline: Dial 112 (Disaster Control Room).',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.security),
              label: const Text('VIEW SAFETY INFORMATION'),
              style: FilledButton.styleFrom(
                backgroundColor: CitizenTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorBadge extends StatelessWidget {
  final String label;
  final String value;

  const _FactorBadge({required this.label, required this.value});

  Color _valColor(String v) {
    if (v == 'HIGH' || v == 'VERY HIGH') return Colors.red;
    if (v == 'MODERATE') return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _valColor(value))),
          ],
        ),
      ),
    );
  }
}

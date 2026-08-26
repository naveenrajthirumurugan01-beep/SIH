import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/risk_zone.dart';
import '../../widgets/risk_badge.dart';

class CitizenRiskMapScreen extends StatefulWidget {
  const CitizenRiskMapScreen({super.key});

  @override
  State<CitizenRiskMapScreen> createState() => _CitizenRiskMapScreenState();
}

class _CitizenRiskMapScreenState extends State<CitizenRiskMapScreen> {
  List<RiskZone> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final zones = await context.read<AppState>().riskRepository.getRiskZones();
    if (!mounted) return;
    setState(() {
      _zones = zones;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Risk Map')),
      body: Stack(
        children: [
          FlutterMap(
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
                  for (final zone in _zones)
                    Marker(
                      point: LatLng(zone.lat, zone.lng),
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: '${zone.name}\n${zone.level.label} risk',
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.colorForRisk(zone.level),
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          const Positioned(top: 12, right: 12, child: _Legend()),
        ],
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
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final level in RiskLevel.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RiskBadge(level: level),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/risk_badge.dart';
import '../../../core/services/risk_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/risk_map_provider.dart';

/// Color-coded risk map shared across all three roles. Citizens see their
/// own district highlighted with basic detail; field officials and
/// analysts see all districts with fuller detail (rainfall/slope figures).
/// TODO: once RiskService.fetchHeatmap() is implemented, wire real markers;
/// this screen currently renders the base OSM map with a legend and an
/// empty/error state.
class RiskMapScreen extends StatelessWidget {
  const RiskMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RiskMapProvider(RiskService())..load(),
      child: const _RiskMapView(),
    );
  }
}

class _RiskMapView extends StatelessWidget {
  const _RiskMapView();

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<RiskMapProvider>();
    final role = context.watch<AuthProvider>().role ?? UserRole.citizen;
    final showFullDetail = role != UserRole.citizen;

    return Scaffold(
      appBar: AppBar(title: const Text('Risk Map')),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(AppConstants.defaultMapLat, AppConstants.defaultMapLng),
              initialZoom: AppConstants.defaultMapZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ner.landslide.landslide_ews',
              ),
              MarkerLayer(
                markers: [
                  for (final district in mapState.districts)
                    Marker(
                      point: LatLng(district.lat, district.lng),
                      width: 36,
                      height: 36,
                      child: Icon(Icons.location_on, color: district.riskLevel.color, size: 36),
                    ),
                ],
              ),
            ],
          ),
          if (mapState.isLoading) const Center(child: CircularProgressIndicator()),
          if (mapState.error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    // Expected until the backend integration lands.
                    'Live risk data not yet connected: ${mapState.error}',
                  ),
                ),
              ),
            ),
          Positioned(top: 12, right: 12, child: _Legend()),
          if (showFullDetail)
            const Positioned(
              left: 12,
              bottom: 12,
              child: Chip(label: Text('Full detail view')),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
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

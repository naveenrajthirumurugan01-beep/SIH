import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/citizen_theme.dart';
import '../../core/responsive.dart';
import '../../models/alert.dart';
import '../../widgets/risk_badge.dart';

class CitizenAlertsScreen extends StatefulWidget {
  const CitizenAlertsScreen({super.key});

  @override
  State<CitizenAlertsScreen> createState() => _CitizenAlertsScreenState();
}

class _CitizenAlertsScreenState extends State<CitizenAlertsScreen> {
  late Future<List<HazardAlert>> _alertsFuture;
  static const _distance = Distance();

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  void _loadAlerts() {
    final appState = context.read<AppState>();
    appState.refreshLocation();
    _alertsFuture = appState.alertRepository.getAlerts();
  }

  Future<void> _refresh() async {
    _loadAlerts();
    setState(() {});
    await _alertsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final userLoc = appState.currentLocation;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<HazardAlert>>(
          future: _alertsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = snapshot.data!;
            if (alerts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No active hazard alerts in your region right now.'),
                ),
              );
            }

            return ListView(
              padding: context.responsiveValue(
                mobile: const EdgeInsets.all(12),
                tablet: const EdgeInsets.all(16),
                desktop: const EdgeInsets.all(16),
              ),
              children: [
                // Geolocation Info Banner
                Card(
                  color: CitizenTheme.primary.withAlpha(20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: CitizenTheme.primary.withAlpha(50)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, color: CitizenTheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Geofenced Radius Alerts',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Matching GPS location (${userLoc.latitude.toStringAsFixed(4)}°N, ${userLoc.longitude.toStringAsFixed(4)}°E) in ${AppConfig.district}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                for (final alert in alerts)
                  _AlertCard(
                    alert: alert,
                    distanceKm: _distance.as(
                      LengthUnit.Kilometer,
                      userLoc,
                      LatLng(alert.lat, alert.lng),
                    ),
                  ),
              ],
            );
          },
        ),
    );
  }
}

class _AlertCard extends StatelessWidget {

  final HazardAlert alert;
  final double distanceKm;

  const _AlertCard({required this.alert, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final isNearby = distanceKm <= alert.radiusKm || distanceKm <= 50.0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RiskBadge(level: alert.severity),
                const SizedBox(width: 8),
                if (isNearby)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'GEOFENCE WARNING',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${distanceKm.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CitizenTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(alert.message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_city, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'District: ${alert.district}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM, HH:mm').format(alert.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

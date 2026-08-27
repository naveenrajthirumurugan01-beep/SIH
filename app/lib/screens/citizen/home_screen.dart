import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../models/alert.dart';
import '../../models/risk_zone.dart';
import '../../widgets/risk_badge.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int index) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _distance = Distance();

  bool _loading = true;
  RiskZone? _nearestZone;
  HazardAlert? _nearestAlert;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    await appState.refreshLocation();
    final loc = appState.currentLocation;

    final zone = await appState.riskRepository.getNearestZone(loc.latitude, loc.longitude);
    final alerts = await appState.alertRepository.getAlerts();

    HazardAlert? nearestAlert;
    for (final alert in alerts) {
      if (nearestAlert == null ||
          _distance.as(LengthUnit.Kilometer, loc, LatLng(alert.lat, alert.lng)) <
              _distance.as(LengthUnit.Kilometer, loc, LatLng(nearestAlert.lat, nearestAlert.lng))) {
        nearestAlert = alert;
      }
    }

    if (!mounted) return;
    setState(() {
      _nearestZone = zone;
      _nearestAlert = nearestAlert;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AppState>().signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: context.responsiveValue(mobile: const EdgeInsets.all(12), tablet: const EdgeInsets.all(16), desktop: const EdgeInsets.all(16)),
                children: [
                  if (_nearestZone != null) ...[
                    RiskBadge(level: _nearestZone!.level, big: true),
                    const SizedBox(height: 8),
                    Text(
                      'Nearest monitored zone: ${_nearestZone!.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    const RiskBadge(level: RiskLevel.low, big: true),
                  const SizedBox(height: 24),
                  if (_nearestAlert != null) _NearestAlertCard(alert: _nearestAlert!),
                  const SizedBox(height: 16),
                  Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _QuickActionTile(
                    icon: Icons.map,
                    label: 'View Risk Map',
                    onTap: () => widget.onNavigate(1),
                  ),
                  _QuickActionTile(
                    icon: Icons.add_a_photo,
                    label: 'Report a Hazard',
                    onTap: () => widget.onNavigate(2),
                  ),
                  _QuickActionTile(
                    icon: Icons.list_alt,
                    label: 'My Reports',
                    onTap: () => widget.onNavigate(3),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NearestAlertCard extends StatelessWidget {
  final HazardAlert alert;

  const _NearestAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RiskBadge(level: alert.severity),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

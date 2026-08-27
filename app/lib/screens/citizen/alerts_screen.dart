import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
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

  @override
  void initState() {
    super.initState();
    _alertsFuture = context.read<AppState>().alertRepository.getAlerts();
  }

  Future<void> _refresh() async {
    final future = context.read<AppState>().alertRepository.getAlerts();
    setState(() {
      _alertsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<HazardAlert>>(
          future: _alertsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = snapshot.data!;
            if (alerts.isEmpty) {
              return const Center(child: Text('No alerts right now.'));
            }

            return ListView.builder(
              padding: context.responsiveValue(mobile: const EdgeInsets.all(12), tablet: const EdgeInsets.all(16), desktop: const EdgeInsets.all(16)),
              itemCount: alerts.length,
              itemBuilder: (context, index) => _AlertCard(alert: alerts[index]),
            );
          },
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final HazardAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RiskBadge(level: alert.severity),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    DateFormat('d MMM y, HH:mm').format(alert.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(alert.message),
            const SizedBox(height: 4),
            Text(
              alert.district,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

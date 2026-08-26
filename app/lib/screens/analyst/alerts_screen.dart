import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/alert.dart';
import '../../models/risk_zone.dart';
import '../../widgets/risk_badge.dart';

/// Alert issuance here is manual and analyst-approved — there is no
/// automatic threshold-triggered alerting in this build. That is a
/// deliberate scope decision for the prototype (keeps a human in the loop
/// before anything reaches citizens), not a missing feature.
class AnalystAlertsScreen extends StatefulWidget {
  const AnalystAlertsScreen({super.key});

  @override
  State<AnalystAlertsScreen> createState() => _AnalystAlertsScreenState();
}

class _AnalystAlertsScreenState extends State<AnalystAlertsScreen> {
  late Future<List<HazardAlert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final future = context.read<AppState>().alertRepository.getAlerts();
    setState(() => _alertsFuture = future);
    await future;
  }

  Future<void> _openNewAlertSheet() async {
    final zones = await context.read<AppState>().riskRepository.getRiskZones();
    if (!mounted) return;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NewAlertSheet(zones: zones),
    );

    if (created == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewAlertSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Alert'),
      ),
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
              return const Center(child: Text('No alerts issued yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
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
                Text(
                  DateFormat('d MMM y, HH:mm').format(alert.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(alert.message),
            const SizedBox(height: 4),
            Text(
              '${alert.district} · ${alert.radiusKm.toStringAsFixed(1)} km radius',
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

class _NewAlertSheet extends StatefulWidget {
  final List<RiskZone> zones;

  const _NewAlertSheet({required this.zones});

  @override
  State<_NewAlertSheet> createState() => _NewAlertSheetState();
}

class _NewAlertSheetState extends State<_NewAlertSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '3.0');
  RiskLevel _severity = RiskLevel.moderate;
  RiskZone? _selectedZone;
  bool _isSubmitting = false;

  void _applyZone(RiskZone? zone) {
    setState(() {
      _selectedZone = zone;
      if (zone != null) {
        _latController.text = zone.lat.toString();
        _lngController.text = zone.lng.toString();
        _severity = zone.level;
      }
    });
  }

  Future<void> _submit() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    final radius = double.tryParse(_radiusController.text);
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty ||
        lat == null ||
        lng == null ||
        radius == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.alertRepository.createAlert(
        HazardAlert(
          id: '',
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          severity: _severity,
          lat: lat,
          lng: lng,
          radiusKm: radius,
          district: _selectedZone?.district ?? '',
          createdAt: DateTime.now(),
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Alert', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 12),
            Text('Severity', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final level in RiskLevel.values)
                  ChoiceChip(
                    label: Text(level.label),
                    selected: _severity == level,
                    onSelected: (_) => setState(() => _severity = level),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RiskZone>(
              initialValue: _selectedZone,
              decoration: const InputDecoration(
                labelText: 'Pick a risk zone to auto-fill location (optional)',
              ),
              items: [
                for (final zone in widget.zones)
                  DropdownMenuItem(value: zone, child: Text(zone.name)),
              ],
              onChanged: _applyZone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Lat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Lng'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Radius (km)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Issue Alert'),
            ),
          ],
        ),
      ),
    );
  }
}

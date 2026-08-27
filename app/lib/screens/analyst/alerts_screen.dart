import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/date_range_filter.dart';
import '../../core/responsive.dart';
import '../../models/alert.dart';
import '../../models/risk_zone.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/risk_badge.dart';
import 'assign_officer_dialog.dart';

/// Alert issuance itself is still manual and analyst-approved — there is no
/// automatic threshold-triggered alerting in this build. That is a
/// deliberate scope decision for the prototype (keeps a human in the loop
/// before anything reaches citizens), not a missing feature. What IS wired
/// up here is the response workflow once an alert exists: Review →
/// Acknowledge → Assign → Escalate → Resolve, each a real Firestore write
/// via AlertRepository.updateAlertStatus.
class AnalystAlertsScreen extends StatefulWidget {
  const AnalystAlertsScreen({super.key});

  @override
  State<AnalystAlertsScreen> createState() => _AnalystAlertsScreenState();
}

class _AnalystAlertsScreenState extends State<AnalystAlertsScreen> {
  late Future<List<HazardAlert>> _alertsFuture;
  DateRangePreset _dateFilter = DateRangePreset.allTime;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final future = context.read<AppState>().alertRepository.getAlerts();
    // A block body, not `() => _alertsFuture = future`: an assignment
    // expression evaluates to its right-hand side, so an arrow-bodied
    // closure here would hand setState back the Future itself — and
    // setState asserts its callback returns void, throwing "setState()
    // callback argument returned a Future" the moment this ran.
    setState(() {
      _alertsFuture = future;
    });
    // Swallow here — the FutureBuilder below reads _alertsFuture directly
    // and renders ErrorStateView off its own hasError check; without this
    // try/catch, a rejected `future` would also surface as a second,
    // redundant unhandled-exception report from this awaited copy.
    try {
      await future;
    } catch (_) {
      // Handled by the FutureBuilder.
    }
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
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.isMobile ? 12 : 16, 12, context.isMobile ? 12 : 16, 4),
            child: Row(
              children: [
                Text('Issued:', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in DateRangePreset.values)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: _dateFilter == preset,
                        onSelected: (_) => setState(() => _dateFilter = preset),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<HazardAlert>>(
                future: _alertsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorStateView(
                      message: 'Could not load alerts: ${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LoadingView();
                  }

                  final alerts = snapshot.data!
                      .where((a) => _dateFilter.includes(a.createdAt))
                      .toList();
                  if (alerts.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.campaign_outlined,
                      message: _dateFilter == DateRangePreset.allTime
                          ? 'No active alerts right now.'
                          : 'No alerts issued in the ${_dateFilter.label.toLowerCase()}.',
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(context.isMobile ? 12 : 16),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) =>
                        _AlertCard(alert: alerts[index], onChanged: _refresh),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, AlertStatus status) => switch (status) {
      AlertStatus.open => Theme.of(context).colorScheme.error,
      AlertStatus.acknowledged => const Color(0xFFF9A825),
      AlertStatus.assigned => const Color(0xFF1565C0),
      AlertStatus.escalated => const Color(0xFFC62828),
      AlertStatus.resolved => const Color(0xFF2E7D32),
    };

class _AlertCard extends StatelessWidget {
  final HazardAlert alert;
  final Future<void> Function() onChanged;

  const _AlertCard({required this.alert, required this.onChanged});

  Future<void> _setStatus(BuildContext context, AlertStatus status) async {
    final appState = context.read<AppState>();
    await appState.alertRepository.updateAlertStatus(alert.id, status);
    appState.recordActivity('${status.label} alert "${alert.title}"');
    await onChanged();
  }

  Future<void> _review(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ALERT ID: ${alert.id}', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(alert.message),
              const SizedBox(height: 12),
              Text('Source: ${alert.source.label}'),
              Text('Location: ${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)}'),
              Text('${alert.district} · ${alert.radiusKm.toStringAsFixed(1)} km radius'),
              Text('Time: ${DateFormat('d MMM y, HH:mm').format(alert.createdAt)}'),
              if (alert.recommendedAction.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Recommended action', style: Theme.of(context).textTheme.titleSmall),
                Text(alert.recommendedAction),
              ],
            ],
          ),
        ),
        actions: [
          if (alert.status == AlertStatus.open)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _setStatus(context, AlertStatus.acknowledged);
              },
              child: const Text('Acknowledge'),
            ),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _notifyOfficer(BuildContext context) async {
    final appState = context.read<AppState>();
    final officers = await appState.authRepository.watchEnabledFieldOfficers().first;
    if (!context.mounted) return;

    if (officers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No approved Field Officer accounts yet.')),
      );
      return;
    }

    final officer = await pickFieldOfficer(context, officers);
    if (officer == null || !context.mounted) return;

    await notifyFieldOfficerAt(
      appState,
      officer: officer,
      lat: alert.lat,
      lng: alert.lng,
      riskLevel: alert.severity,
      reason: 'Alert response: ${alert.title}',
      instructions: 'Investigate the alert "${alert.title}" at this location. ${alert.message}',
    );
    await appState.alertRepository.updateAlertStatus(alert.id, AlertStatus.assigned);
    appState.recordActivity(
      'Notified ${officer.displayName ?? officer.email} to respond to alert "${alert.title}"',
    );
    await onChanged();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notified ${officer.displayName ?? officer.email} — awaiting their response.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, alert.status);

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert.status.label,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM y, HH:mm').format(alert.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              'Source: ${alert.source.label} · ID ${alert.id}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 6),
            Text(alert.message),
            const SizedBox(height: 4),
            Text(
              '${alert.district} · ${alert.radiusKm.toStringAsFixed(1)} km radius',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            if (alert.recommendedAction.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Recommended: ${alert.recommendedAction}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(onPressed: () => _review(context), child: const Text('Review')),
                if (alert.status == AlertStatus.open)
                  OutlinedButton(
                    onPressed: () => _setStatus(context, AlertStatus.acknowledged),
                    child: const Text('Acknowledge'),
                  ),
                if (alert.status != AlertStatus.resolved)
                  OutlinedButton(
                    onPressed: () => _notifyOfficer(context),
                    child: const Text('Notify Officer'),
                  ),
                if (alert.status != AlertStatus.escalated && alert.status != AlertStatus.resolved)
                  OutlinedButton(
                    onPressed: () => _setStatus(context, AlertStatus.escalated),
                    child: const Text('Escalate'),
                  ),
                if (alert.status != AlertStatus.resolved)
                  FilledButton(
                    onPressed: () => _setStatus(context, AlertStatus.resolved),
                    child: const Text('Resolve'),
                  ),
              ],
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
  final _recommendedActionController = TextEditingController();
  RiskLevel _severity = RiskLevel.moderate;
  AlertSource _source = AlertSource.analystDecision;
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
          source: _source,
          recommendedAction: _recommendedActionController.text.trim(),
        ),
      );
      appState.recordActivity('Issued alert "${_titleController.text.trim()}"');

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
            Text('Source', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<AlertSource>(
              initialValue: _source,
              items: [
                for (final source in AlertSource.values)
                  DropdownMenuItem(value: source, child: Text(source.label)),
              ],
              onChanged: (source) => setState(() => _source = source ?? _source),
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
            const SizedBox(height: 12),
            TextField(
              controller: _recommendedActionController,
              decoration: const InputDecoration(labelText: 'Recommended action (optional)'),
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

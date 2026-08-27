import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/location_service.dart';

/// Live GPS Status & Location Handling Widget for Field Officer Inspection.
/// Displays: Latitude, Longitude, Accuracy (meters), Timestamp, Accuracy Quality,
/// and Recovery Action Buttons for every permission/hardware failure state.
class FieldGpsStatusCard extends StatefulWidget {
  const FieldGpsStatusCard({super.key});

  @override
  State<FieldGpsStatusCard> createState() => _FieldGpsStatusCardState();
}

class _FieldGpsStatusCardState extends State<FieldGpsStatusCard> {
  final LocationService _locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FieldGpsFix>(
      stream: _locationService.watchFieldGpsFix(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Acquiring GPS Satellite Signal...'),
                ],
              ),
            ),
          );
        }

        final fix = snapshot.data ??
            FieldGpsFix(
              latitude: LocationService.studyAreaCenter.latitude,
              longitude: LocationService.studyAreaCenter.longitude,
              accuracyMeters: 0,
              timestamp: DateTime.now(),
              status: FieldGpsStatus.disabled,
              errorMessage: 'Awaiting location signal...',
            );

        return _buildGpsCardContent(context, fix);
      },
    );
  }

  Widget _buildGpsCardContent(BuildContext context, FieldGpsFix fix) {
    final formattedTime = DateFormat('HH:mm:ss').format(fix.timestamp);

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    switch (fix.status) {
      case FieldGpsStatus.activeHighAccuracy:
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.gps_fixed;
        statusTitle = 'GPS Active (High Accuracy)';
        break;
      case FieldGpsStatus.activeLowAccuracy:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.gps_not_fixed;
        statusTitle = 'Weak GPS Signal (${fix.accuracyLabel})';
        break;
      case FieldGpsStatus.disabled:
        statusColor = Colors.red.shade700;
        statusIcon = Icons.location_off;
        statusTitle = 'Location Services Disabled';
        break;
      case FieldGpsStatus.permissionDenied:
        statusColor = Colors.red.shade700;
        statusIcon = Icons.gavel;
        statusTitle = 'Location Permission Denied';
        break;
      case FieldGpsStatus.permissionDeniedForever:
        statusColor = Colors.red.shade900;
        statusIcon = Icons.block;
        statusTitle = 'Permission Permanently Denied';
        break;
      case FieldGpsStatus.acquiring:
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.sync;
        statusTitle = 'Searching Satellites...';
        break;
      case FieldGpsStatus.error:
        statusColor = Colors.red.shade800;
        statusIcon = Icons.error_outline;
        statusTitle = 'GPS System Error';
        break;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Row
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    fix.isReliable ? 'RELIABLE' : 'UNRELIABLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Live Telemetry Grid
            Row(
              children: [
                Expanded(
                  child: _TelemetryTile(
                    label: 'Latitude',
                    value: fix.latitude.toStringAsFixed(6),
                  ),
                ),
                Expanded(
                  child: _TelemetryTile(
                    label: 'Longitude',
                    value: fix.longitude.toStringAsFixed(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TelemetryTile(
                    label: 'Accuracy',
                    value: fix.accuracyLabel,
                    highlight: fix.isReliable ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                Expanded(
                  child: _TelemetryTile(
                    label: 'Timestamp',
                    value: formattedTime,
                  ),
                ),
              ],
            ),

            // Error & Recovery Action Section
            if (fix.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fix.errorMessage!,
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ),
            ],

            // Recovery Action Buttons based on failure mode
            if (fix.status != FieldGpsStatus.activeHighAccuracy) ...[
              const SizedBox(height: 14),
              _buildRecoveryButton(context, fix.status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryButton(BuildContext context, FieldGpsStatus status) {
    switch (status) {
      case FieldGpsStatus.disabled:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await _locationService.openLocationSettings();
              setState(() {});
            },
            icon: const Icon(Icons.settings),
            label: const Text('Enable Device GPS Settings'),
          ),
        );
      case FieldGpsStatus.permissionDenied:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              await _locationService.requestPermission();
              setState(() {});
            },
            icon: const Icon(Icons.security),
            label: const Text('Grant Location Permission'),
          ),
        );
      case FieldGpsStatus.permissionDeniedForever:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await _locationService.openAppSettings();
              setState(() {});
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open App Settings to Grant Permission'),
          ),
        );
      case FieldGpsStatus.activeLowAccuracy:
      case FieldGpsStatus.acquiring:
      case FieldGpsStatus.error:
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Re-acquire GPS Satellite Fix'),
          ),
        );
    }
  }
}

class _TelemetryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;

  const _TelemetryTile({
    required this.label,
    required this.value,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

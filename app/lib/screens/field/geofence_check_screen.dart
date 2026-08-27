import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../models/location_verification.dart';
import '../../models/task.dart';
import '../../services/location_service.dart';
import '../../services/location_verifier.dart';
import '../../services/task_repository.dart';
import 'inspection_form_screen.dart';

/// Location Verification Screen for Field Officer Inspection (Phase 7).
/// Evaluates and displays the 5 formal location verification states:
/// 1. GPS Unavailable
/// 2. GPS Accuracy Too Poor
/// 3. Outside Inspection Zone
/// 4. Inside Inspection Zone
/// 5. LOCATION VERIFIED
class GeofenceCheckScreen extends StatefulWidget {
  final InspectionTask task;

  const GeofenceCheckScreen({super.key, required this.task});

  @override
  State<GeofenceCheckScreen> createState() => _GeofenceCheckScreenState();
}

class _GeofenceCheckScreenState extends State<GeofenceCheckScreen> {
  final _locationService = LocationService();
  StreamSubscription<FieldGpsFix>? _subscription;

  FieldGpsFix? _currentFix;
  LocationVerificationRecord? _verificationRecord;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final initial = await _locationService.getFieldGpsFix();
    _processFix(initial);
    _subscription = _locationService.watchFieldGpsFix().listen(_processFix);
  }

  void _processFix(FieldGpsFix fix) {
    if (!mounted) return;

    final appState = context.read<AppState>();
    final authProvider = context.read<AuthProvider>();
    final officerUid = authProvider.profile?.uid ?? appState.officerId ?? demoOfficerUid;

    final record = LocationVerifier.evaluate(
      fix: fix,
      task: widget.task,
      officerUid: officerUid,
    );

    setState(() {
      _currentFix = fix;
      _verificationRecord = record;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final record = _verificationRecord;

    return Scaffold(
      appBar: AppBar(
        title: Text('Location Verification — ${task.id}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Verification State Banner Card
            _buildStateBannerCard(context, record),
            const SizedBox(height: 16),

            // 2. Recorded Verification Proof Card (when Location Verified)
            if (record != null && record.isVerified) ...[
              _buildVerifiedProofCard(context, record),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InspectionFormScreen(
                          task: widget.task,
                          verificationRecord: record,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_turned_in, size: 24),
                  label: const Text(
                    'PROCEED TO FIELD OBSERVATION FORM',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Inspection & Geofence Boundary Target Summary Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSPECTION GEOFENCE TARGET',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Divider(height: 20),
                    _RowItem(label: 'Inspection ID', value: task.id),
                    _RowItem(label: 'Risk Zone ID', value: task.riskZoneId),
                    _RowItem(label: 'Boundary Specification', value: task.boundary.boundaryDescription),
                    _RowItem(
                      label: 'Target Coordinates',
                      value: '${task.lat.toStringAsFixed(5)}, ${task.lng.toStringAsFixed(5)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Clear Recovery Actions based on failure state
            if (record != null && !record.isVerified) ...[
              _buildRecoveryActionSection(context, record.state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStateBannerCard(BuildContext context, LocationVerificationRecord? record) {
    if (record == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Evaluating GPS & Dynamic Geofence Criteria...'),
            ],
          ),
        ),
      );
    }

    Color stateColor;
    IconData stateIcon;
    String stateTitle;

    switch (record.state) {
      case LocationVerificationState.locationVerified:
        stateColor = const Color(0xFF2E7D32);
        stateIcon = Icons.verified_user_rounded;
        stateTitle = 'STATE 5: LOCATION VERIFIED';
        break;
      case LocationVerificationState.insideInspectionZone:
        stateColor = Colors.green.shade800;
        stateIcon = Icons.location_on;
        stateTitle = 'STATE 4: INSIDE INSPECTION ZONE';
        break;
      case LocationVerificationState.outsideInspectionZone:
        stateColor = Colors.orange.shade800;
        stateIcon = Icons.person_pin_circle_outlined;
        stateTitle = 'STATE 3: OUTSIDE INSPECTION ZONE';
        break;
      case LocationVerificationState.accuracyTooPoor:
        stateColor = Colors.deepOrange.shade800;
        stateIcon = Icons.gps_off_rounded;
        stateTitle = 'STATE 2: GPS ACCURACY TOO POOR';
        break;
      case LocationVerificationState.gpsUnavailable:
      default:
        stateColor = Colors.red.shade700;
        stateIcon = Icons.portable_wifi_off;
        stateTitle = 'STATE 1: GPS UNAVAILABLE';
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: stateColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(stateIcon, size: 52, color: stateColor),
            const SizedBox(height: 12),
            Text(
              stateTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: stateColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              record.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedProofCard(BuildContext context, LocationVerificationRecord record) {
    final formattedTime = DateFormat('MMMM d, y • HH:mm:ss').format(record.timestamp);

    return Card(
      elevation: 3,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'RECORDED VERIFICATION PROOF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFF2E7D32)),
            _ProofRow(label: 'Inspection ID', value: record.inspectionId),
            _ProofRow(label: 'Field Officer ID', value: record.officerUid),
            _ProofRow(
              label: 'Verified Latitude',
              value: record.latitude.toStringAsFixed(6),
            ),
            _ProofRow(
              label: 'Verified Longitude',
              value: record.longitude.toStringAsFixed(6),
            ),
            _ProofRow(
              label: 'GPS Accuracy',
              value: '±${record.gpsAccuracyMeters.toStringAsFixed(1)} m',
            ),
            _ProofRow(label: 'Verified Timestamp', value: formattedTime),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryActionSection(BuildContext context, LocationVerificationState state) {
    switch (state) {
      case LocationVerificationState.gpsUnavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RECOVERY ACTION:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                await _locationService.openLocationSettings();
                setState(() {});
              },
              icon: const Icon(Icons.settings),
              label: const Text('Turn On Location Services'),
            ),
          ],
        );
      case LocationVerificationState.accuracyTooPoor:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RECOVERY ACTION:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Move to Open Sky & Refresh Satellite Fix'),
            ),
          ],
        );
      case LocationVerificationState.outsideInspectionZone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RECOVERY ACTION:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.directions_walk),
              label: const Text('Move Physical Position Closer to Zone Boundary'),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;

  const _RowItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ProofRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProofRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
          ),
        ],
      ),
    );
  }
}

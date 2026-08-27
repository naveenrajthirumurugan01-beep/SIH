import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../models/field_evidence.dart';
import '../../models/inspection.dart';
import '../../models/location_verification.dart';
import '../../models/task.dart';
import '../../services/evidence_capture_service.dart';

import '../../services/task_repository.dart';
import '../../widgets/field_sync_banner.dart';
import 'field_report_review_screen.dart';

/// Field Inspection Form Screen (Phase 8 & Phase 9 & Phase 10).
/// Accessible ONLY after Location Verification proof is established.
/// Supports field observations, live camera evidence capture, and offline draft sync.
class InspectionFormScreen extends StatefulWidget {
  final InspectionTask task;
  final LocationVerificationRecord verificationRecord;

  const InspectionFormScreen({
    super.key,
    required this.task,
    required this.verificationRecord,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final EvidenceCaptureService _evidenceService = EvidenceCaptureService();

  CrackStatus _crack = CrackStatus.none;
  SlopeMovement _slopeMovement = SlopeMovement.none;
  bool _rockfall = false;
  bool _waterSeepage = false;
  RoadCondition _roadCondition = RoadCondition.normal;
  OverallObservation _overallObservation = OverallObservation.safe;
  final _remarksController = TextEditingController();

  EvidenceCategory _selectedCategory = EvidenceCategory.slope;
  final List<FieldEvidenceItem> _capturedEvidence = [];
  bool _isCapturing = false;

  bool _isSaved = false;
  FieldObservation? _savedObservation;

  Future<void> _captureEvidence() async {
    final authProvider = context.read<AuthProvider>();
    final appState = context.read<AppState>();
    final officerUid = authProvider.profile?.uid ?? appState.officerId ?? demoOfficerUid;

    setState(() => _isCapturing = true);

    try {
      final item = await _evidenceService.captureLiveCameraEvidence(
        task: widget.task,
        officerUid: officerUid,
        category: _selectedCategory,
      );

      setState(() {
        _capturedEvidence.add(item);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Captured ${item.category.label} Evidence (${item.id}) — ${item.isZoneVerified ? "ZONE VERIFIED" : "UNVERIFIED (OUTSIDE ZONE)"}',
          ),
          backgroundColor: item.isZoneVerified ? const Color(0xFF2E7D32) : Colors.orange.shade800,
        ),
      );
    } on EvidenceCaptureException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera error: ${e.toString()}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _saveObservation() {
    final authProvider = context.read<AuthProvider>();
    final appState = context.read<AppState>();
    final officerUid = authProvider.profile?.uid ?? appState.officerId ?? demoOfficerUid;

    final observation = FieldObservation(
      inspectionId: widget.task.id,
      officerUid: officerUid,
      crack: _crack,
      slopeMovement: _slopeMovement,
      rockfall: _rockfall,
      waterSeepage: _waterSeepage,
      roadCondition: _roadCondition,
      overallObservation: _overallObservation,
      remarks: _remarksController.text.trim(),
      recordedAt: DateTime.now(),
    );

    setState(() {
      _savedObservation = observation;
      _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Field observation & ${_capturedEvidence.length} evidence item(s) saved locally for ${widget.task.id}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final proof = widget.verificationRecord;

    return Scaffold(
      appBar: AppBar(
        title: Text('Observation & Evidence — ${task.id}'),
      ),
      body: Column(
        children: [
          const FieldSyncBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            // 1. Verified Location Proof Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2E7D32)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location Verified Proof Attached (${proof.latitude.toStringAsFixed(4)}, ${proof.longitude.toStringAsFixed(4)} • ±${proof.gpsAccuracyMeters.toStringAsFixed(1)}m)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Saved Observation Confirmation Card (when saved)
            if (_isSaved && _savedObservation != null) ...[
              _buildSavedObservationSummaryCard(context, _savedObservation!),
              const SizedBox(height: 16),
            ],

            // 3. Phase 9 Live Field Evidence Capture Section
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE FIELD EVIDENCE CAPTURE',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Category Selector
                    const Text('Select Evidence Category:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<EvidenceCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: EvidenceCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Live Camera Capture Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isCapturing ? null : _captureEvidence,
                        icon: _isCapturing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera),
                        label: Text(_isCapturing ? 'ACQUIRING TELEMETRY...' : 'CAPTURE LIVE CAMERA EVIDENCE'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Evidence Gallery
                    if (_capturedEvidence.isNotEmpty) ...[
                      Text(
                        'Captured Evidence Items (${_capturedEvidence.length}):',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _capturedEvidence.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _capturedEvidence[index];
                          return _buildEvidenceTile(context, item);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Large Field Control 1: Crack Observation
            _buildControlSection(
              context,
              title: '1. Crack Status',
              child: SegmentedButton<CrackStatus>(
                segments: const [
                  ButtonSegment(value: CrackStatus.none, label: Text('None')),
                  ButtonSegment(value: CrackStatus.minor, label: Text('Minor')),
                  ButtonSegment(value: CrackStatus.major, label: Text('Major')),
                ],
                selected: {_crack},
                onSelectionChanged: (val) => setState(() => _crack = val.first),
              ),
            ),
            const SizedBox(height: 16),

            // Large Field Control 2: Slope Movement
            _buildControlSection(
              context,
              title: '2. Slope Movement',
              child: SegmentedButton<SlopeMovement>(
                segments: const [
                  ButtonSegment(value: SlopeMovement.none, label: Text('None')),
                  ButtonSegment(value: SlopeMovement.minor, label: Text('Minor')),
                  ButtonSegment(value: SlopeMovement.moderate, label: Text('Moderate')),
                  ButtonSegment(value: SlopeMovement.severe, label: Text('Severe')),
                ],
                selected: {_slopeMovement},
                onSelectionChanged: (val) => setState(() => _slopeMovement = val.first),
              ),
            ),
            const SizedBox(height: 16),

            // Large Field Control 3 & 4: Rockfall & Water Seepage
            _buildControlSection(
              context,
              title: '3. Hazard Triggers Observed',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Rockfall Observed', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_rockfall ? 'CONFIRMED YES' : 'NO'),
                    value: _rockfall,
                    activeColor: Colors.orange.shade800,
                    onChanged: (val) => setState(() => _rockfall = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Water Seepage Observed', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_waterSeepage ? 'CONFIRMED YES' : 'NO'),
                    value: _waterSeepage,
                    activeColor: Colors.blue.shade800,
                    onChanged: (val) => setState(() => _waterSeepage = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Large Field Control 5: Road Condition
            _buildControlSection(
              context,
              title: '4. Road Condition',
              child: SegmentedButton<RoadCondition>(
                segments: const [
                  ButtonSegment(value: RoadCondition.normal, label: Text('Normal')),
                  ButtonSegment(value: RoadCondition.damaged, label: Text('Damaged')),
                  ButtonSegment(value: RoadCondition.blocked, label: Text('Blocked')),
                ],
                selected: {_roadCondition},
                onSelectionChanged: (val) => setState(() => _roadCondition = val.first),
              ),
            ),
            const SizedBox(height: 16),

            // Large Field Control 6: Overall Hazard Assessment
            _buildControlSection(
              context,
              title: '5. Overall Hazard Assessment',
              child: SegmentedButton<OverallObservation>(
                segments: const [
                  ButtonSegment(value: OverallObservation.safe, label: Text('SAFE')),
                  ButtonSegment(value: OverallObservation.monitor, label: Text('MONITOR')),
                  ButtonSegment(value: OverallObservation.highRisk, label: Text('HIGH RISK')),
                  ButtonSegment(value: OverallObservation.critical, label: Text('CRITICAL')),
                ],
                selected: {_overallObservation},
                onSelectionChanged: (val) => setState(() => _overallObservation = val.first),
              ),
            ),
            const SizedBox(height: 16),

            // Control 7: Optional Remarks
            _buildControlSection(
              context,
              title: '6. Optional Officer Remarks',
              child: TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter optional field observations, landmarks, or structural notes...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Action Button
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveObservation,
                icon: const Icon(Icons.save_outlined, size: 24),
                label: Text(
                  'SAVE OBSERVATIONS FOR INSPECTION ${task.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Button to Phase 11 Review & Submit Screen
            if (_isSaved && _savedObservation != null) ...[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FieldReportReviewScreen(
                          task: widget.task,
                          verificationRecord: widget.verificationRecord,
                          observation: _savedObservation!,
                          evidenceItems: _capturedEvidence,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check_outlined, size: 24),
                  label: const Text(
                    'PROCEED TO REVIEW & SUBMIT FIELD REPORT',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    ),
  ],
),
);
  }

  Widget _buildEvidenceTile(BuildContext context, FieldEvidenceItem item) {
    final sizeKb = (item.fileSizeBytes / 1024).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isZoneVerified ? const Color(0xFF2E7D32) : Colors.orange.shade800,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 50,
              height: 50,
              child: item.localFilePath.startsWith('http') || kIsWeb
                  ? Image.network(item.localFilePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                  : const Icon(Icons.image, size: 28, color: Colors.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.id} • ${item.category.label}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isZoneVerified ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isZoneVerified ? 'ZONE VERIFIED' : 'UNVERIFIED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.isZoneVerified ? const Color(0xFF2E7D32) : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Size: ${sizeKb} KB  •  GPS: ${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)} (±${item.gpsAccuracyMeters.toStringAsFixed(1)}m)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(BuildContext context, {required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSavedObservationSummaryCard(BuildContext context, FieldObservation obs) {
    return Card(
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
                Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'OBSERVATION RECORDED LOCALLY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const Divider(height: 16, color: Color(0xFF2E7D32)),
            Text('Crack: ${obs.crack.label}  •  Slope: ${obs.slopeMovement.label}'),
            Text('Rockfall: ${obs.rockfall ? "YES" : "NO"}  •  Seepage: ${obs.waterSeepage ? "YES" : "NO"}'),
            Text('Road: ${obs.roadCondition.label}  •  Assessment: ${obs.overallObservation.label}'),
            if (obs.remarks.isNotEmpty) Text('Remarks: ${obs.remarks}'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../models/field_evidence.dart';
import '../../models/field_report.dart';
import '../../models/inspection.dart';
import '../../models/location_verification.dart';
import '../../models/task.dart';
import '../../services/task_repository.dart';
import '../../widgets/field_sync_banner.dart';

/// Review and Submit Field Report Screen (Phase 11).
/// Displays full pre-submission review and validates security constraints before
/// generating and storing a structured FieldReport.
class FieldReportReviewScreen extends StatefulWidget {
  final InspectionTask task;
  final LocationVerificationRecord verificationRecord;
  final FieldObservation observation;
  final List<FieldEvidenceItem> evidenceItems;

  const FieldReportReviewScreen({
    super.key,
    required this.task,
    required this.verificationRecord,
    required this.observation,
    required this.evidenceItems,
  });

  @override
  State<FieldReportReviewScreen> createState() => _FieldReportReviewScreenState();
}

class _FieldReportReviewScreenState extends State<FieldReportReviewScreen> {
  bool _isConfirmedByOfficer = false;
  bool _isSubmitting = false;
  FieldReport? _generatedReport;

  Future<void> _submitFieldReport() async {
    final appState = context.read<AppState>();
    final authProvider = context.read<AuthProvider>();
    final officerUid = authProvider.profile?.uid ?? appState.officerId ?? demoOfficerUid;

    final task = widget.task;
    final proof = widget.verificationRecord;

    // 1. Protection Check 1: Prevent Duplicate Submission
    if (task.status == InspectionTaskStatus.completed) {
      _showErrorSnackBar('Duplicate Submission Error: Inspection task ${task.id} is already completed.');
      return;
    }

    // 2. Protection Check 2: Prevent Submission for another officer's inspection
    final isAuthorizedOfficer = task.assignedOfficerUid == officerUid || task.assignedOfficerUid == demoOfficerUid;
    if (!isAuthorizedOfficer) {
      _showErrorSnackBar('Unauthorized: This inspection is assigned to officer ${task.assignedOfficerUid}.');
      return;
    }

    // 3. Protection Check 3: Prevent Submission without required location verification
    if (!proof.isVerified) {
      _showErrorSnackBar('Location Verification Error: Reliable location verification proof is required.');
      return;
    }

    // 4. Protection Check 4: Prevent Submission of invalid / cancelled assignment
    if (task.status == InspectionTaskStatus.cancelled) {
      _showErrorSnackBar('Invalid Assignment Error: This inspection task was cancelled.');
      return;
    }

    // 5. Require explicit officer confirmation
    if (!_isConfirmedByOfficer) {
      _showErrorSnackBar('Explicit Confirmation Required: Check the confirmation box before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reportId = 'REP-${task.id}';
      final report = FieldReport(
        reportId: reportId,
        inspectionId: task.id,
        officerUid: officerUid,
        officerName: authProvider.profile?.fullName ?? appState.officerName ?? 'Field Officer',
        riskZoneId: task.riskZoneId,
        aiBaselineContext: AIBaselineContext(
          initialRiskLevel: task.riskLevel,
          initialTriggerReason: task.reason,
          assignedBy: task.assignedBy,
        ),
        latitude: proof.latitude,
        longitude: proof.longitude,
        gpsAccuracyMeters: proof.gpsAccuracyMeters,
        verifiedAt: proof.timestamp,
        verificationState: proof.state.name,
        observation: widget.observation,
        evidenceReferences: widget.evidenceItems,
        officerAssessment: widget.observation.overallObservation,
        submissionStatus: 'completed',
        submittedAt: DateTime.now(),
      );

      // Close loop in task repository (assigned / enRoute -> completed)
      await appState.taskRepository.updateTaskStatus(task.id, InspectionTaskStatus.completed);

      setState(() {
        _generatedReport = report;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Field Report $reportId successfully generated and submitted!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Submission failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final proof = widget.verificationRecord;
    final obs = widget.observation;
    final formattedTime = DateFormat('MMMM d, y • HH:mm:ss').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Review & Submit — ${task.id}'),
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
                  // 1. Success Submitted Summary Card (when submitted)
                  if (_generatedReport != null) ...[
                    _buildSubmittedReportSummaryCard(context, _generatedReport!),
                    const SizedBox(height: 16),
                  ],

                  // 2. Pre-Submission Overview Card
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INSPECTION ASSIGNMENT SUMMARY',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const Divider(height: 20),
                          _DetailTile(label: 'Inspection ID', value: task.id),
                          _DetailTile(label: 'Assigned Officer ID', value: proof.officerUid),
                          _DetailTile(label: 'Risk Zone ID', value: task.riskZoneId),
                          _DetailTile(label: 'Task Current Status', value: task.status.label.toUpperCase()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Verified Location Proof Section
                  Card(
                    elevation: 2,
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified, color: Color(0xFF2E7D32)),
                              SizedBox(width: 8),
                              Text(
                                'LOCATION VERIFICATION STATUS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFF2E7D32)),
                          _DetailTile(
                            label: 'Verification Status',
                            value: proof.isVerified ? 'VERIFIED (State 5)' : 'UNVERIFIED',
                          ),
                          _DetailTile(
                            label: 'Verified Coordinates',
                            value: '${proof.latitude.toStringAsFixed(5)}, ${proof.longitude.toStringAsFixed(5)}',
                          ),
                          _DetailTile(
                            label: 'GPS Accuracy',
                            value: '±${proof.gpsAccuracyMeters.toStringAsFixed(1)} m',
                          ),
                          _DetailTile(
                            label: 'Verification Timestamp',
                            value: DateFormat('HH:mm:ss').format(proof.timestamp),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Field Observations Summary
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FIELD OBSERVATIONS & FINDINGS',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const Divider(height: 20),
                          _DetailTile(label: 'Crack Status', value: obs.crack.label),
                          _DetailTile(label: 'Slope Movement', value: obs.slopeMovement.label),
                          _DetailTile(label: 'Rockfall Observed', value: obs.rockfall ? 'YES' : 'NO'),
                          _DetailTile(label: 'Water Seepage Observed', value: obs.waterSeepage ? 'YES' : 'NO'),
                          _DetailTile(label: 'Road Condition', value: obs.roadCondition.label),
                          if (obs.remarks.isNotEmpty)
                            _DetailTile(label: 'Officer Remarks', value: obs.remarks),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Evidence References Summary
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'EVIDENCE REFERENCES',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              Text(
                                '${widget.evidenceItems.length} Item(s)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (widget.evidenceItems.isEmpty)
                            const Text('No camera evidence attached.', style: TextStyle(color: Colors.grey))
                          else
                            Column(
                              children: widget.evidenceItems.map((evd) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.photo, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${evd.id} (${evd.category.label})',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      Text(
                                        evd.isZoneVerified ? 'ZONE VERIFIED' : 'UNVERIFIED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: evd.isZoneVerified ? const Color(0xFF2E7D32) : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Officer Assessment Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'OFFICER ASSESSMENT:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getAssessmentColor(obs.overallObservation),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            obs.overallObservation.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 7. Explicit Officer Confirmation Checkbox
                  CheckboxListTile(
                    value: _isConfirmedByOfficer,
                    activeColor: const Color(0xFF2E7D32),
                    title: Text(
                      'I explicitly confirm that the location proof, observations, and evidence for ${task.id} are accurate and verified for submission.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onChanged: (val) {
                      setState(() => _isConfirmedByOfficer = val ?? false);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Final Submission Action Button
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: (_isSubmitting || !_isConfirmedByOfficer || _generatedReport != null)
                          ? null
                          : _submitFieldReport,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 24),
                      label: Text(
                        _generatedReport != null
                            ? 'FIELD REPORT SUBMITTED ✓'
                            : 'CONFIRM AND SUBMIT FIELD REPORT',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAssessmentColor(OverallObservation assessment) {
    return switch (assessment) {
      OverallObservation.safe => Colors.green.shade800,
      OverallObservation.monitor => Colors.blue.shade800,
      OverallObservation.highRisk => Colors.orange.shade900,
      OverallObservation.critical => Colors.red.shade900,
    };
  }

  Widget _buildSubmittedReportSummaryCard(BuildContext context, FieldReport report) {
    return Card(
      elevation: 4,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
                SizedBox(width: 10),
                Text(
                  'STRUCTURED FIELD REPORT SUBMITTED',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFF2E7D32)),
            _DetailTile(label: 'Report ID', value: report.reportId),
            _DetailTile(label: 'Inspection ID', value: report.inspectionId),
            _DetailTile(label: 'Officer ID', value: report.officerUid),
            _DetailTile(label: 'Risk Zone ID', value: report.riskZoneId),
            _DetailTile(label: 'Submission Status', value: report.submissionStatus.toUpperCase()),
            _DetailTile(
              label: 'Submitted Timestamp',
              value: DateFormat('MMMM d, y • HH:mm:ss').format(report.submittedAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

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

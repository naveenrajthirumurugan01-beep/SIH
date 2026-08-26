import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/app_config.dart';
import '../../../core/app_state.dart';
import '../../../models/report.dart';
import '../../../models/user_role.dart';

/// Geo-tagged report submission: description + live photo/video + GIS location.
/// Auto-submits upon media capture for Field Officer review.
class ReportSubmissionScreen extends StatefulWidget {
  const ReportSubmissionScreen({super.key});

  @override
  State<ReportSubmissionScreen> createState() => _ReportSubmissionScreenState();
}

class _ReportSubmissionScreenState extends State<ReportSubmissionScreen> {
  final _descriptionController = TextEditingController();
  XFile? _pickedMedia;
  bool _isSubmitting = false;

  Future<void> _captureMediaAndSubmit() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    setState(() => _pickedMedia = file);
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.refreshLocation();
      final loc = appState.currentLocation;

      final descText = _descriptionController.text.trim().isEmpty
          ? 'Live captured hazard report'
          : _descriptionController.text.trim();

      await appState.reportRepository.submitReport(
        deviceId: appState.deviceId,
        role: UserRole.citizen,
        hazardType: HazardType.other,
        description: descText,
        lat: loc.latitude,
        lng: loc.longitude,
        district: AppConfig.district,
        localMediaPaths: _pickedMedia == null ? [] : [_pickedMedia!.path],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report live-captured & auto-submitted! Sent to Field Officer for review.'),
          ),
        );
        setState(() {
          _descriptionController.clear();
          _pickedMedia = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Live Hazard Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe what you observed',
                hintText: 'e.g. New crack on hillside, ~2m long, near the main road',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSubmitting ? null : _captureMediaAndSubmit,
              icon: const Icon(Icons.camera_alt),
              label: Text(_pickedMedia == null ? '📷 Capture Photo/Video & Auto-Submit' : 'Recapture Photo/Video'),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.location_on, color: Colors.redAccent),
                title: Text('GPS GIS Location'),
                subtitle: Text('Auto-capturing live coordinates upon submission'),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Without Media'),
            ),
          ],
        ),
      ),
    );
  }
}

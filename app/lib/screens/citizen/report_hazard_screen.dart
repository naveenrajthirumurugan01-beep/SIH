import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../models/report.dart';
import '../../models/user_role.dart';
import '../../widgets/hazard_icons.dart';

class ReportHazardScreen extends StatefulWidget {
  const ReportHazardScreen({super.key});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final _descriptionController = TextEditingController();
  HazardType _hazardType = HazardType.crack;
  XFile? _media;
  bool _isLocating = true;
  bool _isSubmitting = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    final appState = context.read<AppState>();
    await appState.refreshLocation();
    if (!mounted) return;
    setState(() {
      _lat = appState.currentLocation.latitude;
      _lng = appState.currentLocation.longitude;
      _isLocating = false;
    });
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _media = file);
  }

  Future<void> _submit() async {
    if (_lat == null || _lng == null) return;

    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.reportRepository.submitReport(
        deviceId: appState.deviceId,
        role: UserRole.citizen,
        hazardType: _hazardType,
        description: _descriptionController.text.trim(),
        lat: _lat!,
        lng: _lng!,
        district: AppConfig.district,
        localMediaPaths: _media == null ? [] : [_media!.path],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Track it under My Reports.')),
      );
      setState(() {
        _descriptionController.clear();
        _media = null;
        _hazardType = HazardType.crack;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isLocating && !_isSubmitting && _descriptionController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Report a Hazard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Hazard type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in HazardType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    avatar: Icon(iconForHazard(type), size: 18),
                    selected: _hazardType == type,
                    onSelected: (_) => setState(() => _hazardType = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Describe what you observed',
                hintText: 'e.g. New crack on hillside, ~2m long, near the main road',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.camera_alt),
              label: Text(_media == null ? 'Attach Photo/Video' : 'Photo attached'),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: _isLocating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on),
                title: Text(
                  _isLocating
                      ? 'Capturing your location…'
                      : 'Lat ${_lat!.toStringAsFixed(5)}, Lng ${_lng!.toStringAsFixed(5)}',
                ),
                subtitle: Text(DateFormat('d MMM y, HH:mm').format(DateTime.now())),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}

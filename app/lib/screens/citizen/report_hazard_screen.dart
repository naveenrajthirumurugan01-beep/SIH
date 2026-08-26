import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../models/report.dart';
import '../../models/user_role.dart';
import '../../widgets/hazard_icons.dart';

/// Historical observation patterns per Hazard Type (derived from NESAC & GSI NER archives)
final Map<HazardType, List<String>> _historicalSuggestions = {
  HazardType.crack: [
    'New longitudinal tension crack ~2m long on road embankment',
    'Widening soil fissure observed near hill slope crown after rain',
    'Deep ground crack appearing along residential hill slope edge',
  ],
  HazardType.landslide: [
    'Active mudslide sliding down hill slope after heavy rain',
    'Fresh earth collapse displacing debris across main highway road',
    'Deep-seated slope movement near village settlement',
  ],
  HazardType.rockfall: [
    'Unstable boulders rolling down onto highway path',
    'Small rock fragments accumulating at slope toe section',
    'Loose stones dislodging from steep rock cut',
  ],
  HazardType.roadBlockage: [
    'Debris and mud blocking both highway traffic lanes',
    'Fallen rocks and trees blocking vehicle access',
    'Partial lane blockage due to slope slumping',
  ],
  HazardType.waterSeepage: [
    'Sudden water gushing out of retaining wall weep holes',
    'Unusual muddy water spring appearing at slope base',
    'Water accumulation causing heavy slope saturation',
  ],
  HazardType.soilMovement: [
    'Creeping soil displacement tilting trees and utility poles',
    'Soft soil erosion along hill road cutting edge',
    'Soil slumping observed above highway cut slope',
  ],
  HazardType.damagedInfrastructure: [
    'Cracked retaining wall bulging outward under soil pressure',
    'Blockade in drainage channel causing road washaway',
    'Culvert damage with soil subsidence beneath foundation',
  ],
  HazardType.other: [
    'Unusual ground vibration or slope movement sounds heard',
    'Tilting structures or retaining wall displacement observed',
  ],
};

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

  void _applySuggestion(String suggestion) {
    setState(() {
      if (_descriptionController.text.isEmpty) {
        _descriptionController.text = suggestion;
      } else {
        _descriptionController.text = '${_descriptionController.text.trim()}. $suggestion';
      }
    });
  }

  /// Live Capture Photo/Video with immediate auto-submission
  Future<void> _captureMediaAndSubmit() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    setState(() {
      _media = file;
    });

    // Auto-fill description if blank using historical pattern default
    if (_descriptionController.text.trim().isEmpty) {
      final suggestions = _historicalSuggestions[_hazardType];
      if (suggestions != null && suggestions.isNotEmpty) {
        _descriptionController.text = suggestions.first;
      } else {
        _descriptionController.text = 'Live captured ${_hazardType.label} hazard';
      }
    }

    // Auto-submit immediately upon media capture
    await _submit();
  }

  Future<void> _submit() async {
    if (_lat == null || _lng == null) {
      await _captureLocation();
    }
    if (_lat == null || _lng == null) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      final descText = _descriptionController.text.trim().isEmpty
          ? 'Live captured ${_hazardType.label} hazard'
          : _descriptionController.text.trim();

      await appState.reportRepository.submitReport(
        deviceId: appState.deviceId,
        role: UserRole.citizen,
        hazardType: _hazardType,
        description: descText,
        lat: _lat!,
        lng: _lng!,
        district: AppConfig.district,
        localMediaPaths: _media == null ? [] : [_media!.path],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 8),
              Expanded(
                child: Text('Report live-captured & auto-submitted! Sent to Field Officer for review.'),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
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
    final canSubmit = !_isLocating && !_isSubmitting;
    final suggestions = _historicalSuggestions[_hazardType] ?? [];

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
            const SizedBox(height: 16),

            // AI / Historical Auto-Suggest Chips
            if (suggestions.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'AI Suggested Descriptions (from NER records)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.amber.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _applySuggestion(suggestion),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _descriptionController,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Describe what you observed',
                hintText: 'Tap AI suggestion above or type observation details...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Live Camera Capture & Auto-Submit Action Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _media == null
                    ? Theme.of(context).colorScheme.primary
                    : Colors.teal,
              ),
              onPressed: canSubmit ? _captureMediaAndSubmit : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(
                _isSubmitting
                    ? 'Auto-Submitting Report...'
                    : (_media == null
                        ? '📷 Capture Photo/Video & Auto-Submit'
                        : 'Recapture Photo/Video'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
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
                    : const Icon(Icons.location_on, color: Colors.redAccent),
                title: Text(
                  _isLocating
                      ? 'Capturing GIS coordinates...'
                      : 'GIS: Lat ${_lat!.toStringAsFixed(5)}, Lng ${_lng!.toStringAsFixed(5)}',
                ),
                subtitle: Text(DateFormat('d MMM y, HH:mm').format(DateTime.now())),
              ),
            ),
            const SizedBox(height: 20),

            OutlinedButton(
              onPressed: canSubmit ? _submit : null,
              child: const Text('Submit Without Media'),
            ),
          ],
        ),
      ),
    );
  }
}

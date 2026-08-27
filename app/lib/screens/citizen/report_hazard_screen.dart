import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/citizen_theme.dart';
import '../../models/report.dart';
import '../../models/risk_zone.dart';
import '../../models/user_role.dart';
import 'live_location_screen.dart';
import 'report_submitted_screen.dart';

/// Historical AI-suggested descriptions per hazard type (NER archive derived)
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
  final HazardType? presetType;
  const ReportHazardScreen({super.key, this.presetType});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final _descController = TextEditingController();
  late HazardType _hazardType;
  final List<XFile> _mediaFiles = [];
  bool _isLocating = true;
  bool _isSubmitting = false;
  double? _lat;
  double? _lng;
  String _locationLabel = 'Detecting location…';
  DateTime _observedAt = DateTime.now();
  RiskLevel _severity = RiskLevel.moderate;

  @override
  void initState() {
    super.initState();
    _hazardType = widget.presetType ?? HazardType.landslide;
    _captureLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    final appState = context.read<AppState>();
    await appState.refreshLocation();
    if (!mounted) return;
    final loc = appState.currentLocation;
    setState(() {
      _lat = loc.latitude;
      _lng = loc.longitude;
      _locationLabel = AppConfig.fallbackVillageName;
      _isLocating = false;
    });
  }

  Future<void> _openLiveLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const LiveLocationScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _locationLabel =
            'Near ${AppConfig.fallbackVillageName.split(',').first}, ${AppConfig.stateName}';
      });
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null && mounted) {
      setState(() => _mediaFiles.add(file));
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _observedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _observedAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _applySuggestion(String text) {
    setState(() {
      _descController.text = text;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_lat == null || _lng == null) {
      await _captureLocation();
    }
    if (_lat == null || _lng == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      final desc = _descController.text.trim().isEmpty
          ? (_historicalSuggestions[_hazardType]?.first ??
              '${_hazardType.label} observed')
          : _descController.text.trim();

      final report = await appState.reportRepository.submitReport(
        deviceId: appState.deviceId,
        role: UserRole.citizen,
        hazardType: _hazardType,
        description: desc,
        lat: _lat!,
        lng: _lng!,
        district: AppConfig.district,
        localMediaPaths: _mediaFiles.map((f) => f.path).toList(),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ReportSubmittedScreen(report: report)),
      );

      if (!mounted) return;
      setState(() {
        _descController.clear();
        _mediaFiles.clear();
        _hazardType = HazardType.landslide;
        _severity = RiskLevel.moderate;
        _observedAt = DateTime.now();
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
      backgroundColor: CitizenTheme.background,
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        leading: const BackButton(color: Colors.white),
        title: const Text('Report a Landslide',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── What do you want to report? ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What do you want to report?',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _HazardChip(
                      icon: Icons.landslide_outlined,
                      label: 'Landslide',
                      selected: _hazardType == HazardType.landslide,
                      onTap: () => setState(
                          () => _hazardType = HazardType.landslide),
                    ),
                    const SizedBox(width: 8),
                    _HazardChip(
                      icon: Icons.splitscreen_outlined,
                      label: 'Crack',
                      selected: _hazardType == HazardType.crack,
                      onTap: () =>
                          setState(() => _hazardType = HazardType.crack),
                    ),
                    const SizedBox(width: 8),
                    _HazardChip(
                      icon: Icons.terrain,
                      label: 'Rockfall',
                      selected: _hazardType == HazardType.rockfall,
                      onTap: () => setState(
                          () => _hazardType = HazardType.rockfall),
                    ),
                    const SizedBox(width: 8),
                    _HazardChip(
                      icon: Icons.more_horiz,
                      label: 'Other',
                      selected: _hazardType == HazardType.other,
                      onTap: () =>
                          setState(() => _hazardType = HazardType.other),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Location ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Location',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locationLabel,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                          if (!_isLocating && _lat != null)
                            Text(
                              '${AppConfig.district}, ${AppConfig.stateName}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openLiveLocation,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CitizenTheme.primary.withAlpha(15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: CitizenTheme.primary.withAlpha(60)),
                        ),
                        child: const Icon(Icons.gps_fixed,
                            color: CitizenTheme.primary, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Add Photos / Videos ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Photos / Videos',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < _mediaFiles.length; i++)
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image,
                                  color: CitizenTheme.primary, size: 36),
                            ),
                            Positioned(
                              right: 10,
                              top: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _mediaFiles.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 10, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      GestureDetector(
                        onTap: _pickMedia,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add,
                                  color: CitizenTheme.primary, size: 28),
                              Text('Add More',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: CitizenTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Description ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description (Optional)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                // AI suggestions
                if (suggestions.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'AI Suggested (NER archives)',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in suggestions)
                        GestureDetector(
                          onTap: () => _applySuggestion(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.amber.shade200),
                            ),
                            child: Text(s,
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write what you observed…',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── When did you see it? ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('When did you see it?',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d MMM yyyy, hh:mm a')
                              .format(_observedAt),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Severity ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Severity (Your Observation)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final level in RiskLevel.values) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _severity = level),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            decoration: BoxDecoration(
                              color: _severity == level
                                  ? _levelColor(level)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _levelColor(level),
                              ),
                            ),
                            child: Text(
                              level == RiskLevel.critical
                                  ? 'Very High'
                                  : level.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _severity == level
                                    ? Colors.white
                                    : _levelColor(level),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (level != RiskLevel.critical)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Submit button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: CitizenTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'SUBMIT REPORT',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _levelColor(RiskLevel level) => switch (level) {
        RiskLevel.low => Colors.green,
        RiskLevel.moderate => Colors.orange,
        RiskLevel.high => Colors.red.shade600,
        RiskLevel.critical => Colors.red.shade900,
      };
}

// ──────────────────────────────────────────────────────────────────────────────

class _HazardChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HazardChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? CitizenTheme.primary
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? CitizenTheme.primary
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

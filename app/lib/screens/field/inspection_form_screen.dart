import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/inspection.dart';
import '../../models/task.dart';
import '../../services/task_repository.dart';

/// Structured inspection form — every field is a chip/switch selection,
/// never free text, so findings stay machine-readable (they drive the
/// linked report's status update; see InspectionRepository.submitInspection).
class InspectionFormScreen extends StatefulWidget {
  final InspectionTask task;
  final double checkInLat;
  final double checkInLng;
  final DateTime checkInAt;

  const InspectionFormScreen({
    super.key,
    required this.task,
    required this.checkInLat,
    required this.checkInLng,
    required this.checkInAt,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  CrackStatus _crackStatus = CrackStatus.none;
  SlopeMovement _slopeMovement = SlopeMovement.none;
  bool _rockfall = false;
  bool _waterSeepage = false;
  RoadCondition _roadCondition = RoadCondition.open;
  final _notesController = TextEditingController();
  final List<XFile> _photos = [];
  bool _isSubmitting = false;

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _photos.add(file));
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.inspectionRepository.submitInspection(
        task: widget.task,
        officerUid: appState.officerId ?? demoOfficerUid,
        officerName: appState.officerName ?? 'Field Officer',
        checkInLat: widget.checkInLat,
        checkInLng: widget.checkInLng,
        checkInAt: widget.checkInAt,
        crackStatus: _crackStatus,
        slopeMovement: _slopeMovement,
        rockfall: _rockfall,
        waterSeepage: _waterSeepage,
        roadCondition: _roadCondition,
        notes: _notesController.text.trim(),
        localPhotoPaths: _photos.map((f) => f.path).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection submitted. Linked report updated.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Form')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Crack status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final status in CrackStatus.values)
                  ChoiceChip(
                    label: Text(status.label),
                    selected: _crackStatus == status,
                    onSelected: (_) => setState(() => _crackStatus = status),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Slope movement', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final movement in SlopeMovement.values)
                  ChoiceChip(
                    label: Text(movement.label),
                    selected: _slopeMovement == movement,
                    onSelected: (_) => setState(() => _slopeMovement = movement),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rockfall observed'),
              value: _rockfall,
              onChanged: (value) => setState(() => _rockfall = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Water seepage observed'),
              value: _waterSeepage,
              onChanged: (value) => setState(() => _waterSeepage = value),
            ),
            const SizedBox(height: 8),
            Text('Road condition', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final condition in RoadCondition.values)
                  ChoiceChip(
                    label: Text(condition.label),
                    selected: _roadCondition == condition,
                    onSelected: (_) => setState(() => _roadCondition = condition),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text('Add Photo (${_photos.length})'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Inspection'),
            ),
          ],
        ),
      ),
    );
  }
}

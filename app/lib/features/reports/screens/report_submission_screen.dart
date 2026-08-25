import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Geo-tagged report submission: description + photo/video + location.
/// Shared by citizens and field officials; field officials additionally
/// get the road status field (TODO: gate with AuthProvider.role).
///
/// TODO:
///  - capture device location via geolocator and show it / let the user
///    confirm or drag-adjust a pin
///  - upload picked media to Firebase Storage under report_media/{uid}/...
///  - call ReportService.submitReport with the resulting media URLs
class ReportSubmissionScreen extends StatefulWidget {
  const ReportSubmissionScreen({super.key});

  @override
  State<ReportSubmissionScreen> createState() => _ReportSubmissionScreenState();
}

class _ReportSubmissionScreenState extends State<ReportSubmissionScreen> {
  final _descriptionController = TextEditingController();
  XFile? _pickedMedia;
  bool _isSubmitting = false;

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _pickedMedia = file);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      // TODO: implement via ReportService.submitReport once storage upload
      // and geolocation capture are wired up.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TODO: report submission not yet implemented')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Report')),
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
            OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.camera_alt),
              label: Text(_pickedMedia == null ? 'Attach Photo/Video' : 'Photo attached'),
            ),
            const SizedBox(height: 16),
            // TODO: location picker/confirmation widget.
            const Card(
              child: ListTile(
                leading: Icon(Icons.location_on_outlined),
                title: Text('Location'),
                subtitle: Text('TODO: capture current GPS position'),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
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

import 'package:flutter/material.dart';

/// TODO: fetch the single report by id (Firestore doc get or a stream),
/// render media carousel, map pin, description, status, and (for
/// analyst/admin) approve/reject controls calling ReportService.reviewReport.
class ReportDetailScreen extends StatelessWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report $reportId')),
      body: const Center(child: Text('TODO: report detail view')),
    );
  }
}

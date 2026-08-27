import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/inspection.dart';

class MyInspectionsScreen extends StatelessWidget {
  const MyInspectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Inspections')),
      body: StreamBuilder<List<FieldInspection>>(
        stream: appState.inspectionRepository.watchMyInspections(appState.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final inspections = snapshot.data!;
          if (inspections.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No inspections submitted yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: inspections.length,
            itemBuilder: (context, index) => _InspectionCard(inspection: inspections[index]),
          );
        },
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final FieldInspection inspection;

  const _InspectionCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final hazard = inspection.indicatesHazard;

    return Card(
      child: ExpansionTile(
        leading: Icon(
          hazard ? Icons.warning_amber : Icons.check_circle,
          color: hazard ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32),
        ),
        title: Text(DateFormat('d MMM y, HH:mm').format(inspection.submittedAt)),
        subtitle: Text(hazard ? 'Hazard confirmed' : 'No hazard found'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crack: ${inspection.crackStatus.label}'),
                Text('Slope movement: ${inspection.slopeMovement.label}'),
                Text('Rockfall: ${inspection.rockfall ? 'Yes' : 'No'}'),
                Text('Water seepage: ${inspection.waterSeepage ? 'Yes' : 'No'}'),
                Text('Road condition: ${inspection.roadCondition.label}'),
                if (inspection.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(inspection.notes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

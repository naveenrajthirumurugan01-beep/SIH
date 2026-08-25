import 'package:flutter/material.dart';

/// TODO: stream the alerts/ Firestore collection (filtered to the user's
/// district for citizens/field officials, unfiltered for analysts) and
/// render a timeline of push/SMS alerts that have gone out.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: const Center(child: Text('TODO: alert history not yet connected to Firestore.')),
    );
  }
}

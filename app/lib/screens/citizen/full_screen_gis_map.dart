import 'package:flutter/material.dart';

import '../../core/citizen_theme.dart';
import '../../widgets/gis_map_widget.dart';

/// Full-screen GIS & Weather map view for citizens.
class FullScreenGisMapScreen extends StatelessWidget {
  const FullScreenGisMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CitizenTheme.primary,
        title: const Text('Dibang Valley GIS & Weather Map', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const GisMapWidget(isFullScreen: true),
    );
  }
}

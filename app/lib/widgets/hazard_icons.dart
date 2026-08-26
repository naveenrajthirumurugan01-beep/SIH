import 'package:flutter/material.dart';

import '../models/report.dart';

IconData iconForHazard(HazardType type) => switch (type) {
      HazardType.crack => Icons.linear_scale,
      HazardType.landslide => Icons.landscape,
      HazardType.rockfall => Icons.terrain,
      HazardType.roadBlockage => Icons.block,
      HazardType.waterSeepage => Icons.water_drop,
      HazardType.soilMovement => Icons.grain,
      HazardType.damagedInfrastructure => Icons.domain_disabled,
      HazardType.other => Icons.report_problem,
    };

import '../models/report.dart';
import '../models/risk_zone.dart';

/// Report has no dedicated citizen-reported severity field — the original
/// submission form doesn't collect one (see models/report.dart, shared
/// with the Citizen app's report_hazard_screen.dart, which this
/// deliberately doesn't modify). This is a display-only estimate derived
/// from the hazard type the citizen picked — not a stored field, and not
/// presented as analyst-confirmed severity.
///
/// Shared by ReportsQueueScreen (display) and RiskMapScreen (so picking a
/// severity in the GIS layer panel also narrows the Citizen Reports layer
/// consistently, instead of each screen inventing its own estimate).
RiskLevel inferredSeverityForReport(Report report) => switch (report.hazardType) {
      HazardType.landslide => RiskLevel.critical,
      HazardType.rockfall => RiskLevel.high,
      HazardType.soilMovement => RiskLevel.high,
      HazardType.roadBlockage => RiskLevel.moderate,
      HazardType.waterSeepage => RiskLevel.moderate,
      HazardType.crack => RiskLevel.moderate,
      HazardType.damagedInfrastructure => RiskLevel.moderate,
      HazardType.other => RiskLevel.low,
    };

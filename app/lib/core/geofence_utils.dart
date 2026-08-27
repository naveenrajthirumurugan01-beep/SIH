import '../models/risk_zone.dart';

/// MVP placeholder radius-by-severity lookup — NOT a GIS computation. We
/// don't have real risk-zone polygons yet, so the geofence size is just a
/// flat guess per severity tier rather than something derived from actual
/// zone geometry. Replace this with zone-boundary-derived sizing once
/// polygon risk zones exist (see models/geofence.dart's GeofenceType for
/// where polygon support would plug in).
///
/// The Analyst's manual-assignment flow shows this value pre-filled but
/// editable, up to a higher cap (see screens/analyst/tasks_screen.dart) —
/// automatic assignment always uses the lookup value as-is.
double radiusMetersForSeverity(RiskLevel severity) => switch (severity) {
      RiskLevel.low => 500,
      RiskLevel.moderate => 2000,
      RiskLevel.high => 5000,
      RiskLevel.critical => 8000,
    };

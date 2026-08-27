import 'dart:math';

import '../core/app_config.dart';
import '../core/geofence_utils.dart';
import '../models/alert.dart';
import '../models/geofence.dart';
import '../models/historical_landslide.dart';
import '../models/inspection.dart';
import '../models/report.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';
import '../models/user_role.dart';

/// Fixed, arbitrary — NOT time-based. Every `Random(_seed)` built from this
/// produces the identical sequence on every app run, so the whole demo
/// dataset (zones, historical events, tasks, reports, alerts, and the
/// weather reading derived from it) is stable across restarts/hot
/// reloads, not a fresh random dataset each time.
const _seed = 20260827;

/// Real Firebase Auth uids for the three fixed demo accounts (see
/// RoleSelectScreen's `_demoCredentials` and Firebase Console) — used so
/// synthetic tasks assigned "to the Field Officer" actually show up when
/// signing in as field@gmail.com, and so `assignedBy`/alert
/// authorship reads as the real Analyst account.
const realFieldOfficerUid = 'MQpjmSmxSVfNaLk8rIsfJB9gkkE3'; // field@gmail.com
const realAnalystUid = 'l16ysYvpCFSC2QIAI2dbu7o4b552'; // analyst@gmail.com
const realCitizenUid = 'tWdFTvE5oahcCz93tm80xy8UyDF2'; // citizen@gmail.com

/// One shared, seeded synthetic dataset for every Mock repository and for
/// [DemoWeatherProvider] (see weather_provider.dart) — the single source
/// of truth so a zone's risk score, its historical event count, the tasks
/// inspecting it, and the valley-wide weather reading all agree with each
/// other instead of being independently-random per repository.
///
/// SYNTHETIC — replace with real Firestore data / a trained model. Every
/// number here is generated, not measured — see each field's generation
/// comment below for exactly how.
class SyntheticDataset {
  final List<RiskZone> zones;
  final List<HistoricalLandslide> historicalLandslides;
  final List<InspectionTask> tasks;
  final List<Report> reports;
  final List<HazardAlert> alerts;
  final List<FieldInspection> fieldInspections;

  const SyntheticDataset._({
    required this.zones,
    required this.historicalLandslides,
    required this.tasks,
    required this.reports,
    required this.alerts,
    required this.fieldInspections,
  });

  /// Generated once, on first access, and cached — every Mock repository
  /// reads from this same instance.
  static final SyntheticDataset instance = _generate();

  static SyntheticDataset _generate() {
    final rng = Random(_seed);

    final blueprints = _buildZoneBlueprints(rng);
    final historicalLandslides = _buildHistoricalLandslides(rng, blueprints);

    final eventCountByZone = <String, int>{};
    for (final event in historicalLandslides) {
      final zoneId = event.relatedZoneId;
      if (zoneId == null) continue;
      eventCountByZone[zoneId] = (eventCountByZone[zoneId] ?? 0) + 1;
    }

    final zones = [
      for (final bp in blueprints) bp.toRiskZone(rng, eventCountByZone[bp.id] ?? 0),
    ];

    final reports = _buildReports(rng, zones);
    final tasks = _buildTasks(rng, zones, reports);
    final alerts = _buildAlerts(rng, zones);
    final fieldInspections = _buildFieldInspections(rng, tasks);

    return SyntheticDataset._(
      zones: zones,
      historicalLandslides: historicalLandslides,
      tasks: tasks,
      reports: reports,
      alerts: alerts,
      fieldInspections: fieldInspections,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared scoring helpers — deliberately mirror RiskFactorProvider's existing
// 3-band thresholds (see services/risk_factor_provider.dart's `_band`), just
// interpolated into a continuous 0-1 score instead of banding straight to
// low/moderate/high, so riskScore varies smoothly instead of clumping at 3
// fixed values.
// ---------------------------------------------------------------------------

double _normalize(double value, double lowMax, double highMin) {
  if (value <= lowMax) {
    return lowMax <= 0 ? 0.0 : (value / lowMax).clamp(0.0, 1.0) * 0.33;
  }
  if (value >= highMin) {
    final extra = highMin <= 0 ? 1.0 : (value - highMin) / (highMin * 0.4);
    return (0.67 + extra.clamp(0.0, 1.0) * 0.33).clamp(0.0, 1.0);
  }
  final span = highMin - lowMax;
  return 0.33 + (value - lowMax) / span * 0.34;
}

/// Susceptibility signal from terrain/weather features ONLY (no historical
/// event count — that would be circular, since this weight is what decides
/// where historical events get placed in the first place). Matches the
/// factor set (minus Lithology/LULC, which have no numeric field to derive
/// a weight from) that RiskFactorProvider itself uses.
double _preliminaryWeight(_ZoneBlueprint bp) {
  final slope = _normalize(bp.slopeMaxDegrees, 25, 45);
  final rainfall = _normalize(bp.rainfall24hMm, 5, 10);
  final soil = _normalize(bp.soilMoisturePercent, 40, 70);
  final lineament = _normalize(bp.lineamentDensity, 0.3, 0.6);
  return (slope + rainfall + soil + lineament) / 4;
}

RiskLevel _levelForScore(double score) {
  if (score >= 0.75) return RiskLevel.critical;
  if (score >= 0.5) return RiskLevel.high;
  if (score >= 0.25) return RiskLevel.moderate;
  return RiskLevel.low;
}

int _weightedPick(List<double> weights, Random rng) {
  // Every zone gets a small floor weight so even a low-susceptibility zone
  // has a (small) chance of a historical event — real slopes occasionally
  // fail for reasons terrain alone doesn't fully explain.
  final floored = weights.map((w) => w + 0.05).toList();
  final total = floored.fold<double>(0, (a, b) => a + b);
  var roll = rng.nextDouble() * total;
  for (var i = 0; i < floored.length; i++) {
    roll -= floored[i];
    if (roll <= 0) return i;
  }
  return floored.length - 1;
}

// ---------------------------------------------------------------------------
// Zone generation
// ---------------------------------------------------------------------------

class _ZoneBlueprint {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusKm;
  final String? notes;
  final double slopeMinDegrees;
  final double slopeMaxDegrees;
  final double rainfall24hMm;
  final double soilMoisturePercent;
  final String lithology;
  final String lulc;
  final double lineamentDensity;
  final double nearestRoadKm;

  const _ZoneBlueprint({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.slopeMinDegrees,
    required this.slopeMaxDegrees,
    required this.rainfall24hMm,
    required this.soilMoisturePercent,
    required this.lithology,
    required this.lulc,
    required this.lineamentDensity,
    required this.nearestRoadKm,
    this.notes,
  });

  RiskZone toRiskZone(Random rng, int historicalEventCount) {
    final slopeScore = _normalize(slopeMaxDegrees, 25, 45);
    final rainfallScore = _normalize(rainfall24hMm, 5, 10);
    final soilScore = _normalize(soilMoisturePercent, 40, 70);
    final lineamentScore = _normalize(lineamentDensity, 0.3, 0.6);
    final historicalScore = _normalize(historicalEventCount.toDouble(), 1, 3);

    final raw = slopeScore * 0.25 +
        rainfallScore * 0.20 +
        soilScore * 0.20 +
        lineamentScore * 0.15 +
        historicalScore * 0.20;
    // Small seeded jitter so riskScore isn't a pure, perfectly-repeatable
    // function of the visible features — still deterministic run-to-run
    // (same seed), just not obviously formulaic at a glance.
    final noise = (rng.nextDouble() - 0.5) * 0.08;
    final riskScore = (raw + noise).clamp(0.0, 1.0);

    final confidencePercent = (55 +
            historicalEventCount.clamp(0, 5) * 6 +
            (rng.nextDouble() - 0.5) * 10)
        .clamp(50.0, 95.0);

    return RiskZone(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      level: _levelForScore(riskScore),
      district: AppConfig.district,
      updatedAt: DateTime.now().subtract(Duration(hours: rng.nextInt(72))),
      notes: notes,
      riskScore: riskScore,
      confidencePercent: confidencePercent,
      slopeMinDegrees: slopeMinDegrees,
      slopeMaxDegrees: slopeMaxDegrees,
      rainfall24hMm: rainfall24hMm,
      soilMoisturePercent: soilMoisturePercent,
      historicalEventCount: historicalEventCount,
      nearestRoadKm: nearestRoadKm,
      lithology: lithology,
      lulc: lulc,
      lineamentDensity: lineamentDensity,
    );
  }
}

const _lithologyOptions = [
  'Weathered Phyllite/Schist',
  'Fractured Gneiss',
  'Compact Sandstone',
  'Alluvium/Sandstone',
  'Compact Granite',
  'Compact Basalt',
  'Weathered Schist',
];

const _lulcOptions = [
  'Sparse Forest / Bare Slope',
  'Mixed Forest',
  'Settlement/Cropland',
  'River Terrace/Cropland',
  'Dense Forest',
  'Scrubland',
];

const _nameQualifiers = [
  'Upper', 'Lower', 'Eastern', 'Western', 'Northern', 'Southern',
  'Inner', 'Outer', 'Middle', 'Far',
];
const _nameFeatures = [
  'Ridge', 'Slope', 'Valley', 'Belt', 'Corridor', 'Bend', 'Basin', 'Pass', 'Terrace',
];
// Both rivers are already referenced elsewhere in this app (see
// dev/seed_demo_data.dart's "Confluence of the Dri and Tangon rivers" note)
// — reused here rather than inventing new hydrology, so generated zone
// names stay consistent with the rest of the demo's geography.
const _nameLandmarks = ['Dri', 'Tangon'];

List<_ZoneBlueprint> _buildZoneBlueprints(Random rng) {
  // The 5 "hero" locations the rest of the app already names explicitly
  // (Dri River, Ithun Valley, Anini, Etalin, West Slope) plus the 2 belt
  // zones that were already in MockRiskRepository — hand-curated values
  // reused from the existing seed data for continuity, not regenerated.
  final hero = <_ZoneBlueprint>[
    const _ZoneBlueprint(
      id: 'zone_confirmed_1',
      name: 'Confirmed Slide Point — Dri River Slope',
      lat: 28.7891,
      lng: 95.8328,
      radiusKm: 1.5,
      notes: 'Near Mathunli Village. Anchored at a Bhuvan-confirmed landslide point.',
      slopeMinDegrees: 38,
      slopeMaxDegrees: 58,
      rainfall24hMm: 17.5,
      soilMoisturePercent: 85,
      lithology: 'Weathered Phyllite/Schist',
      lulc: 'Sparse Forest / Bare Slope',
      lineamentDensity: 0.85,
      nearestRoadKm: 2.3,
    ),
    const _ZoneBlueprint(
      id: 'zone_confirmed_2',
      name: 'Confirmed Slide Point — Ithun Valley Slope',
      lat: 28.7647,
      lng: 95.8248,
      radiusKm: 1.5,
      notes: 'Anchored at a Bhuvan-confirmed landslide point.',
      slopeMinDegrees: 30,
      slopeMaxDegrees: 48,
      rainfall24hMm: 9.1,
      soilMoisturePercent: 64,
      lithology: 'Fractured Gneiss',
      lulc: 'Mixed Forest',
      lineamentDensity: 0.55,
      nearestRoadKm: 1.8,
    ),
    const _ZoneBlueprint(
      id: 'zone_anini_town',
      name: 'Anini Township',
      lat: 28.8167,
      lng: 95.8333,
      radiusKm: 3.0,
      notes: 'District headquarters area.',
      slopeMinDegrees: 15,
      slopeMaxDegrees: 28,
      rainfall24hMm: 6.2,
      soilMoisturePercent: 45,
      lithology: 'Compact Sandstone',
      lulc: 'Settlement/Cropland',
      lineamentDensity: 0.30,
      nearestRoadKm: 0.5,
    ),
    const _ZoneBlueprint(
      id: 'zone_etalin',
      name: 'Etalin Confluence Area',
      lat: 28.7500,
      lng: 95.8500,
      radiusKm: 3.0,
      notes: 'Confluence of the Dri and Tangon rivers.',
      slopeMinDegrees: 18,
      slopeMaxDegrees: 30,
      rainfall24hMm: 7.0,
      soilMoisturePercent: 50,
      lithology: 'Alluvium/Sandstone',
      lulc: 'River Terrace/Cropland',
      lineamentDensity: 0.28,
      nearestRoadKm: 1.2,
    ),
    const _ZoneBlueprint(
      id: 'zone_north_ridge',
      name: 'Northern Ridge Belt',
      lat: 28.8400,
      lng: 95.7600,
      radiusKm: 4.0,
      notes: 'Stable forested ridge line.',
      slopeMinDegrees: 10,
      slopeMaxDegrees: 20,
      rainfall24hMm: 4.0,
      soilMoisturePercent: 30,
      lithology: 'Compact Granite',
      lulc: 'Dense Forest',
      lineamentDensity: 0.15,
      nearestRoadKm: 4.5,
    ),
    const _ZoneBlueprint(
      id: 'zone_south_valley',
      name: 'Southern Valley Belt',
      lat: 28.6500,
      lng: 95.9200,
      radiusKm: 4.0,
      notes: 'Stable valley floor, dense cover.',
      slopeMinDegrees: 8,
      slopeMaxDegrees: 18,
      rainfall24hMm: 3.5,
      soilMoisturePercent: 28,
      lithology: 'Compact Basalt',
      lulc: 'Dense Forest',
      lineamentDensity: 0.12,
      nearestRoadKm: 5.1,
    ),
    const _ZoneBlueprint(
      id: 'zone_west_slope',
      name: 'Western Slope Corridor',
      lat: 28.7200,
      lng: 95.7300,
      radiusKm: 3.0,
      notes: 'Scrubland corridor, moderate historical activity.',
      slopeMinDegrees: 22,
      slopeMaxDegrees: 35,
      rainfall24hMm: 8.3,
      soilMoisturePercent: 55,
      lithology: 'Weathered Schist',
      lulc: 'Scrubland',
      lineamentDensity: 0.42,
      nearestRoadKm: 2.0,
    ),
  ];

  // 11 more, procedurally placed — 18 zones total. Scattered by random
  // angle + random radius fraction around the study-area center (not an
  // even grid, not clustered on one point), clamped inside the study
  // area's bounding box.
  final generated = <_ZoneBlueprint>[];
  final usedNames = <String>{for (final z in hero) z.name};
  final maxRadiusLat = (AppConfig.studyAreaMaxLat - AppConfig.studyAreaMinLat) / 2 * 0.85;
  final maxRadiusLng = (AppConfig.studyAreaMaxLng - AppConfig.studyAreaMinLng) / 2 * 0.85;

  for (var i = 0; i < 11; i++) {
    String name;
    do {
      final qualifier = _nameQualifiers[rng.nextInt(_nameQualifiers.length)];
      final useLandmark = rng.nextBool();
      final middle =
          useLandmark ? _nameLandmarks[rng.nextInt(_nameLandmarks.length)] : qualifier;
      final feature = _nameFeatures[rng.nextInt(_nameFeatures.length)];
      name = useLandmark ? '$qualifier $middle $feature' : '$qualifier $feature';
    } while (!usedNames.add(name));

    final angle = rng.nextDouble() * 2 * pi;
    final radiusFraction = 0.25 + rng.nextDouble() * 0.75;
    final lat = (AppConfig.studyAreaCenterLat + cos(angle) * maxRadiusLat * radiusFraction)
        .clamp(AppConfig.studyAreaMinLat, AppConfig.studyAreaMaxLat);
    final lng = (AppConfig.studyAreaCenterLng + sin(angle) * maxRadiusLng * radiusFraction)
        .clamp(AppConfig.studyAreaMinLng, AppConfig.studyAreaMaxLng);

    final slopeMin = 5 + rng.nextDouble() * 20;
    final slopeMax = slopeMin + 8 + rng.nextDouble() * 20;

    generated.add(
      _ZoneBlueprint(
        id: 'zone_gen_${i + 1}',
        name: name,
        lat: lat,
        lng: lng,
        radiusKm: 1.5 + rng.nextDouble() * 2.5,
        notes: 'SYNTHETIC — procedurally generated, see lib/dev/synthetic_dataset.dart.',
        slopeMinDegrees: slopeMin,
        slopeMaxDegrees: slopeMax,
        rainfall24hMm: 2 + rng.nextDouble() * 16,
        soilMoisturePercent: 20 + rng.nextDouble() * 60,
        lithology: _lithologyOptions[rng.nextInt(_lithologyOptions.length)],
        lulc: _lulcOptions[rng.nextInt(_lulcOptions.length)],
        lineamentDensity: 0.05 + rng.nextDouble() * 0.75,
        nearestRoadKm: 0.3 + rng.nextDouble() * 5.5,
      ),
    );
  }

  return [...hero, ...generated];
}

// ---------------------------------------------------------------------------
// Historical landslides
// ---------------------------------------------------------------------------

const _eventTriggers = [
  'Heavy monsoon rainfall',
  'Prolonged soil saturation',
  'Road-cutting destabilization',
  'Minor seismic tremor',
  'Snowmelt-driven saturation',
  'Undercutting by river erosion',
];

String _severityFor(double weight, Random rng) {
  final roll = rng.nextDouble();
  if (weight > 0.6) {
    if (roll < 0.5) return 'Major';
    if (roll < 0.85) return 'Moderate';
    return 'Minor';
  }
  if (weight > 0.3) {
    if (roll < 0.2) return 'Major';
    if (roll < 0.7) return 'Moderate';
    return 'Minor';
  }
  if (roll < 0.05) return 'Major';
  if (roll < 0.35) return 'Moderate';
  return 'Minor';
}

List<HistoricalLandslide> _buildHistoricalLandslides(Random rng, List<_ZoneBlueprint> zones) {
  final weights = zones.map(_preliminaryWeight).toList();
  final now = DateTime.now();
  const eventCount = 20;

  return [
    for (var i = 0; i < eventCount; i++)
      () {
        final zoneIndex = _weightedPick(weights, rng);
        final zone = zones[zoneIndex];
        final jitterLat = (rng.nextDouble() - 0.5) * 0.01;
        final jitterLng = (rng.nextDouble() - 0.5) * 0.01;
        final daysAgo = rng.nextInt(365 * 6);

        return HistoricalLandslide(
          id: 'hist_${zone.id}_$i',
          locationName: zone.name,
          lat: zone.lat + jitterLat,
          lng: zone.lng + jitterLng,
          eventDate: now.subtract(Duration(days: daysAgo)),
          severity: _severityFor(weights[zoneIndex], rng),
          source: 'SYNTHETIC — demo placeholder, not a verified survey record. '
              '${_eventTriggers[rng.nextInt(_eventTriggers.length)]}.',
          relatedZoneId: zone.id,
        );
      }(),
  ];
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

const _reportStatusCycle = [
  ReportStatus.submitted,
  ReportStatus.submitted,
  ReportStatus.underReview,
  ReportStatus.underReview,
  ReportStatus.fieldVerification,
  ReportStatus.verified,
  ReportStatus.verified,
  ReportStatus.resolved,
  ReportStatus.resolved,
  ReportStatus.rejected,
];

const _reporterUids = [
  realCitizenUid,
  'demo_citizen_2',
  'demo_citizen_3',
  'demo_citizen_4',
];

String _reportDescriptionFor(HazardType type, String zoneName) => switch (type) {
      HazardType.crack =>
        'Crack noticed on the slope near $zoneName, a few metres long and seems to be widening.',
      HazardType.landslide => 'Small landslide occurred near $zoneName after recent rain.',
      HazardType.rockfall => 'Loose rocks falling from the slope above $zoneName.',
      HazardType.roadBlockage => 'Road partially blocked by debris near $zoneName.',
      HazardType.waterSeepage => 'Water seeping from the hillside near $zoneName, ground looks soft.',
      HazardType.soilMovement => 'Ground appears to be slowly shifting near $zoneName.',
      HazardType.damagedInfrastructure => 'A retaining wall near $zoneName looks damaged/cracked.',
      HazardType.other => 'Unusual ground condition observed near $zoneName, worth checking.',
    };

List<Report> _buildReports(Random rng, List<RiskZone> zones) {
  final now = DateTime.now();

  return [
    for (var i = 0; i < _reportStatusCycle.length; i++)
      () {
        final zone = zones[rng.nextInt(zones.length)];
        final hazardType = HazardType.values[rng.nextInt(HazardType.values.length)];
        final jitterLat = (rng.nextDouble() - 0.5) * 0.012;
        final jitterLng = (rng.nextDouble() - 0.5) * 0.012;
        final isFieldReport = i == 3; // one report authored by a field officer, for variety

        return Report(
          id: 'synthetic_report_${i + 1}',
          reporterUid: isFieldReport ? realFieldOfficerUid : _reporterUids[rng.nextInt(_reporterUids.length)],
          reporterRole: isFieldReport ? UserRole.fieldOfficial : UserRole.citizen,
          hazardType: hazardType,
          description: _reportDescriptionFor(hazardType, zone.name),
          lat: zone.lat + jitterLat,
          lng: zone.lng + jitterLng,
          district: AppConfig.district,
          mediaUrls: const [],
          status: _reportStatusCycle[i],
          trustWeight: 0.6 + rng.nextDouble() * 0.4,
          createdAt: now.subtract(Duration(days: rng.nextInt(21), hours: rng.nextInt(24))),
        );
      }(),
  ];
}

// ---------------------------------------------------------------------------
// Inspection tasks
// ---------------------------------------------------------------------------

const _taskStatusPlan = [
  InspectionTaskStatus.unassigned,
  InspectionTaskStatus.notified,
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
  InspectionTaskStatus.completed,
  InspectionTaskStatus.completed,
  InspectionTaskStatus.notified,
];

List<InspectionTask> _buildTasks(Random rng, List<RiskZone> zones, List<Report> reports) {
  final sortedZones = [...zones]..sort((a, b) => b.riskScore.compareTo(a.riskScore));
  final targetZones = sortedZones.take(_taskStatusPlan.length).toList();
  final now = DateTime.now();

  return [
    for (var i = 0; i < _taskStatusPlan.length; i++)
      () {
        final zone = targetZones[i];
        final status = _taskStatusPlan[i];
        final isUnassigned = status == InspectionTaskStatus.unassigned;
        // A "notified" task can only exist via the analyst's manual
        // notify-then-accept flow — auto-assignment never produces one
        // (see auto_assignment_service.dart) — so force manual regardless
        // of the usual i.isEven alternation.
        final isNotified = status == InspectionTaskStatus.notified;
        final isManual = isNotified || i.isEven;
        final createdAt = now.subtract(Duration(days: rng.nextInt(10) + 1));
        // Real notifyFieldOfficerAt/assignInspectionAt calls never stamp
        // assignedAt/dueDate at creation — those are only set by the
        // separate TasksScreen "Assign Field Officer" (re)assign dialog —
        // so a still-notified task has neither yet, same as unassigned.
        final assignedAt =
            isUnassigned || isNotified ? null : createdAt.add(Duration(hours: rng.nextInt(12) + 1));
        final isTerminal = status == InspectionTaskStatus.completed;
        final dueDate = isUnassigned || isNotified || isTerminal
            ? null
            : assignedAt!.add(Duration(days: rng.nextInt(4) + 2));
        final acceptedAt = isUnassigned || isNotified
            ? null
            : createdAt.add(Duration(hours: rng.nextInt(12) + 1, minutes: rng.nextInt(60)));
        // Tie the first two assignable tasks to real seeded reports, so the
        // Reports Queue's "Assign Field Officer" outcome and the
        // Inspections page tell the same story for at least a couple of
        // records — the rest are independent AI/susceptibility-flagged
        // tasks, same as before.
        final linkedReportId = (i == 1 && reports.isNotEmpty)
            ? reports[0].id
            : (i == 4 && reports.length > 3 ? reports[3].id : null);

        final reason = linkedReportId != null
            ? 'Citizen report — field verification requested'
            : (isManual
                ? 'AI/susceptibility flagged — manual review requested by analyst'
                : 'AI flagged rising risk — no citizen report yet');
        final instructions = 'Inspect ${zone.name} (${zone.level.label} risk). '
            '${linkedReportId != null ? 'Field-verify the citizen-reported condition at this location. ' : ''}'
            'Confirm current ground conditions, check for fresh cracking or slope movement, '
            'and photograph anything relevant.';

        return InspectionTask(
          id: 'synthetic_task_${i + 1}',
          assignedOfficerUid: isUnassigned ? null : realFieldOfficerUid,
          linkedReportId: linkedReportId,
          lat: zone.lat,
          lng: zone.lng,
          riskLevel: zone.level,
          reason: reason,
          instructions: instructions,
          status: status,
          createdAt: createdAt,
          geofence: Geofence.circle(
            centerLat: zone.lat,
            centerLng: zone.lng,
            radiusMeters: radiusMetersForSeverity(zone.level),
          ),
          assignmentType: isManual ? AssignmentType.manual : AssignmentType.automatic,
          assignedBy: isManual && !isUnassigned ? realAnalystUid : null,
          geofenceStatus: isTerminal ? GeofenceStatus.inactive : GeofenceStatus.active,
          assignedAt: assignedAt,
          dueDate: dueDate,
          acceptedAt: acceptedAt,
        );
      }(),
  ];
}

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------

const _alertStatusPlan = [
  AlertStatus.open,
  AlertStatus.open,
  AlertStatus.assigned,
  AlertStatus.acknowledged,
  AlertStatus.escalated,
  AlertStatus.resolved,
  AlertStatus.resolved,
];

const _alertSourcePlan = [
  AlertSource.aiRiskEngine,
  AlertSource.heavyRainfall,
  AlertSource.fieldOfficerVerification,
  AlertSource.sensorAnomaly,
  AlertSource.citizenReport,
  AlertSource.analystDecision,
  AlertSource.aiRiskEngine,
];

String _recommendedActionFor(RiskLevel level) => switch (level) {
      RiskLevel.critical => 'Dispatch a field officer for verification within 6h.',
      RiskLevel.high => 'Dispatch a field officer for verification within 12-24h.',
      RiskLevel.moderate => 'Schedule routine monitoring; escalate if conditions worsen.',
      RiskLevel.low => 'Routine monitoring — no immediate action required.',
    };

/// Picks zones across risk bands rather than strictly the top-N by score —
/// a real alert history includes past moderate/routine advisories too, not
/// just whatever is hottest right now, and this is what gives the Alerts
/// screen mixed severities instead of a wall of "High". Per-band caps (not
/// just concatenate-and-take-N) are what actually force the mix: with 18
/// zones typically skewing high/moderate, taking N off the front of a
/// critical->high->moderate->low list would still land on all
/// critical+high.
List<RiskZone> _pickAlertZones(List<RiskZone> zones, int count) {
  final byLevel = <RiskLevel, List<RiskZone>>{};
  for (final zone in zones) {
    (byLevel[zone.level] ??= []).add(zone);
  }
  for (final list in byLevel.values) {
    list.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  }

  final caps = {
    RiskLevel.critical: 2,
    RiskLevel.high: 3,
    RiskLevel.moderate: 2,
    RiskLevel.low: 1,
  };

  final picked = <RiskZone>[];
  for (final level in [RiskLevel.critical, RiskLevel.high, RiskLevel.moderate, RiskLevel.low]) {
    final available = byLevel[level] ?? [];
    picked.addAll(available.take(caps[level]!));
  }
  // If some band was short (e.g. no critical zone this run), fill the
  // remaining slots from whoever's left, highest score first.
  if (picked.length < count) {
    final remaining = zones.where((z) => !picked.contains(z)).toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
    picked.addAll(remaining.take(count - picked.length));
  }
  return picked.take(count).toList();
}

List<HazardAlert> _buildAlerts(Random rng, List<RiskZone> zones) {
  final targetZones = _pickAlertZones(zones, _alertStatusPlan.length);
  final now = DateTime.now();

  return [
    for (var i = 0; i < targetZones.length; i++)
      () {
        final zone = targetZones[i];
        return HazardAlert(
          id: 'synthetic_alert_${i + 1}',
          title: '${zone.level.label} risk — ${zone.name}',
          message: 'Monitoring indicates ${zone.level.label.toLowerCase()} landslide risk near '
              '${zone.name} (rainfall ${zone.rainfall24hMm.toStringAsFixed(1)}mm/24h, '
              'soil moisture ${zone.soilMoisturePercent.toStringAsFixed(0)}%). '
              '${i.isEven ? 'Avoid travel through this area if possible.' : 'Field verification is underway.'}',
          severity: zone.level,
          lat: zone.lat,
          lng: zone.lng,
          radiusKm: 2.0 + rng.nextDouble() * 2.0,
          district: AppConfig.district,
          createdAt: now.subtract(Duration(hours: rng.nextInt(96) + 1)),
          status: _alertStatusPlan[i],
          source: _alertSourcePlan[i],
          recommendedAction: _recommendedActionFor(zone.level),
        );
      }(),
  ];
}

// ---------------------------------------------------------------------------
// Field inspections — one per completed task, so the "review what the
// officer actually reported" detail view (Inspection Queue) has real data
// to show instead of nothing. Deliberately varied: one confirms a hazard,
// one comes back clear, giving the demo both outcomes to show.
// ---------------------------------------------------------------------------

class _InspectionFinding {
  final CrackStatus crackStatus;
  final SlopeMovement slopeMovement;
  final bool rockfall;
  final bool waterSeepage;
  final RoadCondition roadCondition;
  final String notes;
  final bool locationVerified;

  const _InspectionFinding({
    required this.crackStatus,
    required this.slopeMovement,
    required this.rockfall,
    required this.waterSeepage,
    required this.roadCondition,
    required this.notes,
    required this.locationVerified,
  });
}

const _inspectionFindings = [
  _InspectionFinding(
    crackStatus: CrackStatus.major,
    slopeMovement: SlopeMovement.significant,
    rockfall: true,
    waterSeepage: true,
    roadCondition: RoadCondition.partiallyBlocked,
    notes: 'Fresh cracking along the upper slope, roughly 2m and actively widening. Minor '
        'rockfall debris on the access track and visible water seepage lower down. '
        'Recommend continued close monitoring and restricting foot traffic through the area.',
    locationVerified: true,
  ),
  _InspectionFinding(
    crackStatus: CrackStatus.none,
    slopeMovement: SlopeMovement.none,
    rockfall: false,
    waterSeepage: false,
    roadCondition: RoadCondition.open,
    notes: 'No visible cracking, slope movement, or water seepage at the time of inspection. '
        'Ground conditions appear stable and road access is clear.',
    locationVerified: false,
  ),
];

List<FieldInspection> _buildFieldInspections(Random rng, List<InspectionTask> tasks) {
  final completed = tasks.where((t) => t.status == InspectionTaskStatus.completed).toList();

  return [
    for (var i = 0; i < completed.length && i < _inspectionFindings.length; i++)
      () {
        final task = completed[i];
        final finding = _inspectionFindings[i];
        final checkInAt = task.createdAt.add(Duration(hours: rng.nextInt(24) + 6));
        final submittedAt = checkInAt.add(Duration(minutes: rng.nextInt(40) + 20));
        double jitter() => (rng.nextDouble() - 0.5) * 0.0008;

        return FieldInspection(
          id: 'synthetic_inspection_${i + 1}',
          taskId: task.id,
          officerUid: realFieldOfficerUid,
          officerName: 'Field Officer',
          geofenceVerified: true,
          checkInLat: task.lat + jitter(),
          checkInLng: task.lng + jitter(),
          checkInAt: checkInAt,
          crackStatus: finding.crackStatus,
          slopeMovement: finding.slopeMovement,
          rockfall: finding.rockfall,
          waterSeepage: finding.waterSeepage,
          roadCondition: finding.roadCondition,
          notes: finding.notes,
          photoUrls: const [],
          submittedAt: submittedAt,
          submissionLat: task.lat + jitter(),
          submissionLng: task.lng + jitter(),
          locationVerifiedAtSubmission: finding.locationVerified,
        );
      }(),
  ];
}

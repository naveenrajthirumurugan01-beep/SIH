import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo_utils.dart';
import '../models/risk_zone.dart';

abstract class RiskRepository {
  Future<List<RiskZone>> getRiskZones();
  Future<RiskZone?> getNearestZone(double lat, double lng);
}

/// SYNTHETIC DEMO LANDSLIDE RISK DATA — Dibang Valley, Arunachal Pradesh, India.
///
/// NOTE: These coordinates, risk scores, and risk polygons are synthetic
/// demonstration data for the UI prototype. They do NOT present actual live predictions.
/// In production, this service will be replaced by FastAPIRiskService connected to the ML engine.
class MockRiskRepository implements RiskRepository {
  static final List<RiskZone> _zones = [
    // ── DV-01: Near Anini (Score: 0.87, VERY HIGH) ───────────────────────────
    RiskZone(
      id: 'DV-01',
      name: 'Near Anini',
      lat: 28.7891,
      lng: 95.8328,
      radiusKm: 3.5,
      riskScore: 0.87,
      level: RiskLevel.critical,
      district: 'Dibang Valley',
      updatedAt: DateTime.now(),
      notes: 'DEMO DATA — Fragile steep mountain cut slope near Dri River.',
      slopeFactor: 'HIGH',
      rainfallFactor: 'HIGH',
      soilMoistureFactor: 'HIGH',
      historyFactor: 'HIGH',
      polygonPoints: const [
        LatLng(28.8100, 95.8100),
        LatLng(28.8200, 95.8500),
        LatLng(28.7800, 95.8700),
        LatLng(28.7500, 95.8400),
        LatLng(28.7650, 95.8000),
      ],
    ),

    // ── DV-02: Near Etalin (Score: 0.72, HIGH) ──────────────────────────────
    RiskZone(
      id: 'DV-02',
      name: 'Near Etalin',
      lat: 28.7500,
      lng: 95.8500,
      radiusKm: 3.0,
      riskScore: 0.72,
      level: RiskLevel.high,
      district: 'Dibang Valley',
      updatedAt: DateTime.now(),
      notes: 'DEMO DATA — River confluence corridor with active soil creep.',
      slopeFactor: 'HIGH',
      rainfallFactor: 'HIGH',
      soilMoistureFactor: 'MODERATE',
      historyFactor: 'MODERATE',
      polygonPoints: const [
        LatLng(28.7700, 95.8350),
        LatLng(28.7750, 95.8750),
        LatLng(28.7300, 95.8800),
        LatLng(28.7250, 95.8400),
      ],
    ),

    // ── DV-03: Near Dambuk (Score: 0.81, VERY HIGH) ──────────────────────────
    RiskZone(
      id: 'DV-03',
      name: 'Near Dambuk',
      lat: 28.2500,
      lng: 95.5600,
      radiusKm: 4.0,
      riskScore: 0.81,
      level: RiskLevel.critical,
      district: 'Lower Dibang Valley',
      updatedAt: DateTime.now(),
      notes: 'DEMO DATA — Highway rockfall and mudslide vulnerability band.',
      slopeFactor: 'HIGH',
      rainfallFactor: 'VERY HIGH',
      soilMoistureFactor: 'HIGH',
      historyFactor: 'HIGH',
      polygonPoints: const [
        LatLng(28.2750, 95.5350),
        LatLng(28.2850, 95.5850),
        LatLng(28.2250, 95.5900),
        LatLng(28.2150, 95.5400),
      ],
    ),

    // ── DV-04: Near Mathunli (Score: 0.46, MODERATE) ─────────────────────────
    RiskZone(
      id: 'DV-04',
      name: 'Near Mathunli Village',
      lat: 28.7156,
      lng: 95.6332,
      radiusKm: 3.2,
      riskScore: 0.46,
      level: RiskLevel.moderate,
      district: 'Dibang Valley',
      updatedAt: DateTime.now(),
      notes: 'DEMO DATA — Moderate risk agricultural slope near Mathunli.',
      slopeFactor: 'MODERATE',
      rainfallFactor: 'MODERATE',
      soilMoistureFactor: 'HIGH',
      historyFactor: 'LOW',
      polygonPoints: const [
        LatLng(28.7350, 95.6100),
        LatLng(28.7400, 95.6600),
        LatLng(28.6950, 95.6550),
        LatLng(28.6900, 95.6150),
      ],
    ),

    // ── DV-05: Surrounding terrain (Score: 0.18, LOW) ────────────────────────
    RiskZone(
      id: 'DV-05',
      name: 'Surrounding Ridge Belt',
      lat: 28.5000,
      lng: 95.8000,
      radiusKm: 8.0,
      riskScore: 0.18,
      level: RiskLevel.low,
      district: 'Dibang Valley',
      updatedAt: DateTime.now(),
      notes: 'DEMO DATA — Forested valley terrain with low slope activity.',
      slopeFactor: 'LOW',
      rainfallFactor: 'MODERATE',
      soilMoistureFactor: 'LOW',
      historyFactor: 'LOW',
      polygonPoints: const [
        LatLng(28.6000, 95.7000),
        LatLng(28.6200, 95.9000),
        LatLng(28.4000, 95.9200),
        LatLng(28.3800, 95.7200),
      ],
    ),
  ];

  @override
  Future<List<RiskZone>> getRiskZones() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_zones);
  }

  @override
  Future<RiskZone?> getNearestZone(double lat, double lng) async {
    if (_zones.isEmpty) return null;
    RiskZone? nearest;
    var nearestKm = double.infinity;
    for (final zone in _zones) {
      final km = distanceKm(lat, lng, zone.lat, zone.lng);
      if (km < nearestKm) {
        nearestKm = km;
        nearest = zone;
      }
    }
    return nearest;
  }
}

/// Reads the `risk_zones` Firestore collection when AppConfig.useMockData is false.
class FirestoreRiskRepository implements RiskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'risk_zones';

  @override
  Future<List<RiskZone>> getRiskZones() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map((doc) => RiskZone.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<RiskZone?> getNearestZone(double lat, double lng) async {
    final zones = await getRiskZones();
    if (zones.isEmpty) return null;
    RiskZone? nearest;
    var nearestKm = double.infinity;
    for (final zone in zones) {
      final km = distanceKm(lat, lng, zone.lat, zone.lng);
      if (km < nearestKm) {
        nearestKm = km;
        nearest = zone;
      }
    }
    return nearest;
  }
}

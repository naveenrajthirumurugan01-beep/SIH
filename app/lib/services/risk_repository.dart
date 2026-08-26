import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../core/geo_utils.dart';
import '../models/risk_zone.dart';

abstract class RiskRepository {
  Future<List<RiskZone>> getRiskZones();

  /// Nearest zone to (lat, lng), or null if no zones are loaded.
  Future<RiskZone?> getNearestZone(double lat, double lng);
}

/// SYNTHETIC — replace me. Seeded risk zones for the Anini/Etalin study
/// area. Two zones are anchored at Bhuvan-confirmed landslide points
/// (28.7891, 95.8328 and 28.7647, 95.8248); every other zone/coordinate
/// here is a placeholder for demo purposes only and carries no real
/// terrain/rainfall analysis behind it.
class MockRiskRepository implements RiskRepository {
  static final List<RiskZone> _zones = [
    RiskZone(
      id: 'zone_confirmed_1',
      name: 'Confirmed Slide Point — Dri River Slope',
      lat: 28.7891,
      lng: 95.8328,
      radiusKm: 1.5,
      level: RiskLevel.critical,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC — anchored at a Bhuvan-confirmed landslide point.',
    ),
    RiskZone(
      id: 'zone_confirmed_2',
      name: 'Confirmed Slide Point — Ithun Valley Slope',
      lat: 28.7647,
      lng: 95.8248,
      radiusKm: 1.5,
      level: RiskLevel.high,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC — anchored at a Bhuvan-confirmed landslide point.',
    ),
    RiskZone(
      id: 'zone_anini_town',
      name: 'Anini Township',
      lat: 28.8167,
      lng: 95.8333,
      radiusKm: 3.0,
      level: RiskLevel.moderate,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC placeholder — not model-derived.',
    ),
    RiskZone(
      id: 'zone_etalin',
      name: 'Etalin Confluence Area',
      lat: 28.7500,
      lng: 95.8500,
      radiusKm: 3.0,
      level: RiskLevel.moderate,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC placeholder — not model-derived.',
    ),
    RiskZone(
      id: 'zone_north_ridge',
      name: 'Northern Ridge Belt',
      lat: 28.8400,
      lng: 95.7600,
      radiusKm: 4.0,
      level: RiskLevel.low,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC placeholder — not model-derived.',
    ),
    RiskZone(
      id: 'zone_south_valley',
      name: 'Southern Valley Belt',
      lat: 28.6500,
      lng: 95.9200,
      radiusKm: 4.0,
      level: RiskLevel.low,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC placeholder — not model-derived.',
    ),
    RiskZone(
      id: 'zone_west_slope',
      name: 'Western Slope Corridor',
      lat: 28.7200,
      lng: 95.7300,
      radiusKm: 3.0,
      level: RiskLevel.moderate,
      district: AppConfig.district,
      updatedAt: DateTime.now(),
      notes: 'SYNTHETIC placeholder — not model-derived.',
    ),
  ];

  @override
  Future<List<RiskZone>> getRiskZones() async {
    // Simulate network latency so loading states are exercised in the UI.
    await Future<void>.delayed(const Duration(milliseconds: 200));
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

/// Reads the `risk_zones` Firestore collection once a real Firebase project
/// is wired up (see AppConfig.useMockData).
class FirestoreRiskRepository implements RiskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'risk_zones';

  @override
  Future<List<RiskZone>> getRiskZones() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => RiskZone.fromFirestore(doc.id, doc.data())).toList();
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
